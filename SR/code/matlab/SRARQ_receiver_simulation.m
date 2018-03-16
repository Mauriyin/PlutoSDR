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
totalseqnum = 4; %�������
if (totalseqnum+1)/2 == fix((totalseqnum+1)/2) %���㴰�ڴ�С������slidewindow��SWS�����÷�ʽ����N��ѡȡҪ�ж��������ֵ�Ƿ�Ϊ����
    N = floor((totalseqnum+1)/2) - 1;
else %��С��
    N = floor((totalseqnum+1)/2);
end
disp(['Waiting for the frame:',num2str(0),' to ',num2str(N-1)]);
rcv_base = 0; %����ţ�����δȷ�ϵ����
nextseqnum = 0; %��һ����ţ���Сδʹ�õ����
ackstr = 'ACK';
rcvbuffer = [];
window_slided = 0; %�жϴ����Ƿ񻬶�

Test = 1;

while(1)
    %Test ���յ�1��
        if Test == 1
        strbuf = ['1',ackstr];
        txdata = bpsk_tx_func(strbuf);
        txdata = round(txdata .* 2^14);
        txdata = repmat(txdata, 8,1);
        input{1} = real(txdata);
        input{2} = imag(txdata);
        Tx(s, input);
        Test = 0;
        end
    %Test ����
    
    output = Rx(s);    %������Ϣ
    I = output{1};
    Q = output{2};
    Rxdata = I+1i*Q;
    [msgStr,crcResult] = bpsk_rx_func(Rxdata);
    rcvSN = str2num(msgStr(1));
    disp(msgStr);
    if strcmp(crcResult,'YES') == 1
        if inwindow(rcv_base, N, totalseqnum - 1, rcvSN) %�ڽ��մ�����
            if ~ismember(rcvSN,rcvbuffer) %������û����Ӧ��SN��
                rcvbuffer = [rcvbuffer, rcvSN];  %����SN�Ų�����ACK
                strbuf = [num2str(rcvSN),ackstr];
                txdata = bpsk_tx_func(strbuf);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                Tx(s, input);
                disp(['SendNewframeACK:',strbuf]);
                while(ismember(rcv_base,rcvbuffer)) %rcv_base�ƶ��������δ�����յ���SN�Ŵ�
                    rcvbuffer(find(rcvbuffer==rcv_base))=[]; %ȥ���ڽ��ջ����е���Ӧ֡
                    rcv_base = mod(rcv_base + 1, totalseqnum);
                    window_slided = 1;
                end   
                if window_slided == 1;  %������ڻ�����Ϣ
                    window_slided = 0;
                    disp(['Window has slided. New window is waiting for the frame:',num2str(rcv_base),' to ',num2str(mod(rcv_base + N -1, totalseqnum))]);
                end
                %Test ���յ�0��
                strbuf = ['0',ackstr];
                txdata = bpsk_tx_func(strbuf);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                Tx(s, input);
                %Test ����
                
            else  %�Ѿ�����SN�ţ�����ֱ�ӷ���ACK
                strbuf = [num2str(rcvSN),ackstr];
                txdata = bpsk_tx_func(strbuf);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                Tx(s, input);
                disp(['SendOldframeACK:',strbuf]);
            end
        else
            if inwindow(mod(rcv_base-N,totalseqnum), N, totalseqnum - 1, rcvSN) %����ACK��֪���ͷ��Ѿ����չ���Ӧ�İ�
                strbuf = [num2str(rcvSN),ackstr];
                txdata = bpsk_tx_func(strbuf);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                Tx(s, input);
                disp(['Frame not in rcv window,send ACK again:',strbuf]);
            end
        end
    end
end

% Read the RSSI attributes of both channels
rssi1 = output{s.getOutChannel('RX1_RSSI')};
% rssi2 = output{s.getOutChannel('RX2_RSSI')};

s.releaseImpl();






