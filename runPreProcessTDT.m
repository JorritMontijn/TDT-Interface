% default options are in parenthesis after the comment

%% define which recording to process
strMouse = 'MB2';
strDate = '20190315';
vecOriginalOrdering = [2 1 18 17 6 5 8 7 10 9 12 11 14 13 16 15 4 3 20 19 ...
	22 21 24 23 26 25 28 27 30 29 32 31];
[vecSorted,vecReorder] = sort(vecOriginalOrdering,'ascend');

%intBlock = 1;
for intBlock = [1:7 9:12]
%%
strBlock = num2str(intBlock);
intRefType = 1;
strDataRoot = 'D:\Data\Raw\ePhys';
strStimLog = [strDataRoot filesep 'StimLogs' filesep strMouse '_' strDate];
%% set paths
addpath(genpath('C:\Code\Acquisition\KiloSort')) % path to kilosort folder
addpath(genpath('C:\Code\Acquisition\npy-matlab')) % path to npy-matlab scripts

%set recording
ops.root = [strDataRoot filesep 'KiloSortBinaries']; % 'openEphys' only: where raw files are
ops.rec  = [strMouse '_' strDate '_B' strBlock]; %which recording to process

%% load stim logs
sStimLogs = dir([strStimLog filesep '*_B' strBlock '_*.mat']);
strLogFile = sStimLogs(1).name;
sStimLogData = load([strStimLog filesep strLogFile]);

%% get meta data from TDT data tank
sMetaData = struct;
sMetaData.Mytank = [strDataRoot filesep 'DataTanksTDT' filesep strMouse '_' strDate];
sMetaData.Myblock = ['Block-' strBlock];
sMetaData = getMetaDataTDT(sMetaData);

vecStimOnTime = sMetaData.Trials.stim_onset;
matWord = sMetaData.Trials.word;
[vecStimOnTime,matWord] = checkTriggersTDT(vecStimOnTime,matWord,sStimLogData);
vecStimType = matWord(:,2);

% get raw data
%[vecTimestamps,matData,vecChannels] = getRawDataTDT(sMetaData);
%intChannels = numel(vecChannels);

%% transform TDT files to KiloSort binaries
sMetaData.CHAN = vecReorder;
[intCountWrite,strTargetFile] = getBinKilofileFromTDT(strMouse, strDate, strBlock, intRefType, sMetaData);

%load binary file
%[matDataBin,intCountRead] = loadEphysBinary(strTargetFile,intChannels);

%% read config file for KiloSort
pathToYourConfigFile = 'C:\Code\Acquisition\TDT-Interface'; % take from Github folder and put it somewhere else (together with the master_file)
run(fullfile(pathToYourConfigFile, 'runConfigHeader_JM.m'));

%% pre-process using KiloSort
if exist(fullfile([ops.root filesep ops.rec], 'spike_times.npy'),'file')
	warning('spike_times.npy already exists! Skipping clustering...');
else
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
save(fullfile([ops.root filesep ops.rec],  'rez.mat'), 'rez', '-v7.3');

% save python results file for Phy
rezToPhy(rez, [ops.root filesep ops.rec]);

% remove temporary file
delete(ops.fproc);
end
end
% end processing, but we still want the interpreter to recognize the
% commands below, so we'll use a stupid work-around
if rand(1) >= 0,return;end

%% to run phy for clustering:
% 1) open anaconda
% 2) go to your output directory (i.e., [ops.root ops.rec]) (e.g., D:\Data\Raw\ePhys\KiloSortBinaries\Roku_20180514_B5)
% 3) type: activate phy
% 4) type: phy template-gui params.py
%
% For more info on phy-contrib's template-gui, see: 
%	https://github.com/kwikteam/phy-contrib/blob/master/docs/template-gui.md
%
%You can also directly copy these lines (one by one) into the matlab
%command window  (but note that matlab is locked in the mean time)
%{
!cmd
D:
cd D:\Data\Raw\ePhys\KiloSortBinaries\Roku_20180514_B5
C:\ProgramData\Miniconda3\Scripts\activate.bat C:\ProgramData\Miniconda3
activate phy
phy template-gui params.py
exit
%}

%% set recording
strMouse = 'MB2';
strDate = '20190315';
intBlock = 3;
strBlock = num2str(intBlock);
strDataRoot = 'D:\Data\Raw\ePhys';
strStimLog = [strDataRoot filesep 'StimLogs' filesep strMouse '_' strDate];

% set paths
ops.root = [strDataRoot filesep 'KiloSortBinaries']; % 'openEphys' only: where raw files are
ops.rec  = [strMouse '_' strDate '_B' strBlock]; %which recording to process

%% load stimulus info
%load logging file
strPathLogs = strcat(strDataRoot,filesep,'StimLogs');
strSubDir = [strPathLogs filesep strMouse '_' strDate filesep];
sFiles = dir([strSubDir strDate '*B*' strBlock '*.mat']);
if numel(sFiles) == 1
	sLog = load([strSubDir sFiles(1).name]);
end
structEP = sLog.structEP;

%load triggers
sMetaData = struct;
sMetaData.Mytank = [strDataRoot filesep 'DataTanksTDT' filesep strMouse '_' strDate];
sMetaData.Myblock = ['Block-' strBlock];
sMetaData = getMetaDataTDT(sMetaData);

vecStimOnTime = sMetaData.Trials.stim_onset;
matWord = sMetaData.Trials.word;
[vecStimOnTime,matWord] = checkTriggersTDT(vecStimOnTime,matWord,structEP);
vecStimType = matWord(:,2);

%% load clustered data into matlab using https://github.com/cortex-lab/spikes
% load some of the useful pieces of information from the kilosort and manual sorting results into a struct
strLoadDir = [ops.root filesep ops.rec];
sSpikes = loadKSdir(strLoadDir);

%% load the information from the cluster_groups.csv file with cluster labels
% cids is length nClusters, the cluster ID numbers
% cgs is length nClusters, the "cluster group":
% - 0 = noise
% - 1 = mua
% - 2 = good
% - 3 = unsorted
[vecClusterIdx, vecClusterType] = readClusterGroupsCSV([strLoadDir filesep 'cluster_groups.csv']);

%% transform data to spikes per cluster
vecAllSpikeTimes = sSpikes.st;
vecAllSpikeClust = sSpikes.clu;
vecSingleUnits = vecClusterIdx(vecClusterType==2);
intNumSU = numel(vecSingleUnits);
vecMultiUnits = vecClusterIdx(vecClusterType==1);
intNumMU = numel(vecMultiUnits);
%assign single unit spikes
SU_st = cell(1,intNumSU); %single unit spike times
for intClustSUA=1:intNumSU
	SU_st{intClustSUA} = vecAllSpikeTimes(vecAllSpikeClust==vecSingleUnits(intClustSUA));
end
%assign multi unit spikes
MU_st = cell(1,intNumMU); %multi unit spike times
for intClustMUA=1:intNumMU
	MU_st{intClustMUA} = vecAllSpikeTimes(vecAllSpikeClust==vecMultiUnits(intClustMUA));
end

%% make PSTH
%gather data
for intSU = 1:intNumSU
	vecSpikeTimes = SU_st{intSU};
	vecWindow = -0.5:0.05:1.5;
	vecEvents = vecStimOnTime;
	[vecMean,vecSEM] = doPEP(vecSpikeTimes,vecWindow,vecEvents);
	xlabel('Time from stim on (s)');
	ylabel('Spiking rate (Hz)');
	title(sprintf('Single Unit %d',intSU));
end

%% compute some useful things about your spikes and their waveform shapes, like the position along the probe and the amplitudes
% outputs: 
% - spikeAmps is length nSpikes vector with amplitude in unwhitened space of every spike
% - spikeDepths is the position along the probe of every spike (according to the position of the template it was extracted with)
% - templateDepths is the position along the probe of every template
% - templateAmps is the amplitude of each template
% - tempsUnW are the unwhitened templates
% - templateDuration is the trough-to-peak time (in samples)
% - waveforms: returns the waveform from the max-amplitude channel
temps = sSpikes.temps;
winv = sSpikes.winv;
ycoords = sSpikes.ycoords;
spikeTemplates = sSpikes.spikeTemplates;
tempScalingAmps = sSpikes.tempScalingAmps;
[spikeAmps, spikeDepths, templateDepths, tempAmps, tempsUnW, templateDuration, waveforms] = ...
	templatePositionsAmplitudes(temps, winv, ycoords, spikeTemplates, tempScalingAmps); 
    
%% retrieve waveforms
% wf.unitIDs                               % [nClu,1]            List of cluster IDs; defines order used in all wf.* variables
% wf.spikeTimeKeeps                        % [nClu,nWf]          Which spike times were used for the waveforms
% wf.waveForms                             % [nClu,nWf,nCh,nSWf] Individual waveforms
% wf.waveFormsMean                         % [nClu,nCh,nSWf]     Average of all waveforms (per channel)
%                                          % nClu: number of different clusters in .spikeClusters
%                                          % nSWf: number of samples per waveform
% WARNING: this requires a lot of RAM, and may take quite long
dblFrac = 0.10; % fraction of all spikes to sample from
sParamsWF.sr = sSpikes.sample_rate;
sParamsWF.dataDir = strLoadDir;
sParamsWF.fileName = [ops.rec '_all.bin'];
sParamsWF.dataType = sSpikes.dtype;
sParamsWF.nCh = sSpikes.n_channels_dat;
sParamsWF.wfWin = round([-(0.001*sParamsWF.sr) 0.002*sParamsWF.sr]); % Number of samples before and after spiketime to include in waveform
sParamsWF.nWf = floor(length(sSpikes.st) * dblFrac);
sParamsWF.spikeTimes = ceil(sSpikes.st * sSpikes.sample_rate);
sParamsWF.spikeClusters = sSpikes.clu;
sOutWF = getWaveForms(sParamsWF);