clearvars -except times;close all;warning off;
set(0,'defaultfigurecolor','w');
addpath ..\..\library
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

Test = 1;

ACK = 0;
maxseqnum = 4; %最大序号数
N = floor((maxseqnum+1)/2); %回退N步的N数，采用slidewindow里SWS的设置方式
base = 0; %基序号，最早未确认的序号
nextseqnum = 0; %下一个序号，最小未使用的序号

while(1)
    while(nextseqnum < base + N)   %SWS中仍有未发送的包
        msgstr = 'xxx';
        strbuf = [num2str(nextseqnum),msgstr];
        txdata = bpsk_tx_func(strbuf);
        txdata = round(txdata .* 2^14);
        txdata = repmat(txdata, 8,1);
        input{1} = real(txdata);
        input{2} = imag(txdata);
        Tx(s, input);
        disp(['Transmitted:',strbuf]);
        if (base == nextseqnum)   %开始发送，开始计时
            t1 = clock;
        end
        nextseqnum = nextseqnum+1;    %未使用序号下移
    end
    t2 = clock;
    if (etime(t2, t1)>10)   %超时重传
        for index = base : (nextseqnum-1)
            disp(['retransmit:',num2str(index)]);
            t1 = clock;         %重新启动定时器
            t2 = clock;
            msgstr = 'xxx';
            strbuf = [num2str(index),msgstr];
            txdata = bpsk_tx_func(strbuf);
            txdata = round(txdata .* 2^14);
            txdata = repmat(txdata, 8,1);
            input{1} = real(txdata);
            input{2} = imag(txdata);
            Tx(s, input);
        end
    end
    
    if Test == 1%%Test 收到 0序号，发送ACK
        msgstr = ['0','ACK'];
        txdata = bpsk_tx_func(msgstr);
        txdata = round(txdata .* 2^14);
        txdata = repmat(txdata, 8,1);
        input{1} = real(txdata);
        input{2} = imag(txdata);
        Tx(s, input);
        Test = 0;
    end
    %%Test 结束
    
    output = Rx(s);
    I = output{1};
    Q = output{2};
    Rxdata = I+1i*Q;
    [msgStr,crcResult] = bpsk_rx_func(Rxdata);
    if strcmp(crcResult,'YES') == 1 && str2num(msgStr(1)) == base && strcmp(msgStr(2:4),'ACK') == 1
        disp(['received:',msgStr(1)]);
        base = str2num(msgStr(1)) + 1;
        if base == nextseqnum
            t1 = [2030,3,1,0,8,1.1111];         %停止计时器操作
            disp('stoped!!!');
        else
            t1 = clock;           %重新启动定时器
            t2 = clock;
        end
        %Test 收到1包
        msgstr = ['1','ACK'];
        txdata = bpsk_tx_func(msgstr);
        txdata = round(txdata .* 2^14);
        txdata = repmat(txdata, 8,1);
        input{1} = real(txdata);
        input{2} = imag(txdata);
        Tx(s, input);
        %Test 结束
    else 
        if strcmp(crcResult,'YES') == 1 && str2num(msgStr(1)) ~= base
            continue
        end
    end
end


% Read the RSSI attributes of both channels
rssi1 = output{s.getOutChannel('RX1_RSSI')};
% rssi2 = output{s.getOutChannel('RX2_RSSI')};

s.releaseImpl();






