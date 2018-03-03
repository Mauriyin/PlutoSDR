function CircleTask(obj,event)
event_time = datestr(event.Data.time);   %使用event对象的data的time属性获得系统当前时间，并转换成字符串
d=event_time(19:20);   %由于本身保存的是年月日小时分钟秒，但我只需要秒的数据，因此单独取出
d=str2double(d); %将字符串转换成数字
alpha=0:pi/20:pi/20*d;%角度[0,2*pi]
ud=obj.UserData;  %使用obj对象的UserData属性传参
R=ud;%半径
x=R*cos(alpha);
y=R*sin(alpha);
plot(x,y,'o-')
axis equal

