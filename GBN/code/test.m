t=timer('Name','CircleTimer',...
'TimerFcn',@CircleTask,...
'Period',1,...
'ExecutionMode','fixedspacing');
%本句解释成中文就是：
%t= timer（计时器名字是啥？，叫CircleTimer，要输入的TimerFcn回调函数是啥？ ，
%用CircleTask这个函数，每次隔多久运行？，一秒，
%执行时间间隔的模式是什么？，上次执行完毕到这次执行计时）；
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