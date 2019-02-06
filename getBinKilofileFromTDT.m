function [intCount,strTargetFile] = getBinKilofileFromTDT(strMouse, strDate, strBlock, intRefType, vecUseOddReferences, vecUseEvenReferences)
	%getBinKilofileFromTDT Transforms TDT raw data to KiloSort binary files
	%	[intCount,strTargetFile] = getBinKilofileFromTDT(strMouse, strDate, strBlock, intRefType, vecUseOddReferences, vecUseEvenReferences)
	%
	%inputs:
	%	- strMouse (string), name of experimental animal (e.g., 'Mouse1')
	%	- strDate (string/numeric), date of experiment (e.g., '20190101')
	%	- strBlock (string/numeric), block of experiment (e.g., '1')
	%	- intRefType (integer), 0=no re-referencing, 1=avg per odd/even
	%			channels, 2=use a subset of channels for re-referencing
	%	- [vecUseOddReferences] (vector), Optional (Default: [29 31])
	%	- [vecUseEvenReferences] (vector), Optional (Default: [30 32])
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
	
	
	%% get paths and locations
	strBlock = num2str(strBlock);
	strDate = num2str(strDate);
	Tank.Name = strMouse;
	Tank.Date = strDate;
	Tank.Tankname = [Tank.Name '_' Tank.Date];
	Tank.Blockno = strBlock;
	strSourceDir = 'D:\Data\Raw\ePhys\DataTanksTDT\';
	strTargetDir = 'D:\Data\Raw\ePhys\KiloSortBinaries\';
	strRec = [strMouse, '_', Tank.Date,'_B', Tank.Blockno];
	strTargetFile = [strTargetDir, strRec,filesep,strRec,'_','all.bin'];
	
	%% check if target file exists
	if exist(strTargetFile,'file')
		warning([mfilename ':FileExists'],'File "%s" already exists! Please check if this is a mistake. Using old file for now...',strTargetFile);
		intCount = 0;
		return
	end
	
	%% Define which data to use
	sMetaData = struct;
	sMetaData.Mytank = strcat(strSourceDir,strMouse,'_',strDate);
	sMetaData.Myblock = strcat('Block-',strBlock);
	
	%% open library
	fprintf('Loading meta-data for %s of tank "%s" [%s]\n',sMetaData.Myblock,sMetaData.Mytank,getTime);
	sMetaData = getMetaDataTDT(sMetaData);
	
	%% Get data from Tank into MATLAB
	fprintf('Found %d channels; Recording length is %.3fs; retrieving raw data... [%s]\n',sMetaData.strms(1).channels(1),range(sMetaData.strms(1).timerange),getTime);
	[vecTimestamps,matData] = getRawDataTDT(sMetaData);
	fprintf('Raw data retrieved; re-referencing now (type %d)... [%s]\n',intRefType,getTime);
	
	%Clean raw data, there is a 1-sample mismatch in top 2 channels
	for intCh = 31:32
		matData(intCh,:) = circshift(matData(intCh,:),[0 -1]);
		matData(intCh,end) = matData(intCh,end-1);
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
			matData(1:2:end,:) = bsxfun(@minus,matData(1:2:end,:),cast(mean(matData(1:2:end,:),1),'like',matData)); %odd
			matData(2:2:end,:) = bsxfun(@minus,matData(2:2:end,:),cast(mean(matData(2:2:end,:),1),'like',matData)); %even
			
		case 2
			%re-reference odd by last two odd and even by last two even channels
			matData(1:2:end,:) = bsxfun(@minus,matData(1:2:end,:),cast(mean(matData(vecUseOddReferences,:),1),'like',matData)); %odd
			matData(2:2:end,:) = bsxfun(@minus,matData(2:2:end,:),cast(mean(matData(vecUseEvenReferences,:),1),'like',matData)); %even
	end
	
	%% write data to binary file
	ptrFile = fopen(strTargetFile,'a');
	fprintf('Pre-procssing complete. Writing data to binary file "%s"... [%s]\n',strTargetFile,getTime);
	intCount = fwrite(ptrFile, matData,'int16');
	fclose(ptrFile);
	fprintf('Done! Output is %d [%s]\n',intCount,getTime);
	
