function [intCount,strTargetFile,vecChannels] = getBinKilofileFromTDT(strMouse, strDate, strBlock, intRefType, sMetaData, vecUseOddReferences, vecUseEvenReferences, vecTimeRange)
	%getBinKilofileFromTDT Transforms TDT raw data to KiloSort binary files
	%	[intCount,strTargetFile] = getBinKilofileFromTDT(strMouse, strDate, strBlock, intRefType, vecUseOddReferences, vecUseEvenReferences, vecTimeRange)
	%
	%inputs:
	%	- strMouse (string), name of experimental animal (e.g., 'Mouse1')
	%	- strDate (string/numeric), date of experiment (e.g., '20190101')
	%	- varBlock (string/numeric/cell), block of experiment (e.g., '1'),
	%			if cell array, defines the blocks that should be concatenated
	%	- intRefType (integer), 0=no re-referencing, 1=avg per odd/even
	%			channels, 2=use a subset of channels for re-referencing
	%	- [sMetaData] (structure), Optional
	%	- [vecUseOddReferences] (vector), Optional (Default: [29 31])
	%	- [vecUseEvenReferences] (vector), Optional (Default: [30 32])
	%	- [vecTimeRange] (vector/cell), Optional (Default: [0 inf])
	%Note that manual reference-channels are only used if intRefType==2
	%
	%output:
	%	- intCount (integer), output from writing binary data
	%	- strTargetFile (string), path and filename of output binary file
	%
	%Version History:
	%2019-02-06 Created based on Leonie's script and my other TDT data
	%			extraction functions. This function requires a
	%			pre-installed KiloSort toolbox.
	%				[by Jorrit Montijn]
	%2019-03-22 Added sMetaData as input [by JM]
	%2019-06-11 Added support for merging recordings [by JM]
	
	
	%% get paths and locations
	if iscell(strBlock)
		strNewBlockName = '';
		for intBlockNr=1:numel(strBlock)
			strThisBlock = num2str(strBlock{intBlockNr});
			cellBlock{intBlockNr} = strThisBlock;
			strNewBlockName = strcat(strNewBlockName,strThisBlock,'-');
		end
		strDate = num2str(strDate);
		strRec = [strMouse, '_', strDate,'_B', strNewBlockName(1:(end-1))];
	else
		cellBlock = {num2str(strBlock)};
		strDate = num2str(strDate);
		strRec = [strMouse, '_', strDate,'_B', cellBlock{1}];
	end
	%set and create paths
	strSourceDir = 'D:\Data\Raw\ePhys\DataTanksTDT\';
	strTargetDir = 'D:\Data\Raw\ePhys\KiloSortBinaries\';
	strSubDir = [strTargetDir, strRec,filesep];
	if ~exist(strSubDir,'dir')
		fprintf('Creating new path: "%s"\n',strSubDir);
		mkdir(strSubDir);
	end
	strTargetFile = [strSubDir,strRec,'_','all.bin'];
	
	%% check if target file exists
	if exist(strTargetFile,'file')
		warning([mfilename ':FileExists'],'File "%s" already exists! Please check if this is a mistake. Using old file for now...',strTargetFile);
		intCount = 0;
		return
	end
	
	%% Define which data to use
	if ~exist('sMetaData','var')
		sMetaData = struct;
	end
	if ~isfield(sMetaData,'Mytank')
		sMetaData.Mytank = strcat(strSourceDir,strMouse,'_',strDate);
	end
	if ~isfield(sMetaData,'CHAN')
		sMetaData.CHAN = 1:32;
	end
	if ~exist('vecTimeRange','var') || isempty(vecTimeRange)
		cellTimeRange = cellfill([0 inf],size(cellBlock)); %start and stop time of recording
	elseif iscell(vecTimeRange)
		cellTimeRange = vecTimeRange;
	elseif numel(vecTimeRange) == 2
		cellTimeRange = {vecTimeRange};
	end
	
	%% go through blocks
	matData = [];
	for intBlockNr = 1:numel(cellBlock)
		%% set block
		sMetaData.Myblock = strcat('Block-',cellBlock{intBlockNr});
		
		%% get timerange
		vecTimeRange = cellTimeRange{intBlockNr};
		
		%% open library
		fprintf('Loading meta-data for %s of tank "%s" [%s]\n',sMetaData.Myblock,sMetaData.Mytank,getTime);
		sMetaData = getMetaDataTDT(sMetaData);
		%% Get data from Tank into MATLAB
		intRawStream = find(ismember({sMetaData.strms(:).name},'dRAW'));
		dblRawSampf = sMetaData.strms(intRawStream).sampf;
		intRawChNr = sMetaData.strms(intRawStream).channels; %#ok<FNDSB>
		fprintf('Found %d channels; Recording length is %.3fs; retrieving time-range [%.3fs - %.3fs] for channels [%s\b] [%s]\n',intRawChNr,range(sMetaData.strms(intRawStream).timerange),vecTimeRange(1),vecTimeRange(end),sprintf('%d ',sMetaData.CHAN),getTime);
		[vecTimestamps,matBlockData,vecChannels] = getRawDataTDT(sMetaData,vecTimeRange);
		fprintf('Re-referencing now (type %d) on channels [%s\b]... [%s]\n',intRefType,sprintf('%d ',vecChannels),getTime);
		
		%Clean raw data, there is a 1-sample mismatch in top 2 channels
		for intCh = 31:32
			matBlockData(intCh,:) = circshift(matBlockData(intCh,:),[0 -1]);
			matBlockData(intCh,end) = matBlockData(intCh,end-1);
		end
		
		%% check if reference channels are supplied
		if ~exist('vecUseOddReferences','var') || isempty(vecUseOddReferences)
			vecUseOddReferences = [29 31];
		end
		if ~exist('vecUseEvenReferences','var') || isempty(vecUseEvenReferences)
			vecUseEvenReferences = [30 32];
		end
		
		%% clean up raw data
		% common average referencing
		switch intRefType
			case 1
				%re-reference odd by average of all odd channels, and even by even
				matBlockData(1:2:end,:) = bsxfun(@minus,matBlockData(1:2:end,:),cast(mean(matBlockData(1:2:end,:),1),'like',matBlockData)); %odd
				matBlockData(2:2:end,:) = bsxfun(@minus,matBlockData(2:2:end,:),cast(mean(matBlockData(2:2:end,:),1),'like',matBlockData)); %even
				
			case 2
				%re-reference odd by last two odd and even by last two even channels
				matBlockData(1:2:end,:) = bsxfun(@minus,matBlockData(1:2:end,:),cast(mean(matBlockData(vecUseOddReferences,:),1),'like',matBlockData)); %odd
				matBlockData(2:2:end,:) = bsxfun(@minus,matBlockData(2:2:end,:),cast(mean(matBlockData(vecUseEvenReferences,:),1),'like',matBlockData)); %even
			case 3
				%re-reference odd by median of all odd channels, and even by even
				matBlockData(1:2:end,:) = bsxfun(@minus,matBlockData(1:2:end,:),cast(median(matBlockData(1:2:end,:),1),'like',matBlockData)); %odd
				matBlockData(2:2:end,:) = bsxfun(@minus,matBlockData(2:2:end,:),cast(median(matBlockData(2:2:end,:),1),'like',matBlockData)); %even
			case 4
				%re-reference all by average
				matBlockData = bsxfun(@minus,matBlockData,cast(mean(matBlockData,1),'like',matBlockData)); %odd
		end
		%% append data
		matData = cat(2,matData,matBlockData);
		fprintf('Finished %s; total data size is now %d timepoints (%.1fs)\n',sMetaData.Myblock,size(matData,2),size(matData,2)/dblRawSampf);
	end
	%% write data to binary file
	ptrFile = fopen(strTargetFile,'a');
	fprintf('Pre-processing complete. Writing data to binary file "%s"... [%s]\n',strTargetFile,getTime);
	intCount = fwrite(ptrFile, matData,'int16');
	fclose(ptrFile);
	fprintf('Done! Output is %d [%s]\n',intCount,getTime);
	
