% default options are in parenthesis after the comment

%% define which recording to process
strMouse = 'Roku';
strDate = '20180514';
strBlock = '5';
intRefType = 2;

%% set paths
addpath(genpath('C:\Code\Acquisition\KiloSort')) % path to kilosort folder
addpath(genpath('C:\Code\Acquisition\npy-matlab')) % path to npy-matlab scripts

%set recording
ops.root = 'D:\Data\Raw\ePhys\KiloSortBinaries'; % 'openEphys' only: where raw files are
ops.rec  = 'Roku_20180514_B5'; %which recording to process

%% transform TDT files to KiloSort binaries
[intCount,strTargetFile] = getBinKilofileFromTDT(strMouse, strDate, strBlock, intRefType);

%% read config
pathToYourConfigFile = 'C:\Code\Acquisition\TDT-Interface'; % take from Github folder and put it somewhere else (together with the master_file)
run(fullfile(pathToYourConfigFile, 'runConfigHeader_JM.m'));

%% pre-process using KiloSort
tic; % start timer
%
if ops.GPU     
    gpuDevice(1); % initialize GPU (will erase any existing GPU arrays)
end

if strcmp(ops.datatype , 'openEphys')
   ops = convertOpenEphysToRawBInary(ops);  % convert data, only for OpenEphys
end
%
[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

% AutoMerge. rez2Phy will use for clusters the new 5th column of st3 if you run this)
%     rez = merge_posthoc2(rez);

% save matlab results file
save(fullfile(ops.root,  'rez.mat'), 'rez', '-v7.3');

% save python results file for Phy
rezToPhy(rez, ops.root);

% remove temporary file
delete(ops.fproc);

%% to run phy for clustering:
% 1) open anaconda
% 2) go to your output directory (i.e., [ops.root ops.rec]) (e.g., D:\Data\Raw\ePhys\KiloSortBinaries\Roku_20180514_B5)
% 3) type: activate phy
% 4) type: phy template-gui params.py
%
% For more info on phy-contrib's template-gui, see: 
%	https://github.com/kwikteam/phy-contrib/blob/master/docs/template-gui.md
%
