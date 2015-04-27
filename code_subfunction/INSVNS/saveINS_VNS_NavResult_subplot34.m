% buaa xyz 2014.1.16

% ����INS_VNS����ϵ������ΪResultDisplayģ���ض���ʽ���ο����˵���ĵ���

function INS_VNS_NavResult = saveINS_VNS_NavResult_subplot(integFre,combineFre,imu_fre,projectName,gp,isKnowTrue,trueTraeFre,...
    INTGpos,INTGvel,INTGatt,dPositionEsm,dVelocityEsm,dangleEsm,accDrift,gyroDrift,INTGPositionError,true_position,...
    INTGAttitudeError,true_attitude,INTGVelocityError,accDriftError,gyroDriftError,dangleEsmP,dVelocityEsmP,dPositionEsmP,...
    gyroDriftP,accDriftP,SINS_accError)
% ���²���Ҳ��ֱ�ӿ��������������У�ֱ������˺����ĵ���

% �洢Ϊ�ض���ʽ��ÿ������һ��ϸ����������Ա��data��name,comment �� dataFlag,frequency,project,subName
resultNum = 19;
INS_VNS_NavResult = cell(1,resultNum);

% ��4����ͬ�ĳ�Ա
for j=1:resultNum
    INS_VNS_NavResult{j}.dataFlag = 'xyz result display format';
    INS_VNS_NavResult{j}.frequency = integFre ;
    INS_VNS_NavResult{j}.project = projectName ;
    INS_VNS_NavResult{j}.subName = {'x(m)','y(m)','z(m)'};
end

INS_VNS_NavResult{1}.data = INTGpos ;
INS_VNS_NavResult{1}.name = 'position(m)';
INS_VNS_NavResult{1}.comment = 'λ��';

INS_VNS_NavResult{2}.data = INTGvel ;
INS_VNS_NavResult{2}.name = 'velocity(m/s)';
INS_VNS_NavResult{2}.comment = '�ٶ�';
INS_VNS_NavResult{2}.subName = {'x(m/s)','y(m/s)','z(m/s)'};

INS_VNS_NavResult{3}.data = INTGatt*180/pi ;   % תΪ�Ƕȵ�λ
INS_VNS_NavResult{3}.name = 'attitude(��)';
INS_VNS_NavResult{3}.comment = '��̬';
INS_VNS_NavResult{3}.subName = {'����(��)','���(��)','����(��)'};

INS_VNS_NavResult{4}.data = dPositionEsm ;
INS_VNS_NavResult{4}.name = 'positionErrorEstimate(m)';
INS_VNS_NavResult{4}.comment = 'λ��������';

INS_VNS_NavResult{5}.data = dVelocityEsm ;
INS_VNS_NavResult{5}.name = 'velocityErrorEstimate(m/s)';
INS_VNS_NavResult{5}.comment = '�ٶ�������';
INS_VNS_NavResult{5}.subName = {'x(m/s)','y(m/s)','z(m/s)'};

INS_VNS_NavResult{6}.data = dangleEsm*180/pi*3600 ;     % תΪ���뵥λ
INS_VNS_NavResult{6}.name = 'attitudeErrorEstimate(����)';
INS_VNS_NavResult{6}.comment = 'ƽ̨���ǹ���';
INS_VNS_NavResult{6}.subName = {'����(����)','���(����)','����(����)'};

INS_VNS_NavResult{7}.data = accDrift/(gp*1e-6) ;     %
INS_VNS_NavResult{7}.name = 'accDrift(ug)';
INS_VNS_NavResult{7}.comment = '�ӼƳ�ֵƯ�ƹ���';
INS_VNS_NavResult{7}.subName = {'x(ug)','y(ug)','z(ug)'};
meanAccDrift = mean(accDrift/(gp*1e-6),2);  % �ӼƳ�ֵƯ�ƹ��ƾ�ֵ
meanAccDriftText{1} = '��ֵ';
meanAccDriftText{2} = sprintf('x��%0.3ug',meanAccDrift(1));
meanAccDriftText{3} = sprintf('y��%0.3ug',meanAccDrift(2));
meanAccDriftText{4} = sprintf('z��%0.3ug',meanAccDrift(3));
INS_VNS_NavResult{7}.text = meanAccDriftText ;

INS_VNS_NavResult{8}.data = gyroDrift*180/pi*3600 ;     % rad/s ת��Ϊ ��/h
INS_VNS_NavResult{8}.name = 'gyroDrift(��/h)';
INS_VNS_NavResult{8}.comment = '���ݳ�ֵƯ�ƹ���';
INS_VNS_NavResult{8}.subName = {'x(��/h)','y(��/h)','z(��/h)'};
meanGyroDrift = mean(gyroDrift*180/pi*3600,2);  % ���ݳ�ֵƯ�ƹ��ƾ�ֵ
meanGyroDriftText{1} = '��ֵ';
meanGyroDriftText{2} = sprintf('x��%0.3f��/h',meanGyroDrift(1));
meanGyroDriftText{3} = sprintf('y��%0.3f��/h',meanGyroDrift(2));
meanGyroDriftText{4} = sprintf('z��%0.3f��/h',meanGyroDrift(3));
INS_VNS_NavResult{8}.text = meanGyroDriftText ;

frontNum = 8;
for j=frontNum+1:resultNum
    INS_VNS_NavResult{j}.frequency = combineFre ;
end
if isKnowTrue==1
    INS_VNS_NavResult{frontNum+1}.data = INTGPositionError;
    INS_VNS_NavResult{frontNum+1}.name = 'positionError(m)';
    INS_VNS_NavResult{frontNum+1}.comment = 'λ�����';    
    % �������������յ�������
    validLength = fix(length(INTGpos)*(trueTraeFre/combineFre));
    true_position_valid = true_position(:,1:validLength) ;
    text_error_xyz = GetErrorText( true_position_valid,INTGPositionError ) ;
    INS_VNS_NavResult{frontNum+1}.text = text_error_xyz ;
    
    INS_VNS_NavResult{frontNum+2}.data = INTGAttitudeError*180/pi*3600;
    INS_VNS_NavResult{frontNum+2}.name = 'attitudeError(����)';
    INS_VNS_NavResult{frontNum+2}.comment = '��̬���';
    INS_VNS_NavResult{frontNum+2}.subName = {'����(����)','���(����)','����(����)'};
    % �������������յ�������
    validLength = fix(length(INTGatt)*(trueTraeFre/combineFre));
    true_attitude_valid = true_attitude(:,1:validLength) ;
    text_error_xyz = GetErrorText( true_attitude_valid,INTGAttitudeError*180/pi*3600 ) ;
    INS_VNS_NavResult{frontNum+2}.text = text_error_xyz ;
    
    INS_VNS_NavResult{frontNum+3}.data = INTGVelocityError;
    INS_VNS_NavResult{frontNum+3}.name = 'velocityError(m/��)';
    INS_VNS_NavResult{frontNum+3}.comment = '�ٶ����';
    INS_VNS_NavResult{frontNum+3}.subName = {'x(m/s)','y(m/s)','z(m/s)'};
    
    INS_VNS_NavResult{frontNum+4}.data = accDriftError/(gp*1e-6) ;     % ת��Ϊ ug ���
    INS_VNS_NavResult{frontNum+4}.name = 'accDriftError(ug)';
    INS_VNS_NavResult{frontNum+4}.comment = '�ӼƳ�ֵƯ�ƹ������';
    INS_VNS_NavResult{frontNum+4}.subName = {'x(ug)','y(ug)','z(ug)'};
    
    INS_VNS_NavResult{frontNum+5}.data = gyroDriftError*180/pi*3600 ;     % ת��Ϊ ��/h 
    INS_VNS_NavResult{frontNum+5}.name = 'gyroDriftError(��/h)';
    INS_VNS_NavResult{frontNum+5}.comment = '���ݳ�ֵƯ�ƹ������';
    INS_VNS_NavResult{frontNum+5}.subName = {'x(��/h)','y(��/h)','z(��/h)'};
    
    INS_VNS_NavResult{frontNum+6}.data = dangleEsmP*180/pi*3600 ;     % ת��Ϊ ����
    INS_VNS_NavResult{frontNum+6}.name = 'dangleEsmP(����)';
    INS_VNS_NavResult{frontNum+6}.comment = 'ƽ̨���ǹ��ƾ�����';
    INS_VNS_NavResult{frontNum+6}.frequency = integFre ;
    INS_VNS_NavResult{frontNum+6}.subName = {'x(����)','y(����)','z(����)'};
    
    INS_VNS_NavResult{frontNum+7}.data = dVelocityEsmP ;     
    INS_VNS_NavResult{frontNum+7}.name = 'dVelocityEsmP(m/��)';
    INS_VNS_NavResult{frontNum+7}.comment = '�ٶ������ƾ�����';
    INS_VNS_NavResult{frontNum+7}.frequency = integFre ;
    INS_VNS_NavResult{frontNum+7}.subName = {'x(m/s)','y(m/s)','z(m/s)'};
    
    INS_VNS_NavResult{frontNum+8}.data = dPositionEsmP ;     
    INS_VNS_NavResult{frontNum+8}.name = 'dPositionEsmP(m)';
    INS_VNS_NavResult{frontNum+8}.comment = 'λ�������ƾ�����';
    INS_VNS_NavResult{frontNum+8}.frequency = integFre ;
    
    INS_VNS_NavResult{frontNum+9}.data = gyroDriftP*180/pi*3600 ;     % ת��Ϊ ��/h 
    INS_VNS_NavResult{frontNum+9}.name = 'gyroDriftP(m)';
    INS_VNS_NavResult{frontNum+9}.comment = '����Ư�ƹ��ƾ�����';
    INS_VNS_NavResult{frontNum+9}.frequency = integFre ;
    INS_VNS_NavResult{frontNum+9}.subName = {'x(��/h)','y(��/h)','z(��/h)'};
    
    INS_VNS_NavResult{frontNum+10}.data = accDriftP/(gp*1e-6) ;     % ת��Ϊ ��/h 
    INS_VNS_NavResult{frontNum+10}.name = 'accDriftP(ug)';
    INS_VNS_NavResult{frontNum+10}.comment = '�Ӽ�Ư�ƹ��ƾ�����';
    INS_VNS_NavResult{frontNum+10}.frequency = integFre ;
    INS_VNS_NavResult{frontNum+10}.subName = {'x(ug)','y(ug)','z(ug)'};
    
    INS_VNS_NavResult{frontNum+11}.data = SINS_accError/(gp*1e-6) ;     % ת��Ϊ ug
    INS_VNS_NavResult{frontNum+11}.name = 'SINS_accError(ug)';
    INS_VNS_NavResult{frontNum+11}.comment = 'SINS������ٶ����';
    INS_VNS_NavResult{frontNum+11}.frequency = imu_fre ;
    INS_VNS_NavResult{frontNum+11}.subName = {'x(ug)','y(ug)','z(ug)'};
end
if length(INS_VNS_NavResult)~=resultNum
    errordlg(['resultNum���ó�������������дΪ:',num2str(length(INS_VNS_NavResult))])
end