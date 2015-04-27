% buaa xyz 2014.1.9

% ������� ��������ϵ�´��ߵ����㣺�Գ�ʼʱ�̵�xyzϵ��Ϊ����ϵ
% Դ�� ���α���2013.1.21-SINSr_addnoise��

function [SINS_Result,imuInputData] = main_SINSNav( imuInputData,trueTrace,timeShorted )
format long
disp('���� main_SINSNav ��ʼ����')
tic

if ~exist('imuInputData','var')
    % ��������
    clc
    clear all 
    close all
    %% �ٴ˸����������ӵ��������ƣ���Ӧ��صĲ������÷���    
    % load('gyro_norm.mat')            % ��ֹ30min���������������
    % load('gyro_const.mat')           % ��ֹ30min�������ݳ�ֵ����
    % load('gyro_const_norm.mat')      % ��ֹ30min�����������+��ֵ����
    % load('acc_norm.mat')            % ��ֹ30min�����Ӽ��������
    % load('acc_const.mat')           % ��ֹ30min�����ӼƳ�ֵ����
    %  load('��ֹ30min-IMU����-���RT.mat')     
    % load('��ֹ30min-IMU����-��ʵRT.mat')
   % load('��ֹ3min-IMU����-RT���')
   
    % load('Բ��1min')
    % load('ֱ��5min-IMU����-��ʵRT')
    % load('��ֹ5min-IMU����-���RT')
    % load('��ֹ5min-IMU����-��ʵRT')
    % load('Բ��5min-IMU����-���RT')
    % load('Բ��5min-IMU����-��ʵRT')
    
    isAlone = 1;
    timeShorted=1;
else
    isAlone = 0;
end
if ~exist('imuInputData','var')
   load('imuInputData.mat') 
end
if ~exist('trueTrace','var')
    if exist('trueTrace.mat','file')
        load('trueTrace.mat') 
    else
        trueTrace=[];
    end
end
save imuInputData imuInputData
save trueTrace trueTrace
%% ��������
% ��1��IMU����
wib_INSm = imuInputData.wib;
f_INSm = imuInputData.f;
imu_fre = imuInputData.frequency; % Hz
%% ��ʵ�켣�Ĳ���
if ~exist('trueTrace','var')
    trueTrace = [];
end
[planet,isKnowTrue,initialPosition_e,initialVelocity_r,initialAttitude_r,trueTraeFre,true_position,...
    true_attitude,true_velocity,true_acc_r,runTime_IMU,runTime_image] = GetFromTrueTrace( trueTrace );

runTimeNum = min(size(f_INSm,2),size(true_attitude,2)-1) ;
runTimeNum = fix(timeShorted*runTimeNum) ;
if isempty(runTime_IMU)
    imu_T=1/imu_fre*ones(runTimeNum,1);     % sec
else
    imu_T = runTime_to_setpTime(runTime_IMU) ;
end

% [pa,na,pg,ng,~] = GetIMUdrift( imuInputData,planet ) ; % pa(�ӼƳ�ֵƫ��),na���Ӽ����Ư�ƣ�,pg(���ݳ�ֵƫ��),ng���������Ư�ƣ�

%% ���峣��
if strcmp(planet,'m')
    moonConst = getMoonConst;   % �õ�������
    gp = moonConst.g0 ;     % ���ڵ�������
    wip = moonConst.wim ;
    Rp = moonConst.Rm ;
    e = moonConst.e;
    gk1 = moonConst.gk1;
    gk2 = moonConst.gk2;
    disp('�켣������������')
else
    earthConst = getEarthConst;   % �õ�������
    gp = earthConst.g0 ;     % ���ڵ�������
    wip = earthConst.wie ;
    Rp = earthConst.Re ;
    e = earthConst.e;
    gk1 = earthConst.gk1;
    gk2 = earthConst.gk2;
    disp('�켣������������')
end

Wiee=[0;0;wip];
% 
% earthConst = getEarthCosnt;
% g0_e = earthConst.g0 ;  % ���ڸ�������ļӼ�����

%% ��ʼ����

% ����ϵ��������
% attitude_t=zeros(3,runTimeNum);
% velocity_t=zeros(3,runTimeNum);
position_e=zeros(3,runTimeNum); % ���ȣ�rad��,γ�ȣ�rad��,�߶�

% ��������ϵ��������
velocity_r=zeros(3,runTimeNum);
position_r=zeros(3,runTimeNum);
attitude_r = zeros(3,runTimeNum);
acc_r = zeros(3,runTimeNum);
% n �ǵ��ص�������ϵ�� r ����������ϵ����ʼʱ�̵�������ϵ��

position_e(:,1)=initialPosition_e;  %��ʼλ��    position_e(1): ����   position_e(2):γ��  position_e(3):�߶�
position_ini_e = FJWtoZJ(position_e(:,1),planet);  %��ʼʱ�̵ع�����ϵ�е�λ�� ��x,y,z/m��
attitude_r(:,1)=initialAttitude_r + [0/3600/180*pi;0/3600/180*pi;0/3600/180*pi];    %��ʼ��̬ sita ,gama ,fai
Cbn=FCbn(attitude_r(:,1));
Cnb=Cbn';
Cen=FCen(position_e(1,1),position_e(2,1));       %calculate Cen
Cer = Cen; % ��������ϵ����ڳ�ʼʱ�̵ع�ϵ����ת����
Cre = Cer';
Crb = Cnb;
Cbr = Crb';
%Crb_ins = Crb ;
velocity_r(:,1) =  initialVelocity_r;
Wirr = Cer * Wiee;

% ���ݳ�ʼ��̬����Crb�����ʼ��̬��Ԫ��
Qrb = FCnbtoQ(Crb);

wh = waitbar(0,'���ߵ�������...');
for t = 1:runTimeNum-1
    if isfield(trueTrace,'dataSource') && strcmp(trueTrace.dataSource,'kitti')   
        %% kitti��IMUʵ�����ݣ������øö�ʱ�����һ��ʱ�̵� ���ٶ� Ч��������ǰһʱ�� �Լ� ���ʱ����м�ֵ
        Wrbb = wib_INSm(:,t+1) - Crb * Wirr;
        
        Qrb=Qrb+0.5*imu_T(t)*get_Wrbb_dM( Wrbb )*Qrb;
        Qrb=Qrb/norm(Qrb);
        
        % Qrb  = QuaternionDifferential( Qrb,Wrbb,imu_T(t) ) ;
        
        f_INSm_k = f_INSm(:,t+1) ;
    else
        %% �켣���������ɵķ������ݣ���켣������һ���� ���������ʱ���ǰһ�� ���ٶ�
        Wrbb = wib_INSm(:,t) - Crb * Wirr;
        Qrb=Qrb+0.5*imu_T(t)*get_Wrbb_dM( Wrbb )*Qrb;
        Qrb=Qrb/norm(Qrb);
        
        % Qrb  = QuaternionDifferential( Qrb,Wrbb,imu_T(t) ) ;
        
        f_INSm_k = f_INSm(:,t) ;
    end

    g = gp * (1+gk1*sin(position_e(2,t))^2-gk2*sin(2*position_e(2,t))^2);
    gn = [0;0;-g];
    Cen = FCen(position_e(1,t),position_e(2,t));
    Cnr = Cer * Cen';
    gr = Cnr * gn ;
  	%%%%%%%%%%% �ٶȷ��� %%%%%%%%%%     
    a_rbr = Cbr * f_INSm_k - getCrossMatrix( 2*Wirr )*velocity_r(:,t) + gr;      
    acc_r(:,t) = a_rbr;

    Crb = FQtoCnb(Qrb);
    Cbr = Crb';

    velocity_r(:,t+1) = velocity_r(:,t) + a_rbr * imu_T(t);
    position_r(:,t+1) = position_r(:,t) + velocity_r(:,t) * imu_T(t);
    positione0 = Cre * position_r(:,t+1) + position_ini_e; % ����������ϵ�е�λ��ת������ʼʱ�̵ع�ϵ
    position_e(:,t+1) = FZJtoJW(positione0,planet);    % ��ת��Ϊ��γ�߶�

    opintions.headingScope=180;
    attitude_r(:,t+1) = GetAttitude(Crb,'rad',opintions);
   
    if mod(t,fix(runTimeNum/20))==0
        waitbar(t/runTimeNum)
    end
end
close(wh)
% %%  �ڴ治��ʱ�� �� �ͷ�һЩ�ռ�
% save SINS_ResultBag  position_e velocity_r position_r attitude_r acc_r 
% save trueBag true_position true_attitude true_velocity true_acc_r
% clear true_position true_attitude true_velocity true_acc_r
% clear position_e velocity_r position_r attitude_r acc_r


%% ��֪��ʵ���������
if  isKnowTrue==1
    % �������������Ч����
    lengthArrayOld = [length(position_r),length(true_position)];
    frequencyArray = [imu_fre,trueTraeFre];
    [~,~,combineLength,combineFre] = GetValidLength(lengthArrayOld,frequencyArray);
    SINSPositionError = zeros(3,combineLength); % SINS��λ�����
    SINSAttitudeError = zeros(3,combineLength); % SINS����̬���
    SINSVelocityError = zeros(3,combineLength); % SINS���ٶ����
    
    for k=1:combineLength
        k_true = fix((k-1)*trueTraeFre/combineFre)+1 ;
        k_imu = fix((k-1)*imu_fre/combineFre)+1;
        SINSPositionError(:,k) = position_r(:,k_imu)-true_position(:,k_true) ;
        SINSAttitudeError(:,k) = attitude_r(:,k_imu)-true_attitude(:,k_true);
        SINSAttitudeError(3,k) = YawErrorAdjust(SINSAttitudeError(3,k),'rad') ;
        SINSVelocityError(:,k) = velocity_r(:,k_imu)-true_velocity(:,k_true);
        
    end    
    if ~isempty(true_acc_r)
        SINSAccError = zeros(3,length(acc_r));      % SINS�ļ��ٶ����
        for k=1:length(acc_r)
            k_true = fix((k-1)*trueTraeFre/combineFre)+1 ;
            k_imu = fix((k-1)*imu_fre/combineFre)+1;
            SINSAccError(:,k) = acc_r(:,k_imu)-true_acc_r(:,k_true);
        end        
    end
    errorStr = CalPosErrorIndex_route( true_position(:,1:runTimeNum),SINSPositionError,SINSAttitudeError*180/pi*3600,position_r );

else
    errorStr = '\n��ʵδ֪';
end

%% ��� 
imuInputData.errorStr=  errorStr ;
% �洢Ϊ�ض���ʽ��ÿ������һ��ϸ����������Ա��data��name,comment �� dataFlag,frequency,project,subName
resultNum = 30;
SINS_Result = cell(1,resultNum);

% ��4����ͬ�ĳ�Ա
for j=1:resultNum
    SINS_Result{j}.dataFlag = 'xyz result display format';
    SINS_Result{j}.frequency = imu_fre ;
    SINS_Result{j}.project = 'SINS';
    SINS_Result{j}.subName = {'x','y','z'};
    if isfield(trueTrace,'runTime_IMU')
        SINS_Result{j}.runTime = trueTrace.runTime_IMU ;
    end
end

res_k=0 ;

res_k = res_k+1 ;  
SINS_Result{res_k}.data = position_r ;
SINS_Result{res_k}.name = 'position(m)';
SINS_Result{res_k}.comment = 'λ��';

res_k = res_k+1 ;  
SINS_Result{res_k}.data = velocity_r ;
SINS_Result{res_k}.name = 'velocity(m/s)';
SINS_Result{res_k}.comment = '�ٶ�';

res_k = res_k+1 ;  
SINS_Result{res_k}.data = attitude_r*180/pi ;
SINS_Result{res_k}.name = 'attitude(��)';
SINS_Result{res_k}.comment = '��̬';
SINS_Result{res_k}.subName = {'����','���','����'};

res_k = res_k+1 ;  
SINS_Result{res_k}.data = acc_r ;
SINS_Result{res_k}.name ='acc(m/s^2)';
SINS_Result{res_k}.comment = '���ٶ�';


if isKnowTrue
    
    res_k = res_k+1 ;  
    SINS_Result{res_k}.data = SINSPositionError ;
    SINS_Result{res_k}.name = 'positionError(m)';
    SINS_Result{res_k}.comment = 'λ�����';
    SINS_Result{res_k}.frequency = combineFre ;
     % �������������    
    validLength = min(fix(length(position_r)*trueTraeFre/combineFre),length(true_position));
    true_position_valid = true_position(:,1:validLength) ;
    text_error_xyz = GetErrorText( true_position_valid,SINSPositionError ) ;
    SINS_Result{res_k}.text = text_error_xyz ;
    
    res_k = res_k+1 ; 
    SINS_Result{res_k}.data = SINSAttitudeError*180/pi;
    SINS_Result{res_k}.name = 'attitudeError(��)';
    SINS_Result{res_k}.comment = '��̬���';
    SINS_Result{res_k}.subName = {'����','���','����'};
    SINS_Result{res_k}.frequency = combineFre ;
    
    res_k = res_k+1 ; 
    SINS_Result{res_k}.data = SINSVelocityError;
    SINS_Result{res_k}.name = 'velocityError(m/��)';
    SINS_Result{res_k}.comment = '�ٶ����';
    SINS_Result{res_k}.frequency = combineFre ;
    
    if exist('SINSAccError','var')
        res_k = res_k+1 ; 
        SINS_Result{res_k}.data = SINSAccError/(gp*1e-6);
        SINS_Result{res_k}.name = 'SINS_accError(ug)';
        SINS_Result{res_k}.comment = 'SINS������ٶ����';
        SINS_Result{res_k}.frequency = combineFre ;
    end
end
SINS_Result = SINS_Result(1:res_k);

% ����
resultPath = [pwd,'\result'];
if isdir(resultPath)
    delete([resultPath,'\*'])
else
    mkdir(resultPath)
end
save([resultPath,'\SINS_Result.mat'],'SINS_Result')
global projectDataPath
if isAlone == 1
    trueTraceResult = GetTrueTraceResult(trueTrace);
	save([resultPath,'\trueTraceResult.mat'],'trueTraceResult')
        
    fid = fopen([resultPath,'\ʵ��ʼǣ�SINS�������У�.txt'], 'w+');
    visualInputData=[];
    RecodeInput (fid,visualInputData,imuInputData,trueTrace);
    fprintf(fid,'\nSINS������\n');
    fprintf(fid,'%s',errorStr);
    fprintf(fid,'SINS�����ʱ��%0.5g sec\n',toc);
    fclose(fid);
    open([resultPath,'\ʵ��ʼǣ�SINS�������У�.txt'])
    %% ��ʾ���
    
    projectDataPath = resultPath ;
    disp('��base workspace ��ִ�� ResultDisplay() �ɲ鿴���')
   % ResultDisplay()
end
    figure('name','�����켣')
    position_r_length = length(position_r);
    trueTraceValidLength = fix((position_r_length-1)*trueTraeFre/imu_fre) +1 ;
    true_position_valid = true_position(:,1:trueTraceValidLength);
    hold on
    plot(true_position_valid(1,:),true_position_valid(2,:),'--r');
    plot(position_r(1,:),position_r(2,:),'-.g');
   
    legend('trueTrace','SINS');
    saveas(gcf,'��ϵ����켣.fig')

    
function   Wrbb_dM = get_Wrbb_dM( Wrbb )

Wrbb_dM = [    0    ,-Wrbb(1,1),-Wrbb(2,1),-Wrbb(3,1);
          Wrbb(1,1),     0    , Wrbb(3,1),-Wrbb(2,1);
          Wrbb(2,1),-Wrbb(3,1),     0    , Wrbb(1,1);
          Wrbb(3,1), Wrbb(2,1),-Wrbb(1,1),     0    ] ;