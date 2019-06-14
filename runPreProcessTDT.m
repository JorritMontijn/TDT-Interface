% default options are in parenthesis after the comment

%% define which recording to process
strMouse = 'MB4';
strDate = '20190516';
%vecOriginalOrdering = [2 1 18 17 6 5 8 7 10 9 12 11 14 13 16 15 4 3 20 19 ...
%	22 21 24 23 26 25 28 27 30 29 32 31];
%[vecSorted,vecReorder] = sort(vecOriginalOrdering,'ascend');
vecReorder=1:32;
vecTimeRange = [];
cellBlock = {2};

%%
intRefType = 1;
strDataRoot = 'D:\Data\Raw\ePhys';
strStimLog = [strDataRoot filesep 'StimLogs' filesep strMouse '_' strDate];
%% set paths
addpath(genpath('C:\Code\Acquisition\KiloSort')) % path to kilosort folder
addpath(genpath('C:\Code\Acquisition\npy-matlab')) % path to npy-matlab scripts


%% transform TDT files to KiloSort binaries
[intCountWrite,strTargetFile] = getBinKilofileFromTDT(strMouse, strDate, cellBlock, intRefType);
strBlock = getFlankedBy(strTargetFile,'_B','_all','last');

%set recording
ops.root = [strDataRoot filesep 'KiloSortBinaries']; % 'openEphys' only: where raw files are
ops.rec  = [strMouse '_' strDate '_B' strBlock]; %which recording to process

%load binary file
[matDataBin,intCountRead] = loadEphysBinary(strTargetFile,numel(vecReorder));

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
