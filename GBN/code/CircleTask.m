function CircleTask(obj,event)
event_time = datestr(event.Data.time);   %ʹ��event�����data��time���Ի��ϵͳ��ǰʱ�䣬��ת�����ַ���
d=event_time(19:20);   %���ڱ��������������Сʱ�����룬����ֻ��Ҫ������ݣ���˵���ȡ��
d=str2double(d); %���ַ���ת��������
alpha=0:pi/20:pi/20*d;%�Ƕ�[0,2*pi]
ud=obj.UserData;  %ʹ��obj�����UserData���Դ���
R=ud;%�뾶
x=R*cos(alpha);
y=R*sin(alpha);
plot(x,y,'o-')
axis equal

