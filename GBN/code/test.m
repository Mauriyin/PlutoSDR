t=timer('Name','CircleTimer',...
'TimerFcn',@CircleTask,...
'Period',1,...
'ExecutionMode','fixedspacing');
%������ͳ����ľ��ǣ�
%t= timer����ʱ��������ɶ������CircleTimer��Ҫ�����TimerFcn�ص�������ɶ�� ��
%��CircleTask���������ÿ�θ�������У���һ�룬
%ִ��ʱ������ģʽ��ʲô�����ϴ�ִ����ϵ����ִ�м�ʱ����
ud=3;
t.UserData=ud;
start(t);
i = 0;
while(i<20)
    disp('asdasd');
    pause(0.5);
    i = i+1;
end
stop(t);