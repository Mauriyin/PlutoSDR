clearvars -except times;close all;warning off;
set(0,'defaultfigurecolor','w');
addpath ..\..\libraryj
addpath ..\..\library\matlab

ip = '192.168.2.1';
addpath BPSK\transmitter
addpath BPSK\receiver
txdata = bpsk_tx_func('xxx');
txdata = round(txdata .* 2^14);
txdata = repmat(txdata, 8,1);

%% Transmit and Receive using MATLAB libiio

% System Object Configuration
s = iio_sys_obj_matlab; % MATLAB libiio Constructor
s.ip_address = ip;
s.dev_name = 'ad9361';
s.in_ch_no = 2;
s.out_ch_no = 2;
s.in_ch_size = length(txdata);
s.out_ch_size = length(txdata).*8;

s = s.setupImpl();

input = cell(1, s.in_ch_no + length(s.iio_dev_cfg.cfg_ch));
output = cell(1, s.out_ch_no + length(s.iio_dev_cfg.mon_ch));

% Set the attributes of AD9361
input{s.getInChannel('RX_LO_FREQ')} = 2e9;
input{s.getInChannel('RX_SAMPLING_FREQ')} = 40e6;
input{s.getInChannel('RX_RF_BANDWIDTH')} = 20e6;
input{s.getInChannel('RX1_GAIN_MODE')} = 'manual';%% slow_attack manual
input{s.getInChannel('RX1_GAIN')} = 10;
% input{s.getInChannel('RX2_GAIN_MODE')} = 'slow_attack';
% input{s.getInChannel('RX2_GAIN')} = 0;
input{s.getInChannel('TX_LO_FREQ')} = 2e9;
input{s.getInChannel('TX_SAMPLING_FREQ')} = 40e6;
input{s.getInChannel('TX_RF_BANDWIDTH')} = 20e6;

%Test = 1;

ACK = 0;
totalseqnum = 8; %总序号数
if (totalseqnum+1)/2 == fix((totalseqnum+1)/2) %计算窗口大小，采用slidewindow里SWS的设置方式。对N的选取要判断算出的数值是否为整数
    N = floor((totalseqnum+1)/2) - 1;
else %是小数
    N = floor((totalseqnum+1)/2);
end
send_base = 0; %基序号，最早未确认的序号
nextseqnum = 0; %下一个序号，最小未使用的序号
clocklist(totalseqnum,6) = 0;    %预先定义相应数量的定时器
acklist(totalseqnum) = 0;   %ACK列表
ackstr = 'ACK';
window_slided = 0; %判断窗口是否滑动
% Test = 1;

disp(['Now is sending:',num2str(0),' to ',num2str(N -1)]);

while(1)

    while(inwindow(send_base,N,totalseqnum-1,nextseqnum))   %SWS中仍有未发送的包
        msgstr = 'hello';
        strbuf = [num2str(nextseqnum),msgstr];
        txdata = bpsk_tx_func(strbuf);
        txdata = round(txdata .* 2^14);
        txdata = repmat(txdata, 8,1);
        input{1} = real(txdata);
        input{2} = imag(txdata);
        Tx(s, input);
        disp(['Transmit:',strbuf]);
        clocklist(nextseqnum+1,1:6) = clock;       %开启此帧的定时器
        nextseqnum = mod(nextseqnum + 1, totalseqnum);    %未使用序号下移
        pause(0.2);
    end
    for index = send_base : send_base + N - 1   %检测是否超时
        retransmition_index = mod(index, totalseqnum);
        if acklist(retransmition_index + 1) == 0
            if (etime(clock, clocklist(retransmition_index+1,1:6))>10)   %超时重传
                clocklist(retransmition_index+1,1:6) = clock; %重启相应的定时器
                msgstr = 'hello';
                strbuf = [num2str(mod(retransmition_index,totalseqnum)),msgstr];
                txdata = bpsk_tx_func(strbuf);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                Tx(s, input);
                disp(['retransmit:',strbuf]);
                pause(0.2);
            end
        end
    end
%          %Test 先到达1包
%      if Test == 1
%      strbuf = ['1',ackstr];
%      txdata = bpsk_tx_func(strbuf);
%      txdata = round(txdata .* 2^14);
%      txdata = repmat(txdata, 8,1);
%      input{1} = real(txdata);
%      input{2} = imag(txdata);
%      Tx(s, input);
%      Test = 0;
%      end
%      %Test 结束
    output = Rx(s);    %接收消息
    I = output{1};
    Q = output{2};
    Rxdata = I+1i*Q;
    [msgStr,crcResult] = bpsk_rx_func(Rxdata);
%     disp(msgStr);
    if strcmp(crcResult,'YES') == 1 && strcmp(msgStr(2:4),'ACK') == 1 %接收到ACK
        disp(['received:',msgStr]);
        rcvSN = str2num(msgStr(1));
        if inwindow(send_base, N, totalseqnum - 1, rcvSN)
            acklist(rcvSN + 1) = 1;
        end
        while(acklist(send_base + 1) == 1) %send_base移动到最近的未被确认的SN号处
            window_slided = 1;
            clocklist(send_base + 1,1:6) = [2030,3,1,0,8,1.1111];         %停止计时器操作;
            acklist(send_base + 1) = 0;
            send_base = mod(send_base + 1, totalseqnum);
        end   
        if window_slided == 1   %窗口滑动
            window_slided = 0;
            disp(['Window has slided. New window is sending:',num2str(send_base),' to ',num2str(mod(send_base + N -1, totalseqnum))]);
        end
%          %Test 再收到0包
%          strbuf = ['0',ackstr];
%          txdata = bpsk_tx_func(strbuf);
%          txdata = round(txdata .* 2^14);
%          txdata = repmat(txdata, 8,1);
%          input{1} = real(txdata);
%          input{2} = imag(txdata);
%          Tx(s, input);
%          %Test 结束
    end
end


% Read the RSSI attributes of both channels
rssi1 = output{s.getOutChannel('RX1_RSSI')};
% rssi2 = output{s.getOutChannel('RX2_RSSI')};

s.releaseImpl();






