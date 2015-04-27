%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
%                             xyz
%                           2014.3.7
%                          记录输入数据到txt文件
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function RecodeInput (fid,visualInputData,imuInputData,trueTrace)

fprintf(fid,'%s','       实验笔记\n');

%% 记录输入参数
% 轨迹发生器
if isfield(trueTrace,'traceRecord')
    fprintf(fid,'采用轨迹发生器生成轨迹\n%s\n\n',trueTrace.traceRecord) ;
end
if isfield(trueTrace,'InitialPositionError')
    str1 = sprintf('%0.4f  ',trueTrace.InitialPositionError) ;
    str2 = sprintf('%0.4f  ',trueTrace.InitialAttitudeError) ;
    str3 = sprintf('%0.4f  ',trueTrace.InitialAttitudeError * 180/pi*3600) ;
    fprintf(fid,'初始位置误差：%s m\n初始姿态误差：%s rad\n初始姿态误差：%s ″\n\n',str1,str2,str3);
else
    fprintf(fid,'无初始位置、姿态误差\n\n');
end
% 视觉信息
if ~isempty(visualInputData)
    fprintf(fid,'视觉信息频率：%0.1f\n',visualInputData.frequency);
    if isfield(visualInputData,'RTError')
        textStr =  '直接仿真生成RT，以下为RT生成所添加的噪声：\n';
        str = num2str(visualInputData.RTError.TbbErrorMean);
        textStr = [textStr  'TbbError均值：'  str  ' (m)\n'];
        str = num2str(visualInputData.RTError.TbbErrorStd);
        textStr = [textStr   'TbbError标准差：'   str   '(m)\n'];

        str1 = num2str(visualInputData.RTError.AngleErrorMean);
        str2 = num2str(visualInputData.RTError.AngleErrorMean*180/pi*3600);
        textStr = [textStr   'AngleError均值：'   str1 ,'(rad)  ', str2,  '(″)\n'];
        str1 = num2str(visualInputData.RTError.AngleErrorStd);
        str2 = num2str(visualInputData.RTError.AngleErrorStd*180/pi*3600);
        textStr = [textStr  'AngleError标准差：'   str1 ,'(rad)  ', str2,  '(″)\n'];

        fprintf(fid,textStr);
    end
end
% 惯导信息
planet = trueTrace.planet ;
if strcmp(planet,'m')
    moonConst = getMoonConst;   % 得到月球常数
    gp = moonConst.g0 ;     % 用于导航解算
    wip = moonConst.wim ;
    fprintf(fid,'\n惯导信息(月球)\n');
else
    earthConst = getEarthConst;   % 得到地球常数
    gp = earthConst.g0 ;     % 用于导航解算
    wip = earthConst.wie ;
    fprintf(fid,'\n惯导信息（地球）\n');
end
fprintf(fid,'惯导信息频率：%0.1f\n',imuInputData.frequency);
if isfield(imuInputData,'pa')    
    pa = imuInputData.pa/(gp*1e-6);
    fprintf(fid,'加计常值偏置：(%g,%g,%g) (ug)\n',pa(1),pa(2),pa(3));
    na = imuInputData.na/(gp*1e-6);
    fprintf(fid,'加计随机漂移：(%g,%g,%g) (ug)\n',na(1),na(2),na(3));
    pg = imuInputData.pg*180/pi*3600;
    fprintf(fid,'陀螺常值偏置：(%g,%g,%g) (°/h)\n',pg(1),pg(2),pg(3));
    ng = imuInputData.ng*180/pi*3600;
    fprintf(fid,'陀螺随机漂移：(%g,%g,%g) (°/h)\n',ng(1),ng(2),ng(3));
end

