% default options are in parenthesis after the comment
clear all;
%% set recording
strMouse = 'MB5';
strDate = '20190508';
dblInvertLeads = true; %is ch1 deepest?
dblStepPerLead = 25; %spacing in microns
dblCh1DepthFromPia = 2500;
strBlock = '9-11-12';
strDataSource = 'D:\Data\Raw\ePhys';
strStimLog = [strDataSource filesep 'StimLogs' filesep strMouse '_' strDate];
strDataTarget = 'D:\Data\Processed\ePhys';

% set paths
ops.root = [strDataSource filesep 'KiloSortBinaries']; % 'openEphys' only: where raw files are
ops.rec  = [strMouse '_' strDate '_B' strBlock]; %which recording to process

%% load stimulus info
%load logging file
strPathLogs = strcat(strDataSource,filesep,'StimLogs');
strSubDir = [strPathLogs filesep strMouse '_' strDate filesep];
sFiles = dir([strSubDir strDate '*_B' strBlock '_*.mat']);
if numel(sFiles) == 1
	sLog = load([strSubDir sFiles(1).name]);
end
structEP = sLog.structEP;

%% load triggers
sMetaData = struct;
sMetaData.Mytank = [strDataSource filesep 'DataTanksTDT' filesep strMouse '_' strDate];
sMetaData.Myblock = ['Block-' strBlock];
sMetaData = getMetaDataTDT(sMetaData);

%stim on
vecStimOnTime = sMetaData.Trials.stim_onset;
%trial count/ID
matWord = sMetaData.Trials.word;
[vecStimOnTime,matWord] = checkTriggersTDT(vecStimOnTime,matWord);
vecWordTime = matWord(:,1);
vecStimType = matWord(:,2);
if ~isnan(vecStimType(end)) && vecStimType(end) ~= numel(vecStimType)
	warning([mfilename ':CountMismatch'], sprintf('Trial count mismatch, # of triggers: %d; trial number: %d',numel(vecStimType),vecStimType(end)));
end
%stim off
if isfield(sMetaData.Trials,'stim_offset')
	vecStimOffTime = checkTriggersTDT(sMetaData.Trials.stim_offset,matWord);
elseif isfield(sMetaData.Trials,'target_onset')
	vecStimOffTime = checkTriggersTDT(sMetaData.Trials.target_onset,matWord);
else
	vecStimOffTime = vecStimOnTime + 0.5; %use 500 ms as default duration
end
%trial start time
if isfield(sMetaData.Trials,'trial')
	vecTrialStartTime = sMetaData.Trials.trial;
else
	vecTrialStartTime = vecWordTime;
end
intEphysTrial = numel(vecStimOffTime);

%% load clustered data into matlab using https://github.com/cortex-lab/spikes
% load some of the useful pieces of information from the kilosort and manual sorting results into a struct
strLoadDir = [ops.root filesep ops.rec];
sSpikes = loadKSdir(strLoadDir);
vecAllSpikeTimes = sSpikes.st;
vecAllSpikeClust = sSpikes.clu;
vecChannelDepth = (1:sSpikes.n_channels_dat)*dblStepPerLead;
vecChannelDepth = vecChannelDepth - max(vecChannelDepth);
if dblInvertLeads
	vecChannelDepth = vecChannelDepth(end:-1:1);
end
vecChannelDepth = vecChannelDepth + dblCh1DepthFromPia;

%% load the information from the cluster_groups.csv file with cluster labels
% cids is length nClusters, the cluster ID numbers
% cgs is length nClusters, the "cluster group":
% - 0 = noise
% - 1 = mua
% - 2 = good
% - 3 = unsorted
[vecClusterIdx, vecClusterType] = readClusterGroupsCSV([strLoadDir filesep 'cluster_groups.csv']);
intClusterNum = numel(vecClusterType);

%% get spike times and depth per cluster
[spikeAmps, vecAllSpikeDepth] = templatePositionsAmplitudes(sSpikes.temps, sSpikes.winv, sSpikes.ycoords, sSpikes.spikeTemplates, sSpikes.tempScalingAmps); 
indSingleUnits = vecClusterType==2;
indMultiUnits = vecClusterType==1;
vecSU_idx = vecClusterIdx(indSingleUnits);
vecMU_idx = vecClusterIdx(indMultiUnits);
intNumSU = numel(vecSU_idx);
intNumMU = numel(vecMU_idx);
%assign single unit spikes
SU_st = cell(1,intNumSU); %single unit spike times
SU_depth = nan(1,intNumSU); %single unit depths
for intClustSUA=1:intNumSU
	intClustIdx = vecSU_idx(intClustSUA);
	vecSpikeIDs = intClustIdx==vecAllSpikeClust;
	SU_depth(intClustSUA) = getFractionalEntry(vecChannelDepth,mean(vecAllSpikeDepth(vecSpikeIDs)));
	SU_st{intClustSUA} = vecAllSpikeTimes(vecSpikeIDs);
end
%assign multi unit spikes
MU_st = cell(1,intNumMU); %multi unit spike times
MU_depth = nan(1,intNumMU); %single unit depths
for intClustMUA=1:intNumMU
	intClustIdx = vecMU_idx(intClustMUA);
	vecSpikeIDs = intClustIdx==vecAllSpikeClust;
	MU_depth(intClustMUA) =  getFractionalEntry(vecChannelDepth,mean(vecAllSpikeDepth(vecSpikeIDs)));
	MU_st{intClustMUA} = vecAllSpikeTimes(vecSpikeIDs);
end

