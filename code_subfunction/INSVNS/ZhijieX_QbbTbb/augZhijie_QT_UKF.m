%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                             augmentZhijie_dQdT_UKF
%                               2014.5.3
%                               buaaxyz
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 
% 状态方程：SINS力学方程—增广四元素和位置
%   16+7=23维：X = (q,r,v,gyro,acc,q_last,r_last)
% 量测量：Qbb,Tbb
% 滤波方法：UKF

function [INS_VNS_NavResult,check,recordStr,NavFilterParameter] = augZhijie_QT_UKF(visualInputData,imuInputData,trueTrace,NavFilterParameter,isTrueX0)
                
format long
if ~exist('visualInputData','var')
    % 独立运行
    clc
    clear all 
    close all
    %% 参数选择1 ： 再此更改所需添加的数据名称：对应相关的参数设置方案    
    % load([pwd,'\gyro_norm.mat']);  % 只有陀螺随机噪声
    % load([pwd,'\10s.mat']);
    % load([pwd,'\SimGenRT-R_Std0.002rad.mat']);                % 简称 R-20
    % load([pwd,'\SimGenRT-R_Std0.002rad_Const0.0002rad.mat']);
    % load([pwd,'\SimGenRT-T_Std0.02m.mat']);                   % 简称 T-20
    % load([pwd,'\SimGenRT-T_Std0.02rad_Const0.002rad.mat']);
    
    % load([pwd,'\ForwardVelNonIMUNoise.mat'])
    % load([pwd,'\trueVision40m.mat']);
    % load([pwd,'\visonScence40m.mat']);
    % load([pwd,'\仿真生成RT-静止-2S-陀螺噪声-Tbb常值.mat']);
    load([pwd,'\圆弧100HZ.mat']);
    % load([pwd,'\直线1min-真实IMU-真实RT.mat']);
     
    %load([pwd,'\静止.mat']);
    isAlone = 1;
else
    isAlone = 0;
end
integMethod = 'augZhijie_QT_UKF';

format long
disp('函数 INS_VNS_ZdRdT 开始运行')
addpath([pwd,'\sub_code']);
oldfolder=cd([GetUpperPath(pwd),'\commonFcn']);
add_CommonFcn_ToPath;
cd(oldfolder);
addpath([GetUpperPath(pwd),'\ResultDisplay']);

%% 导入数据

% (1) 导入纯视觉导航仿真解算的的中间结果，包括两个数据:Rbb[例3*3*127]、Tbb[例3*127]
VisualOut_RT=visualInputData.VisualRT;
RbbVision = VisualOut_RT.Rbb;
TbbVision = VisualOut_RT.Tbb;
frequency_VO = visualInputData.frequency;
% （2）IMU数据
wib_INSm = imuInputData.wib;
f_INSm = imuInputData.f;
imu_fre = imuInputData.frequency; % Hz

% 真实轨迹的参数
if ~exist('trueTrace','var')
    trueTrace = [];
end
resultPath = [pwd,'\navResult'];
if isdir(resultPath)
    delete([resultPath,'\*.*'])
else
   mkdir(resultPath) 
end
[planet,isKnowTrue,initialPosition_e,initialVelocity_r,initialAttitude_r,trueTraeFre,true_position,true_attitude,true_velocity,true_acc_r] = GetFromTrueTrace( trueTrace );
% true_position=-true_position;true_velocity=-true_velocity;initialVelocity_r=-initialVelocity_r;
%% 星体常数
if strcmp(planet,'m')
    moonConst = getMoonConst;   % 得到月球常数
    gp = moonConst.g0 ;     % 用于导航解算
    wip = moonConst.wim ;
    Rp = moonConst.Rm ;
    e = moonConst.e;
    gk1 = moonConst.gk1;
    gk2 = moonConst.gk2;
    disp('轨迹发生器：月球')
else
    earthConst = getEarthConst;   % 得到地球常数
    gp = earthConst.g0 ;     % 用于导航解算
    wip = earthConst.wie ;
    Rp = earthConst.Re ;
    e = earthConst.e;
    gk1 = earthConst.gk1;
    gk2 = earthConst.gk2;
    disp('轨迹发生器：地球')
end
%% 月球模型参数
Wipp=[0;0;wip];

%% sample period
validLenth_INS_VNS = GetValidLength([size(f_INSm,2),size(TbbVision,2)],[imu_fre,frequency_VO]); % 进行组合处理时，INS和VNS数据有效个数
imuNum = validLenth_INS_VNS(1); % 有效的IMU数据长度
%integnum = floor(imuNum/(imu_fre/frequency_VO))+1; % 组合导航数据个数 = 有效的VNS数据个数+1
integnum = validLenth_INS_VNS(2); % 组合导航数据个数 = 有效的VNS数据个数+1
integFre = frequency_VO;
cycleT_INS = 1/imu_fre;  % 捷联解算周期
cycleT_VNS = 1/frequency_VO;  % 视觉数据周期/滤波周期
OneIntegT_IMUtime = fix(imu_fre/integFre);  % 一个组合周内，IMU解算的次数

% cycleT_VNS=cycleT_INS;
% frequency_VO=imu_fre;
% integFre=frequency_VO;
% integnum=imuNum;
%% SINS导航参数
% 由IMU噪声确定滤波PQ初值的选取
    % 仿真时噪声已知，存储在imuInputData中，实验室噪声未知，手动输入 常值偏置 和 随机标准差
[pa,na,pg,ng,~] = GetIMUdrift( imuInputData,planet ) ; % pa(加计常值偏置),na（加计随机漂移）,pg(陀螺常值偏置),ng（陀螺随机漂移）
%初始位置误差 m 
dinit_pos = trueTrace.InitialPositionError;
%初始姿态误差 rad
dinit_att = trueTrace.InitialAttitudeError;

% 组合导航参数
INTGatt = zeros(3,integnum);  % 欧拉角姿态
INTGvel = zeros(3,integnum);  % 速度
INTGpos = zeros(3,integnum);  % 位置

% 捷联惯导解算导航参数
QrbSave = zeros(4,imuNum);      % 四元数记录
CrbSave = zeros(3,3,imuNum);    % 姿态矩阵记录

SINSatt = zeros(3,imuNum);  % 欧拉角姿态
SINSvel = zeros(3,imuNum);  % 速度
SINSposition = zeros(3,imuNum);  % 位置 米
SINSacc_r = zeros(3,imuNum);  % 加速度
SINSpositionition_d = zeros(3,imuNum);% 大地坐标系 经纬度

% SINSposition(:,1)=[1;1;0];
%% SINS初始条件
SINSpositionition_d(:,1) = initialPosition_e;  % 经度 纬度 高度
SINSatt(:,1) = initialAttitude_r;         % 初始姿态 sita ,gama ,fai （rad）

positionr = FJWtoZJ(SINSpositionition_d(:,1),planet);  %地固坐标系中的初始位置
% positionr = positionr+dinit_pos ;   % 叠加初始位置误差
% SINSpositionition_d(:,1) = FZJtoJW(positionr,planet);
Cen=FCen(SINSpositionition_d(1,1),SINSpositionition_d(2,1));       %calculate Cen

Cbn = FCbn(SINSatt(:,1));
Cbn = Cbn*FCbn(dinit_att);  % 叠加初始姿态误差
opintions.headingScope = 180;
SINSatt(:,1) = GetAttitude(Cbn','rad',opintions) ;

Cnb = Cbn';
Cer = Cen; % 世界坐标系相对于初始时刻地固系的旋转矩阵
Cre = Cer';
Crb = Cnb;
Cbr = Crb';
Wirr = Cer * Wipp;
SINSvel(:,1) = Cbr * initialVelocity_r;
INTGvel(:,1) = Cbr * initialVelocity_r;
INTGatt(:,1) = SINSatt(:,1);

% 根据初始姿态矩阵Crb计算初始姿态四元数
Qrb = FCnbtoQ(Crb);
QrbSave(:,1)  = Qrb ;
CrbSave(:,:,1) = Crb ;
%% 组合导航估计的误差
dangleEsm = zeros(3,integnum);          % 平台失准角估计值
dVelocityEsm = zeros(3,integnum);       % 速度误差估计值
dPositionEsm = zeros(3,integnum);       % 位置误差估计值
gyroDrift = zeros(3,integnum);          % 陀螺漂移估计值
accDrift = zeros(3,integnum);           % 加计漂移估计值

dangleEsmP = zeros(3,integnum);       	% 平台失准角估计均方误差
dVelocityEsmP = zeros(3,integnum);      % 速度误差估计均方误差
dPositionEsmP = zeros(3,integnum);      % 位置误差估计均方误差
gyroDriftP = zeros(3,integnum);         % 陀螺漂移估计均方误差
accDriftP = zeros(3,integnum);          % 加计漂移估计均方误差
% 中间参数
R_INS_save = zeros(3,3,integnum);
T_INS_save = zeros(3,integnum);
R_VNS_save = zeros(3,3,integnum);
T_VNS_save = zeros(3,integnum);

%% 组合导航参数（随不同组合方法不同）
projectName = integMethod;  % 存储在结果中，绘图时显示

%% 增广状态方程，Qbb Tbb为量测

XNum = 23;
ZNum = 7; % 量测信息维数
X = zeros(XNum,integnum);       % 状态向量
Xpre = zeros(XNum,integnum);
Xpre(1,1)=1;
X_correct = zeros(XNum,integnum);
if isTrueX0==1
    X(:,1) = [1;zeros(9,1);pg;pa;zeros(7,1)];
    X(1:4,1) = Qrb ;
    X(8:10,1) = SINSvel(:,1) ;
    X(17:20,1) = Qrb ;
else
%         pgError0 = [0.1;0.1;0.1]*pi/180/3600 ;  % 陀螺常值漂移 状态分量初值误差
%         paError0 = [10;10;10]*gp/1e6   ;         % 加计常值漂移 状态分量初值误差
%         X(:,1) = [zeros(9,1);pg-pgError0;pa-paError0;zeros(6,1)]; 
    X(:,1) = zeros(XNum,1);
    X(1:4,1) = Qrb ;
    X(8:10,1) = SINSvel(:,1) ;
    X(17:20,1) = Qrb ;
end
Zinteg = zeros(ZNum,integnum);
Zinteg_error = zeros(ZNum,integnum);
Zinteg_pre = zeros(ZNum,integnum);

P = zeros(XNum,XNum,integnum); % 滤波P阵s
[ P(:,:,1),Q,R,NavFilterParameter ] = GetFilterParameter( pg,ng,pa,na,NavFilterParameter ) ;

waitbarTitle = 'augment\_dRdT组合导航计算';

Crb = FQtoCnb(X(1:4,1));
opintions.headingScope=180;
INTGatt(:,1) = GetAttitude(Crb,'rad',opintions);
INTGpos(:,1) = X(5:7,1) ;
INTGvel(:,1) = X(8:10,1) ;

gyroDrift(:,1) = X(11:13,1) ;
accDrift(:,1) = X(14:16,1) ;

P0_diag = sqrt(diag(P(:,:,1))) ;  % P0阵对角元素
dangleEsmP(:,1) = P0_diag(1:3);
dVelocityEsmP(:,1) = P0_diag(4:6);
dPositionEsmP(:,1) = P0_diag(7:9);
gyroDriftP(:,1) = P0_diag(10:12);
accDriftP(:,1) = P0_diag(13:15);
       
IntegPositionition_d = zeros(3,integnum);
IntegPositionition_d(:,1) = initialPosition_e;  % 经度 纬度 高度
%% 开始导航解算
% 记录上一滤波时刻的姿态和位置
%     %% 纯惯导递推
% for t_imu = 1:imuNum
%     k_integ = t_imu;
%     X_last=X(:,k_integ);
% 
%     % 更新当地加速度
%     g = gp * (1+gk1*sin(SINSpositionition_d(2,t_imu))^2-gk2*sin(2*SINSpositionition_d(2,t_imu))^2);
%     gn = [0;0;-g];
%     % 更新姿态旋转矩阵
%     Cen = FCen(SINSpositionition_d(1,t_imu),SINSpositionition_d(2,t_imu));
%     Cnr = Cer * Cen';
%     gr = Cnr * gn ;
%     
%     wibb = wib_INSm(:,t_imu);
% 	fb = f_INSm(:,t_imu);    
% 
%     Xe=X_last+dXdt_ZhiJie(X_last,Wirr,gr,wibb,fb)*cycleT_VNS;
%     
%     Xe(1:4)=Xe(1:4)/norm(Xe(1:4));
%     Xe(17:20)=Xe(17:20)/norm(Xe(17:20));
%     X(:,k_integ+1)=Xe;
%     
%     % 四元数->方向余弦矩阵
%     Qrb =  X(1:4,k_integ+1) ;
%     Crb = FQtoCnb(Qrb);
%     Cbr = Crb';
%     
%     positione0 = Cre * X(5:7,k_integ+1) + positionr; % 将发射点惯性系中的位置转化到初始时刻地固系
%     SINSpositionition_d(:,t_imu+1) = FZJtoJW(positione0,planet);    % 再转化为经纬高度
%     % 组合导航参数
%     INTGpos(:,k_integ+1) = X(5:7,k_integ+1) ;
%     INTGvel(:,k_integ+1) = X(8:10,k_integ+1) ;
%     % 由方向余弦矩阵求姿态角
% %         Crb = FQtoCnb(X(1:4,k_integ+1));
%     opintions.headingScope=180;
%     INTGatt(:,k_integ+1) = GetAttitude(Crb,'rad',opintions);
%     gyroDrift(:,1) = X(11:13,k_integ+1) ;
%     accDrift(:,1) = X(14:16,k_integ+1) ;
% end

waitbar_h=waitbar(0,waitbarTitle);

for t_imu = 1:imuNum
    if mod(t_imu,ceil((imuNum-1)/200))==0
        waitbar(t_imu/(imuNum-1))
    end
%     %% 世界坐标系SINS导航解算
%     Wrbb = wib_INSm(:,t_imu) - Crb * Wirr;
%     % 角增量法解四元数微分方程（简化的）
%     Qrb=Qrb+0.5*cycleT_INS*[      0    ,-Wrbb(1,1),-Wrbb(2,1),-Wrbb(3,1);
%                             Wrbb(1,1),     0    , Wrbb(3,1),-Wrbb(2,1);
%                             Wrbb(2,1),-Wrbb(3,1),     0    , Wrbb(1,1);
%                             Wrbb(3,1), Wrbb(2,1),-Wrbb(1,1),     0    ]*Qrb;
%     Qrb=Qrb/norm(Qrb);      % 单位化四元数    
%     % 更新当地加速度
%     g = gp * (1+gk1*sin(SINSpositionition_d(2,t_imu))^2-gk2*sin(2*SINSpositionition_d(2,t_imu))^2);
%     gn = [0;0;-g];
%     % 更新姿态旋转矩阵
%     Cen = FCen(SINSpositionition_d(1,t_imu),SINSpositionition_d(2,t_imu));
%     Cnr = Cer * Cen';
%     gr = Cnr * gn;
%   	 %%%%%%%%%%% 速度方程 %%%%%%%%%%            
%     a_rbr = Cbr * f_INSm(:,t_imu) - getCrossMarix( 2*Wirr )*SINSvel(:,t_imu) + gr;      
%     SINSacc_r(:,t_imu) = a_rbr;
%     % 四元数->方向余弦矩阵
%     Crb = FQtoCnb(Qrb);
%     Cbr = Crb';
%     % 更新速度和位置
%         % 捷联解算的导航坐标系：世界坐标系
%     SINSvel(:,t_imu+1) = SINSvel(:,t_imu) + a_rbr * cycleT_INS;
%     SINSposition(:,t_imu+1) = SINSposition(:,t_imu) + SINSvel(:,t_imu) * cycleT_INS;
%     positione0 = Cre * SINSposition(:,t_imu+1) + positionr; % 将发射点惯性系中的位置转化到初始时刻地固系
%     SINSpositionition_d(:,t_imu+1) = FZJtoJW(positione0,planet);
    
    %% 信息融合
    % t_imu=1+100时开始
    
    % if t_imu>1 && mod(t_imu-1,imu_fre/frequency_VO)==0
    if mod(t_imu-1,imu_fre/frequency_VO)==0
        isIntegrate = 1 ;
    else
        isIntegrate = 0 ;
    end
        
    if isIntegrate == 1     % 滤波采样
        %% 信息融合
        % RbbVision(:,:,1)：t_imu=1到t_imu=101。RbbVision(:,:,2)：t_imu=101到t_imu=201。
        % t_imu=1,k_integ=1,用“RbbVision(:,:,1),wib_INSm(:,1),X(:,1)”算“X(:,2)”
        k_integ = round((t_imu-1)*frequency_VO/imu_fre)+1 ; 
        %% 增广，直接法（惯导力学状态模型），Q,T为量测
        X_last=X(:,k_integ);
        % 取 k_integ+1 时刻的状态方程参数
        wibb = wib_INSm(:,t_imu);
        fb = f_INSm(:,t_imu);
        % 更新当地加速度
        g = gp * (1+gk1*sin(IntegPositionition_d(2,k_integ))^2-gk2*sin(2*IntegPositionition_d(2,k_integ))^2);
        gn = [0;0;-g];
        % 更新姿态旋转矩阵
        Cen = FCen(IntegPositionition_d(1,k_integ),IntegPositionition_d(2,k_integ));
        Cnr = Cer * Cen';
        gr = Cnr * gn;
     %   dbstop in UKF_augZhijie_QT
         
        [X_new,P_new,Xpre(:,k_integ+1),X_correct(:,k_integ+1),Zinteg_pre(:,k_integ),Zinteg(:,k_integ),Zinteg_error(:,k_integ)] = UKF_augZhijie_QT(RbbVision(:,:,k_integ),TbbVision(:,k_integ),cycleT_VNS,X_last,P(:,:,k_integ),Q,R,Wirr,gr,wibb,fb);
        
        X(:,k_integ+1) = X_new;
        P(:,:,k_integ+1) = P_new;
        X(1:4,k_integ+1) = X(1:4,k_integ+1)/norm(X(1:4,k_integ+1)); % 单位化四元数
        X(17:20,k_integ+1) = X(1:4,k_integ+1);
        X(21:23,k_integ+1) = X(5:7,k_integ+1);
                
        r = X(5:7,k_integ+1) ;

        positione0 = Cre * r + positionr; % 将发射点惯性系中的位置转化到初始时刻地固系
        IntegPositionition_d(:,k_integ+1) = FZJtoJW(positione0,planet);

        % 组合导航参数
        INTGpos(:,k_integ+1) = X(5:7,k_integ+1) ;
        INTGvel(:,k_integ+1) = X(8:10,k_integ+1) ;
        % 由方向余弦矩阵求姿态角
        Crb = FQtoCnb(X(1:4,k_integ+1));
        opintions.headingScope=180;
        INTGatt(:,k_integ+1) = GetAttitude(Crb,'rad',opintions);
        gyroDrift(:,1) = X(11:13,k_integ+1) ;
        accDrift(:,1) = X(14:16,k_integ+1) ;

    end
 
end
close(waitbar_h)

%% 已知真实：计算导航误差
% 计算各维误差
if  isKnowTrue==1
    % 计算组合数据有效长度
    lengthArrayOld = [length(INTGpos),length(true_position)];
    frequencyArray = [integFre,trueTraeFre];
    [~,~,combineLength,combineFre] = GetValidLength(lengthArrayOld,frequencyArray);
    INTGPositionError = zeros(3,combineLength); % 组合导航的位置误差
    INTGAttitudeError = zeros(3,combineLength); % 组合导航的姿态误差
    INTGVelocityError = zeros(3,combineLength); % 组合导航的速度误差
    for k=1:combineLength
        k_true = fix((k-1)*(trueTraeFre/combineFre))+1 ;
        k_integ = fix((k-1)*(integFre/combineFre))+1;
        if k_true==101
            disp('101')
        end
        INTGPositionError(:,k) = INTGpos(:,k_integ)-true_position(:,k_true) ;
        INTGAttitudeError(:,k) = INTGatt(:,k_integ)-true_attitude(:,k_true);
        INTGAttitudeError(3,k) = YawErrorAdjust(INTGAttitudeError(3,k),'rad') ;
        INTGVelocityError(:,k) = INTGvel(:,k_integ)-true_velocity(:,k_true);  
    end    
    SINS_accError  =SINSacc_r-true_acc_r(:,1:length(SINSacc_r)) ; % SINS的加速度误差
    accDriftError = accDrift-repmat(pa,1,integnum) ;        % 组合导航的加计估计误差
    gyroDriftError = gyroDrift-repmat(pg,1,integnum) ;      % 组合导航的陀螺估计误差

    % 计算空间二维/三维位置误差及相对值
% dbstop in CalPosErrorIndex
    errorStr = CalPosErrorIndex( true_position,INTGPositionError,INTGAttitudeError*180/pi*3600 );
else
    errorStr = '\n真实未知';
end
accDriftStartErrorStr = sprintf('%0.3g  ',accDriftError(:,1)/(gp*1e-6));
accDriftEndErrorStr = sprintf('%0.3g  ',accDriftError(:,length(accDriftError))/(gp*1e-6));
gyroDriftStartErrorStr = sprintf('%0.3g  ',gyroDriftError(:,1)*180/pi*3600);
gyroDriftEndErrorStr = sprintf('%0.3g  ',gyroDriftError(:,length(gyroDriftError))*180/pi*3600);
recordStr = sprintf('%s\n\t初始、最终加计估计误差：(%s)、(%s) ug\n\t初始、最终陀螺估计误差：(%s)、(%s) °/h\n',errorStr,accDriftStartErrorStr,accDriftEndErrorStr,gyroDriftStartErrorStr,gyroDriftEndErrorStr) ;

X0str = sprintf('%0.3g  ',X(:,1));
P0str = sprintf('%0.3g  ',diag(P(:,:,1))');
Qstr = sprintf('%0.3g  ',diag(Q)');
R0str = sprintf('%0.3g  ',diag(R)');
recordStr = sprintf('%s\n滤波参数：\n\tX(0)=( %s )\n\tP(0)=( %s )\n\tQk=( %s )\n\tR(0)=( %s )\n',...
    recordStr,X0str,P0str,Qstr,R0str);

time=zeros(1,integnum);
for i=1:integnum
    time(i)=(i-1)/frequency_VO/60;
end

X_pre_error=[];
X_correct=[];
%% 保存结果为特定格式
INS_VNS_NavResult = save_augZhijie_QT_UKF_subplot(integFre,combineFre,imu_fre,projectName,gp,isKnowTrue,trueTraeFre,...
    INTGpos,INTGvel,INTGatt,dPositionEsm,dVelocityEsm,dangleEsm,accDrift,gyroDrift,INTGPositionError,true_position,...
    INTGAttitudeError,true_attitude,INTGVelocityError,accDriftError,gyroDriftError,dangleEsmP,dVelocityEsmP,dPositionEsmP,...
    gyroDriftP,accDriftP,SINS_accError,X_pre_error,X_correct,Zinteg_error,Zinteg_pre,Zinteg );

save([resultPath,'\INS_VNS_NavResult.mat'],'INS_VNS_NavResult')
disp('INS_VNS_ZdRdT 函数运行结束')

disp('滤波调试信息已输出到基本工作空间')

if exist('R_INS','var')
    check.R_INS=R_INS;  check.T_INS=T_INS;  check.R_VNS=R_VNS;  check.R_INS=R_INS;  check.T_VNS=T_VNS;  check.newInformation=newInformation;
    check.X_correct=X_correct;  check.X_pre_error=X_pre_error;
else
    check=[];
end

global projectDataPath 
if isAlone==1
   % 查看结果
    projectDataPath = pwd;
    [ResultDisplayPath,~] = GetUpperPath(pwd) ;
%     oldFloder = cd([ResultPath,'\ResultDispaly']) ; % 进入结果查看路径
    
%    copyfile([ResultDisplayPath,'\ResultDisplay\ResultDisplay.exe'],[pwd,'\navResult\ResultDisplay.exe']);
    
    % 记录实验参数
    fid = fopen([pwd,'\navResult\实验笔记(INS_VNS独立运行).txt'], 'w+');
    RecodeInput (fid,visualInputData,imuInputData,trueTrace);
    fprintf(fid,'\nINS_VNS_%s 解算误差：\n',integMethod);
    fprintf(fid,'%s',recordStr);
    fclose(fid);
    open([pwd,'\navResult\实验笔记(INS_VNS独立运行).txt'])
    if exist('VOResult','var')
       save([pwd,'\navResult\VOResult.mat'],'VOResult'); 
    end
    if exist('SINS_Result','var')
       save([pwd,'\navResult\SINS_Result.mat'],'SINS_Result'); 
    end
	ResultDisplay()
end

function Q = calQ( Q_ini,F,cycleT,G )
% Q：系统噪声方差阵
format long
Fi = F * cycleT;
Q = G*Q_ini*G';
tmp1 = Q * cycleT;
Q = tmp1;
for i = 2:11
    tmp2 = Fi * tmp1;
    tmp1 = (tmp2 + tmp2')/i;
    Q = Q + tmp1;
end
Q1=Q;


function [ P_ini,Q_ini,R_ini,NavFilterParameter ] = GetFilterParameter( pg,ng,pa,na,NavFilterParameter )
%% 导入初始滤波参数 P、Q、R
% if isfield(NavFilterParameter,'P_ini_augment_dRdT')
%     P_ini = NavFilterParameter.P_ini_augment_dRdT ;
% else
%     
% end
    szj1 = 1/3600*pi/180 * 6;
    szj2 = 1/3600*pi/180 * 6;
    szj3 = 1/3600*pi/180 * 6;
    P1_temp = diag([(1e-5)^2,(1e-5)^2,(1e-5)^2,(1e-5)^2,    (0.001)^2,(0.001)^2,(0.001)^2,  1e-9,1e-9,1e-9,...
                    (pg(1))^2,(pg(2))^2,(pg(3))^2,  (pa(1))^2,(pa(2))^2,(pa(3))^2] ); %  16*16
%     P1_temp = diag([(szj1)^2,(szj2)^2,(szj3)^2,(0.001)^2,(0.001)^2,(0.001)^2,1e-9,1e-9,1e-9,...
%                                     (pg(1))^2+1e-8,(pg(2))^2+1e-8,(pg(3))^2+1e-8,(pa(1))^2+1e-12,(pa(2))^2+1e-12,(pa(3))^2+1e-12]);
%     P1_temp = diag([(szj1)^2,(szj2)^2,(szj3)^2,(0.001)^2,(0.001)^2,(0.001)^2,1e-9,1e-9,1e-9,...
%                                 (pg(1))^2+1e-6,(pg(2))^2+1e-6,(pg(3))^2+1e-6,(pa(1))^2+1e-10,(pa(2))^2+1e-10,(pa(3))^2+1e-10]);
    Ts = [eye(16);eye(4),zeros(4,12);zeros(3,7),eye(3),zeros(3,6)]; % 23*16
    P_ini = Ts * P1_temp * Ts';    
     NavFilterParameter.P_ini_augment_dRdT =  sprintf('%1.1e ',P_ini) ;
    
% if isfield(NavFilterParameter,'Q_ini_augment_dRdT')
%     Q_ini = NavFilterParameter.Q_ini_augment_dRdT ;
% else
% end
   %%% Q_ini = diag([(ng(1))^2,(ng(2))^2,(ng(3))^2,(na(1))^2,(na(2))^2,(na(3))^2]);      % ???
  %  Q_ini = diag([(ng(1))^2+1e-19,(ng(2))^2+1e-19,(ng(3))^2+1e-19,(na(1))^2+1e-15,(na(2))^2+1e-15,(na(3))^2+1e-15]);
    Q_ini = diag([  2e-13 2e-13 2e-13 2e-13 ...         % 四元数微分方程
                    0 0 0 ...         % 位置微分方程
                    2e-12 2e-12 2e-12...         % 速度微分方程
                    0 0 0 ...           % 陀螺常值微分方程
                    0 0 0 ...           % 加计常值微分方程
                    0 0 0 0 0 0 0  ]);       

     NavFilterParameter.Q_ini_augment_dRdT = sprintf('%1.1e ',Q_ini) ;



if isfield(NavFilterParameter,'R_ini_augment_dRdT')
    R_list_input = {NavFilterParameter.R_ini_augment_dRdT} ;
else
    R_list_input = [];
end
R_list = [R_list_input,{'[[1 1 1 1]*1e-5  [1 1 1]*1e-5]'...
                        '[4e-004,4e-004,4e-004,4e-004,6e-007,6e-007,6e-007  ]',...     % 圆周360m Rbb 206"
                        '[1e-004,1e-004,5e-004,8e-004,6e-007,6e-007,6e-007  ]',...
                        '[1e-005,1e-005,1e-005,1e-003,6e-007,6e-007,6e-006  ]'....
                        '[1e-006,1e-006,1e-006,8e-006,6e-004,6e-004,6e-004 ]',...      % 向前360m Tbb 0.02m
                        '[4e-004,4e-004,4e-004,4e-004,6e-007,6e-007,6e-007  ]'}];      % 圆周360m Rbb 20.6"

[Selection,ok] = listdlg('PromptString','R_ini(前R后T)-augment_dRdT:','SelectionMode','single','ListSize',[350,100],'ListString',R_list);
if ok==0    
    Selection = 1 ;
end
answer = inputdlg('噪声方程阵R(前R后T)-augment_dRdT                     .','R_ini',1,R_list(Selection));
R_ini = diag(eval(answer{1})) ;   % R
NavFilterParameter.R_ini_augment_dRdT = answer{1} ;


