%===========================================================================================
% Engineer: Vivienne Clark
% Organisation: Southampton Solent University
% Name: SRRC Filter Design in MATLAB
% Comments:
%   - In accordance with 
%   - Roll-Off (Alpha): 0.35
%   - Samples per symbol: 4
%   - Span: 10 symbols
%   - Taps: 41
% Outputs the filter taps in the format (which can be pasted directly into a VHDL file):
%  to_signed(    33, TAP_BITS),
% to_signed(  -168, TAP_BITS),
% to_signed(  -190, TAP_BITS),
% to_signed(   -39, TAP_BITS),
% to_signed(   123, TAP_BITS)
%==========================================================================================
clear;
clc;

%SRRC Parameters
alpha = 0.35;     %Roll-off factor
span_sym = 10;    %Span in symbols
sps = 4;          %Samples per symbol
TAP_BITS = 16;    %Number of bits for taps

NTAPS = span_sym * sps + 1; %Number of taps

%SRRC Taps Design
h = rcosdesign(alpha, span_sym, sps, 'sqrt');

%Normalise
h = h / sqrt(sum(h.^2));

%Quantise to 16 bits
scale = 2^(TAP_BITS - 1) - 1;          % full-scale for Q15
h_q = round(h * scale);     % quantized taps (integers)
h_q = max(min(h_q, 32767), -32768);  % safety clamp

% Print VHDL Coefficients
for i = 1:length(h_q)
    if i < length(h_q)
        fprintf('  to_signed(%6d, TAP_BITS),\n', h_q(i));
    else
        fprintf('  to_signed(%6d, TAP_BITS)\n', h_q(i));
    end
end

%Save Coefficients to Text File
filename = sprintf('srrc_taps_alpha%.2f_L%d_span%d.txt', alpha, sps, span_sym);
dlmwrite(filename, h_q, 'delimiter', '\n');

%Plots

%Impulse Response
figure;
stem(h, 'filled');
title(sprintf('SRRC Impulse Response'));
xlabel('Tap index');
ylabel('Amplitude');
grid on;

%Frequency Response
NFFT = 4096;
Hf = fftshift(fft(h, NFFT));
f = linspace(-0.5, 0.5, NFFT);   % normalized frequency
figure;
plot(f, 20*log10(abs(Hf) + 1e-12));
title(sprintf('SRRC Magnitude Response'));
xlabel('Normalized Frequency');
ylabel('Magnitude (dB)');
grid on;
