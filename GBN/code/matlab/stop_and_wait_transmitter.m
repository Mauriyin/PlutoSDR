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
seqNum = 0;
i = 0;
for seqNum = 1:10
    msgstr = 'Youarenightmare';
    strbuf = [num2str(seqNum),msgstr];
    txdata = bpsk_tx_func(strbuf);
    txdata = round(txdata .* 2^14);
    txdata = repmat(txdata, 8,1);
    input{1} = real(txdata);
    input{2} = imag(txdata);
    Tx(s, input);
    t1 = clock;
    t2 = clock;
    while (etime(t2,t1)<10)
        output = Rx(s);
        I = output{1};
        Q = output{2};
        Rxdata = I+1i*Q;
        [msgStr,crcResult] = bpsk_rx_func(Rxdata);
        if strcmp(crcResult,'YES') == 1 && str2num(msgStr(1)) == seqNum && strcmp(msgStr(2:4),'ACK') == 1
            fprintf('Received Data Block %i\n',i);
            disp(['Data:',msgStr]);
            ACK = 1;
            break;
        else
            t2 = clock;
            continue;
        end
    end

    if ACK == 1
        seqNum = ~seqNum;
        ACK = 0;
    else
        Tx(s, input);
    end
end



% Read the RSSI attributes of both channels
rssi1 = output{s.getOutChannel('RX1_RSSI')};
% rssi2 = output{s.getOutChannel('RX2_RSSI')};

s.releaseImpl();






