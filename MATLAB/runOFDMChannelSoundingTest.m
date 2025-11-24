function results = runOFDMChannelSoundingTest(testCfg)
%RUNOFDMSDRCHANNELSOUNDINGTEST Launch TX/RX OFDM sounding functions in parallel.
%
%   results = runOFDMChannelSoundingTest(testCfg) starts the Pluto-based OFDM
%   sounding transmitter and receiver in parallel workers, waits for both to
%   finish, and returns their diagnostic structs. This helper is convenient for
%   quick regression checks.
%
%   TESTCFG is an optional struct with fields:
%       RunDuration       - Duration in seconds for both TX and RX (default 10)
%       TxConfig          - Struct of overrides passed to TX_SDR_OFDM_Channel_Sounding
%       RxConfig          - Struct of overrides passed to RX_SDR_OFDM_Channel_Sounding
%       StartupPause      - Seconds to wait after TX starts before launching RX
%                           (default 1)
%
%   Example:
%       results = runOFDMChannelSoundingTest(struct( ...
%                     'RunDuration', 15, ...
%                     'TxConfig', struct('RadioID',"usb:0"), ...
%                     'RxConfig', struct('RadioID',"usb:1")) );
%
%   The function requires the Parallel Computing Toolbox.

if nargin < 1 || isempty(testCfg)
    testCfg = struct();
end

defaultRunDuration = 10;
defaultStartupPause = 1;

runDuration = getfieldwithdefault(testCfg,'RunDuration',defaultRunDuration);
startupPause = getfieldwithdefault(testCfg,'StartupPause',defaultStartupPause);

validateattributes(runDuration, {'double'},{'scalar','real','>=',0});
validateattributes(startupPause, {'double'},{'scalar','real','>=',0});

txConfig = getfieldwithdefault(testCfg,'TxConfig',struct());
rxConfig = getfieldwithdefault(testCfg,'RxConfig',struct());

txConfig = mergeStruct(struct( ...
    'RunDuration', runDuration, ...
    'DataParams', struct('enableScopes', true)), txConfig);

rxConfig = mergeStruct(struct( ...
    'RunDuration', runDuration, ...
    'DisplayUpdates', true, ...
    'DataParams', struct('enableScopes', true)), rxConfig);

if isempty(gcp('nocreate'))
    parpoolArgs = {};
    if feature('numcores') >= 2
        parpoolArgs = [{'local'}, num2cell(2)];
    end
    parpool(parpoolArgs{:});
end

results = struct('txLog',[],'rxLog',[]);
futures = parallel.FevalFuture.empty(0,2);

try
    futures(1) = parfeval(@TX_SDR_OFDM_Channel_Sounding, 1, txConfig);
    pause(startupPause);
    futures(2) = parfeval(@RX_SDR_OFDM_Channel_Sounding, 1, rxConfig);

    for idx = 1:2
        [completedIdx, value] = fetchNext(futures);
        if completedIdx == 1
            results.txLog = value;
        else
            results.rxLog = value;
        end
    end
catch ME
    cancel(futures(isvalid(futures)));
    rethrow(ME);
end

end

%% Local helper functions
function value = getfieldwithdefault(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function out = mergeStruct(defaults, overrides)
out = defaults;
if isempty(overrides)
    return;
end
fields = fieldnames(overrides);
for idx = 1:numel(fields)
    field = fields{idx};
    if isstruct(defaults) && isstruct(overrides.(field)) && isfield(defaults, field)
        out.(field) = mergeStruct(defaults.(field), overrides.(field));
    else
        out.(field) = overrides.(field);
    end
end
end

