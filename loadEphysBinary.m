function [matDataBin,intCount] = loadEphysBinary(strFile,intChannels,strFormat)
	%UNTITLED3 Summary of this function goes here
	%   Detailed explanation goes here
	
	%get format
	if ~exist('strFormat','var')
		strFormat = 'int16';
	end
	
	%get size of format
	x=feval(strFormat,1);y=whos('x');intBytesPerValue=y.bytes;
	
	%get info on file
	sFiles = dir(strFile);
	if isempty(sFiles)
		error([mfilename ':FileNotFound'],sprintf('File "%s" could not be found',strFile));
	end
	
	%get size
	intTotSizeBytes = sFiles.bytes;
	intBytesPerChan = intTotSizeBytes/intChannels;
	intValuesPerChan = intBytesPerChan/intBytesPerValue;
	[ptrFile,strError] = fopen(strFile,'r');
	if isempty(strError)
		fprintf('Loading data from binary file "%s"... [%s]\n',strFile,getTime);
	else
		error([mfilename ':ReadError'],strError);
	end
	
	%read
	[matDataBin,intCount] = fread(ptrFile, [intChannels intValuesPerChan], strcat('*',strFormat));
	fclose(ptrFile);
end