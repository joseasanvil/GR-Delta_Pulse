function txLog = TX_SDR_OFDM_Channel_Sounding(config)
%TX_SDR_OFDM_CHANNEL_SOUNDING Continuous OFDM sounding with a Pluto SDR transmitter.
%
%   txLog = TX_SDR_OFDM_Channel_Sounding(config) configures an OFDM waveform,
%   streams it to a Pluto SDR using transmitRepeat, and keeps the transmission
%   active for the requested duration. The helper-based OFDM framing matches
%   the MathWorks end-to-end example, enabling a companion receiver to perform
%   channel estimation. The function returns basic diagnostics suitable for
%   coordination from a test harness (for example, launched via PARFEVAL).
%
%   CONFIG is an optional struct supporting the following fields:
%       OFDMParams        - struct overriding default OFDM parameters
%       DataParams        - struct overriding default data parameters
%       RadioDevice       - radio platform (default "PLUTO")
%       RadioID           - Pluto SDR identifier (default "usb:0")
%       CenterFrequency   - RF center frequency in Hz (default 3.0e9)
%       Gain              - Pluto TX gain in dB (default 0)
%       RunDuration       - Duration in seconds to transmit (default 10).
%                           Use Inf for indefinite operation (cancel the
%                           parallel future to stop).
%       ShowResourceGrid  - logical flag to visualize the OFDM resource grid
%
%   Example:
%       txCfg = struct('RunDuration', 15, ...
%                      'DataParams', struct('enableScopes', false));
%       futureTx = parfeval(@TX_SDR_OFDM_Channel_Sounding, 1, txCfg);
%
%   The helper functions in this folder must be on the MATLAB path.
%
%   Copyright 2024

if nargin < 1 || isempty(config)
    config = struct();
end

% Reset persistent helper state (important when functions are launched on
% parallel workers).
clear helperOFDMTxInit helperOFDMTx;

% Default OFDM and data configuration
defaultOFDM = struct( ...
    'FFTLength',              128, ...
    'CPLength',               32, ...
    'NumSubcarriers',         72, ...
    'Subcarrierspacing',      30e3, ...
    'PilotSubcarrierSpacing', 9, ...
    'channelBW',              3e6);

defaultData = struct( ...
    'modOrder',       2, ...
    'coderate',       "1/2", ...
    'numSymPerFrame', 30, ...
    'numFrames',      10000, ...
    'enableScopes',   true, ...
    'verbosity',      false);

txOptions = struct( ...
    'RadioDevice',      "PLUTO", ...
    'RadioID',          "usb:0", ...
    'CenterFrequency',  3.0e9, ...
    'Gain',             0, ...
    'RunDuration',      120, ...
    'ShowResourceGrid', true);

% Merge user overrides
OFDMParams = mergeStruct(defaultOFDM, getfieldwithdefault(config,'OFDMParams',struct()));
dataParams = mergeStruct(defaultData, getfieldwithdefault(config,'DataParams',struct()));

txOptions.RadioDevice      = getfieldwithdefault(config,'RadioDevice',txOptions.RadioDevice);
txOptions.RadioID          = getfieldwithdefault(config,'RadioID',txOptions.RadioID);
txOptions.CenterFrequency  = getfieldwithdefault(config,'CenterFrequency',txOptions.CenterFrequency);
txOptions.Gain             = getfieldwithdefault(config,'Gain',txOptions.Gain);
txOptions.RunDuration      = getfieldwithdefault(config,'RunDuration',txOptions.RunDuration);
txOptions.ShowResourceGrid = getfieldwithdefault(config,'ShowResourceGrid',txOptions.ShowResourceGrid);

validateattributes(txOptions.RunDuration, {'double'},{'scalar','real','>=',0});

% Derive OFDM system parameters and generate one sounding frame
[sysParam, txParam, knownPayload] = helperOFDMSetParamsSDR(OFDMParams, dataParams);
sampleRate = sysParam.scs * sysParam.FFTLen;
sysParam.frameNum = 1;

% Generate waveform
txObj = helperOFDMTxInit(sysParam);
txParam.txDataBits = knownPayload(:);
[txFrame, txGrid] = helperOFDMTx(txParam, sysParam, txObj);

% Repeat to satisfy Pluto SDR minimum buffer requirements
frameLength = length(txFrame);
if contains(txOptions.RadioDevice, "PLUTO", "IgnoreCase", true) && frameLength < 48000
    repeatCount = ceil(48000 / frameLength);
else
    repeatCount = 1;
end
txWaveform = repmat(txFrame, repeatCount, 1);

% Instantiate SDR objects
ofdmTx = helperGetRadioParams(sysParam, txOptions.RadioDevice, sampleRate, ...
    txOptions.CenterFrequency, txOptions.Gain);
settingsSDR = struct("RadioID", txOptions.RadioID);
[txRadio, txSpectrumScope] = helperGetRadioTxObj(ofdmTx, settingsSDR);
cleanupObj = onCleanup(@() releaseTxResources(txRadio, txSpectrumScope)); %#ok<NASGU>

% Optional visualization
if txOptions.ShowResourceGrid || dataParams.verbosity
    helperOFDMPlotResourceGrid(txGrid, sysParam);
end
if dataParams.enableScopes
    txSpectrumScope(txWaveform);
    % Plot the waveform in time domain
    signalAnalyzer(txWaveform);
end

% Start continuous transmission
disp('Starting Pluto SDR transmitRepeat with OFDM sounding waveform ...');
% transmitRepeat(txRadio, txWaveform);

runDuration = txOptions.RunDuration;
if isfinite(runDuration)
    stopTimer = tic;
    while toc(stopTimer) < runDuration
        transmitRepeat(txRadio, txWaveform);
    end
else
    % Indefinite operation; keep worker alive until cancelled externally.
    while true
        transmitRepeat(txRadio, txWaveform);
    end
end

% Prepare log information before objects are released
txLog = struct( ...
    'SampleRate',           sampleRate, ...
    'FrameLengthSamples',   frameLength, ...
    'RepeatedWaveformLen',  length(txWaveform), ...
    'RepeatFactor',         repeatCount, ...
    'RunDuration',          runDuration, ...
    'RadioID',              txOptions.RadioID, ...
    'CenterFrequency',      txOptions.CenterFrequency, ...
    'Gain',                 txOptions.Gain, ...
    'OFDMParams',           OFDMParams, ...
    'DataParams',           dataParams);

% Allow onCleanup to stop the transmission and release hardware automatically

end

%% Local helper functions
function out = mergeStruct(defaults, overrides)
out = defaults;
if isempty(overrides)
    return;
end
fields = fieldnames(overrides);
for idx = 1:numel(fields)
    out.(fields{idx}) = overrides.(fields{idx});
end
end

function value = getfieldwithdefault(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function releaseTxResources(radioObj, spectrumScope)
stopTransmission(radioObj);
try %#ok<TRYNC>
    release(spectrumScope);
end
try %#ok<TRYNC>
    release(radioObj);
end
clear helperOFDMTx helperOFDMTxInit;
clear helperOFDMSetParamsSDR helperGetRadioParams helperGetRadioTxObj;
end

function stopTransmission(radioObj)
if isempty(radioObj)
    return;
end
try %#ok<TRYNC>
    if isa(radioObj,'sdrtx') && isprop(radioObj,'Platform') && ...
            strcmpi(radioObj.Platform,'Pluto')
        cancelTransmission(radioObj);
    end
end
end

