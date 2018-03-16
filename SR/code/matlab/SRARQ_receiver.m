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

ACK = 0;
totalseqnum = 8; %总序号数
if (totalseqnum+1)/2 == fix((totalseqnum+1)/2) %计算窗口大小，采用slidewindow里SWS的设置方式。对N的选取要判断算出的数值是否为整数
    N = floor((totalseqnum+1)/2) - 1;
else %是小数
    N = floor((totalseqnum+1)/2);
end
disp(['Waiting for the frame:',num2str(0),' to ',num2str(N-1)]);
rcv_base = 0; %基序号，最早未确认的序号
nextseqnum = 0; %下一个序号，最小未使用的序号
ackstr = 'ACK';
rcvbuffer = [];
window_slided = 0; %判断窗口是否滑动
print_new = 1;   %优化打印
print_old = 1;  %优化打印
print_notinwin = 1; %优化打印
last_SN = 999;    %优化打印
% Test = 1;

while(1)
%     %Test 先收到1包
%         if Test == 1
%         strbuf = ['1xxx'];
%         txdata = bpsk_tx_func(strbuf);
%         txdata = round(txdata .* 2^14);
%         txdata = repmat(txdata, 8,1);
%         input{1} = real(txdata);
%         input{2} = imag(txdata);
%         Tx(s, input);
%         Test = 0;
%         end
%     %Test 结束
    
    output = Rx(s);    %接收消息
    I = output{1};
    Q = output{2};
    Rxdata = I+1i*Q;
    [msgStr,crcResult] = bpsk_rx_func(Rxdata);
    rcvSN = str2num(msgStr(1));
    %disp(msgStr);
    if last_SN ~= rcvSN  %优化打印,本次与上次接收到的序号不相等，开启打印
        print_new = 1;
        print_old = 1;
        print_notinwin = 1;
    end
%     disp(msgStr);
    if strcmp(crcResult,'YES') == 1
        if inwindow(rcv_base, N, totalseqnum - 1, rcvSN) %在接收窗口内
            if ~ismember(rcvSN,rcvbuffer) %缓存中没有相应的SN号
                rcvbuffer = [rcvbuffer, rcvSN];  %缓存SN号并返回ACK
                strbuf = [num2str(rcvSN),ackstr];
                txdata = bpsk_tx_func(strbuf);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                Tx(s, input);
                %disp(['Rcvd New frame in rcv window, put it into the buffer and send New ACK:',strbuf]);
                if print_new == 1 %优化打印
                    disp(['received:',msgStr]);
                    disp(['Rcvd New frame in rcv window, sit in buffer adn new ACK:',strbuf]);
                    print_new = 0;
                end
                while(ismember(rcv_base,rcvbuffer)) %rcv_base移动到最近的未被接收到的SN号处
                    rcvbuffer(find(rcvbuffer==rcv_base))=[]; %去除在接收缓存中的相应帧
                    rcv_base = mod(rcv_base + 1, totalseqnum);
                    window_slided = 1;
                end   
                if window_slided == 1;  %输出窗口滑动信息
                    window_slided = 0;
                    disp(['Window has slided. New window is waiting for the frame:',num2str(rcv_base),' to ',num2str(mod(rcv_base + N -1, totalseqnum))]);
                end
%                 %Test 再收到0包
%                 strbuf = ['0xxx'];
%                 txdata = bpsk_tx_func(strbuf);
%                 txdata = round(txdata .* 2^14);
%                 txdata = repmat(txdata, 8,1);
%                 input{1} = real(txdata);
%                 input{2} = imag(txdata);
%                 Tx(s, input);
%                 %Test 结束
                
            else  %已经缓存SN号，可以直接返回ACK
                strbuf = [num2str(rcvSN),ackstr];
                txdata = bpsk_tx_func(strbuf);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                Tx(s, input);
                %disp(['Rcvd Old frame in rcv window, only send old ACK',strbuf]);
                if print_old == 1  %优化打印
                    disp(['received:',msgStr]);
                    disp(['Rcvd Old frame in rcv window, only send old ACK:',strbuf]);
                    print_old = 0;
                end    
            end
        else
            if inwindow(mod(rcv_base-N,totalseqnum), N, totalseqnum - 1, rcvSN) %发送ACK告知发送方已经接收过相应的包
                strbuf = [num2str(rcvSN),ackstr];
                txdata = bpsk_tx_func(strbuf);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                Tx(s, input);
                %disp(['Frame not in rcv window,send ACK again:',strbuf]);
                if print_notinwin == 1 %优化打印
                    disp(['received:',msgStr]);
                    disp(['Frame not in rcv window,send ACK again:',strbuf]);
                    print_notinwin = 0;
                end
            end
        end
        last_SN = rcvSN; %优化打印
        pause(0.2);
    end
end

% Read the RSSI attributes of both channels
rssi1 = output{s.getOutChannel('RX1_RSSI')};
% rssi2 = output{s.getOutChannel('RX2_RSSI')};

s.releaseImpl();






