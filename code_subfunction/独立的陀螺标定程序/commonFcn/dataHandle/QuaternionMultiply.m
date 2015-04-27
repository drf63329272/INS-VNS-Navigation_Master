%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                xyz
%                             2014.3.28
%                             ��Ԫ���˷�
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Qc = Qa �� Qb
function Qc = QuaternionMultiply(Qa,Qb)
a0 = Qa(1) ;
a1 = Qa(2) ;
a2 = Qa(3) ;
a3 = Qa(4) ;
a = [a1;a2;a3]; 

b0 = Qb(1) ;
b1 = Qb(2) ;
b2 = Qb(3) ;
b3 = Qb(4) ;
b = [b1;b2;b3]; 

c0 = a0*b0 - a'*b ;
c = a0*b + b0*a + getCrossMarix(a)*b ;
Qc = [c0;c];
