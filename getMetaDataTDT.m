function sMetaData = getMetaDataTDT(sMetaData,intVerbose)
	%getMetaDataTDT Extracts metadata from TDT data tank
	%	sMetaData = getMetaDataTDT(sMetaData)
	%
	%If used in a batch file you must initialize these values:
	%input: sMetaData.Mytank = 'the tank you want to read from';
	%       sMetaData.Myblock = 'the block you want to read from';
	%
	%output: sMetaData ;  a structure containing a lot of info
	%        sMetaData.Trials ; a structure containing trial timing and info
	%
	%Version History:
	%2019-02-01 Created metadata retrieval function, based on Chris van der
	%			Togt's Exinf() function. Changes are mostly cosmetic,
	%			except for several error checks and optimizations
	%				[by Jorrit Montijn]
	%2019-02-04 Finished rebuilding, and added to github repository [by JM]
	%2019-05-01 Added support for SCALAR triggers [by JM]
	
	%% get verbosity
	if ~exist('intVerbose','var') || isempty(intVerbose)
		intVerbose = 1;
	end
	
	%% define event codes
	sEventCode.UNKNOWN = hex2dec('0');  %"Unknown"; UNUSED
	sEventCode.STRON = hex2dec('101');  % Strobe ON "Strobe+"
	sEventCode.STROFF = hex2dec('102');  % Strobe OFF "Strobe-"; UNUSED
	sEventCode.SCALAR = hex2dec('201');  % Scalar "Scalar"; UNUSED
	sEventCode.STREAM = hex2dec('8101');  % Stream "Stream"
	sEventCode.SNIP = hex2dec('8201');  % Snip "Snip"
	sEventCode.MARK = hex2dec('8801');  % "Mark"; UNUSED
	sEventCode.HASDATA = hex2dec('8000');  % has associated waveform data "HasData"; UNUSED
	
	%% event info indexes
	sInfoCodes.SIZE   = 1; %size of waveform data in bytes
	sInfoCodes.TYPE   = 2; %event type
	sInfoCodes.EVCODE = 3; %event code
	sInfoCodes.CHAN   = 4; %channel number
	sInfoCodes.SORT   = 5; %sorting number
	sInfoCodes.TIME   = 6; %time stamp
	sInfoCodes.SCVAL  = 7; %scalar value (valid when no waveform data is attached)
	sInfoCodes.FORMAT  = 8; %data format code
	sInfoCodes.HZ     = 9; %waveform sample rate in Hz (requires attached wavefrom data)
	sInfoCodes.ALL    = 0;
	
	%% load libraries
	ptrFig = figure('visible','off');
	ptrLib = actxcontrol('TTANK.X',[0 0 20 20],ptrFig);
	boolConnected = ptrLib.ConnectServer('local','me');
	boolTankLoaded = ptrLib.OpenTank(sMetaData.Mytank, 'R');
	boolBlockLoaded = ptrLib.SelectBlock(sMetaData.Myblock);
	
	%% check if loading has gone correctly
	if ~all(cat(1,boolConnected,boolTankLoaded,boolBlockLoaded))
		cellSuccess = {'FAILED','SUCCESS'};
		error([mfilename ':LoadingError'],sprintf('Loading error; Libraries: %s, Tank: %s, Block: %s',...
			cellSuccess{1+double(boolConnected>0)},cellSuccess{1+double(boolTankLoaded>0)},cellSuccess{1+double(boolBlockLoaded>0)})); %#ok<*SPERR>
	end
	
	%% load stream metadata
	vecLongEvCo = ptrLib.GetEventCodes(sEventCode.STREAM); %gets the long codes of event types
	intStreamTypes = size(vecLongEvCo,2);
	cellStreamNames = cell(intStreamTypes,1);
	if ~isnan(vecLongEvCo)
		for intStreamType = 1:intStreamTypes
			%retrieve name for stream type
			cellStreamNames{intStreamType} = ptrLib.CodeToString(vecLongEvCo(intStreamType));
			strStreamName = char(cellStreamNames{intStreamType});
			
			%readEventsV() must be usef first to sets the read pointer to
			%the requested stream, otherwise ParseEvV() will return the
			%previous stream's data instead. 1000 requests the first 1000
			%events, which are sequentially ordered by channel.
			intReadInitialEventNum = 1000;
			intEventNum = ptrLib.ReadEventsV(intReadInitialEventNum, strStreamName, 0, 0, 0, 0, 'ALL'); %read in number of events
			%In order to extract the number of channels, we can then look at the
			%maximum value contained in the returned 1000-event long epoch.
			intNumChans = max(ptrLib.ParseEvInfoV(0, intEventNum, sInfoCodes.CHAN));
			%Clearly the number of initial event-reads must be equal to or
			%larger than the number of channels, so if the maximum channel
			%number is equal to or larger than the number of events we
			%read, something may be amiss
			if intNumChans >= intEventNum
				warning([mfilename ':ManyChannels'],...
					sprintf(['Highest channel number (%d) is equal to or larger than the number of initial reads (%d)\n'...
					'Please double check your data tank!'],intNumChans,intEventNum)); %#ok<SPWRN>
			end
			
			%read single block
			vecSingleBlock = ptrLib.ParseEvV(0, 1);
			
			%assign data to output structure
			sMetaData.strms(intStreamType).name = strStreamName;
			sMetaData.strms(intStreamType).size = size(vecSingleBlock,1);    %number of samples in each event epoch
			sMetaData.strms(intStreamType).sampf = ptrLib.ParseEvInfoV(0, 1, sInfoCodes.HZ); %9 = sample frequency
			sMetaData.strms(intStreamType).channels = intNumChans; %4 = number of channels
			sMetaData.strms(intStreamType).bytes = ptrLib.ParseEvInfoV(0, 1, sInfoCodes.SIZE); %1 = number of samples * bytes (4??)
			sMetaData.strms(intStreamType).timerange = ptrLib.GetValidTimeRangesV(); %start and stop time in seconds of stream
		end
	end
	%assign time range
	sMetaData.vecTimeRange = sMetaData.strms(end).timerange;
	
	%% get snip events; this part is (practically) unchanged from CvdT's version
	vecLongEvCo = ptrLib.GetEventCodes(sEventCode.SNIP);
	SNIPS = size(vecLongEvCo,2);
	snips = cell(SNIPS,1);
	if ~isnan(vecLongEvCo)
		for intStreamType = 1:SNIPS
			snips{intStreamType} = ptrLib.CodeToString(vecLongEvCo(intStreamType));
		end
		for intStreamType2 = 1:length(snips)
			strSnipName = char(snips{intStreamType2});
			intEventNum = ptrLib.ReadEventsV(100000, strSnipName, 0, 0, 0, 0, 'ALL'); %read in number of events
			
			if intEventNum ~= 0
				vecSingleBlock = ptrLib.ParseEvV(0, 1);
				sMetaData.snips(intStreamType2).name = strSnipName;
				sMetaData.snips(intStreamType2).size = size(vecSingleBlock,1); %number of samples per epoch event
				sMetaData.snips(intStreamType2).sampf = ptrLib.ParseEvInfoV(0, 1, sInfoCodes.HZ); %9 = sample frequency
				
				Timestamps = ptrLib.ParseEvInfoV(0, intEventNum, sInfoCodes.TIME); %6 = the time stamp
				Channel =    ptrLib.ParseEvInfoV(0, intEventNum, sInfoCodes.CHAN);
				Chnm = max(Channel);
				sMetaData.snips(intStreamType2).channels = Chnm;
				sMetaData.snips(intStreamType2).bytes = ptrLib.ParseEvInfoV(0, 1, sInfoCodes.SIZE);
				sMetaData.snips(intStreamType2).timerange = ptrLib.GetValidTimeRangesV();
				
				while intEventNum == 100000
					intEventNum = ptrLib.ReadEventsV(100000, strSnipName, 0, 0, 0, 0, 'NEW'); %read in number of events
					Timestamps = [Timestamps ptrLib.ParseEvInfoV(0, intEventNum, sInfoCodes.TIME)];
					Channel = [Channel ptrLib.ParseEvInfoV(0, intEventNum, sInfoCodes.CHAN)];
				end
				Times = cell(Chnm,1);
				for k = 1:Chnm
					Times(k) = {Timestamps(Channel == k)};
				end
				
				sMetaData.snips(intStreamType2).times = Times;
			else
				sMetaData.snips(intStreamType2).name = strSnipName;
				sMetaData.snips(intStreamType2).size = nan; %number of samples per epoch event
				sMetaData.snips(intStreamType2).sampf = nan; %9 = sample frequency
				sMetaData.snips(intStreamType2).times = [];
				sMetaData.snips(intStreamType2).timerange = [nan nan];
			end
		end
	end
	
	%% retrieve trigger data, v2
	vecLongTrigCo = ptrLib.GetEventCodes(sEventCode.SCALAR); %gets the long codes of event types
	intTrigTypes = numel(vecLongTrigCo);
	if isnan(vecLongTrigCo),intTrigTypes=0;end
	cellTrigNames = cell(intTrigTypes,1);
	for intTrigType = 1:intTrigTypes
		%retrieve name for stream type
		cellTrigNames{intTrigType} = ptrLib.CodeToString(vecLongTrigCo(intTrigType));
	end
	
	%get trigger data
	for intTriggerType = 1:length(cellTrigNames)
		strTriggerName = char(cellTrigNames{intTriggerType});
		intEventNum = ptrLib.ReadEventsV(100000, strTriggerName, 0, 0, 0, 0, 'ALL'); %read in number of events
		vecTriggerTimes = ptrLib.ParseEvInfoV(0, intEventNum, sInfoCodes.TIME); %6 = the time stamp
		
		if isnan(vecTriggerTimes)
			vecTriggerTimes = [];
			if intVerbose
				disp([ strTriggerName ' Event has been recorded, but no events were retrieved']);
			end
		end
		
		if strcmpi(strTriggerName, 'word')
			vecTriggerValues = ptrLib.ParseEvInfoV(0, intEventNum, sInfoCodes.SCVAL); %6 = the time stamp
			vecTriggerTimes(2,:) = vecTriggerValues;
		end
		sMetaData.strons.(strTriggerName) = vecTriggerTimes;
		
	end
	
	%% retrieve trigger data, v1
	%get trigger names
	cellTriggerNames = cell(1,8);
	for intTriggerType=0:7
		strTriggerType = ptrLib.GetEpocCode(intTriggerType);
		cellTriggerNames(intTriggerType+1) = {strTriggerType};
	end
	cellTriggerNames(cellfun(@isempty,cellTriggerNames)) = [];
	
	%get trigger data
	for intTriggerType = 1:length(cellTriggerNames)
		strTriggerName = char(cellTriggerNames{intTriggerType});
		Temp = ptrLib.GetEpocsV( strTriggerName, 0, 0, 100000);
		if isnan(Temp)
			if intVerbose
				disp([ strTriggerName ' Event has been recorded, but cannot be retrieved']);
			end
		else
			vecTriggerSecs = Temp(2,:);
			
			if strcmpi(strTriggerName, 'word')
				vecTriggerSecs(2,:) = Temp(1,:);
			end
			sMetaData.strons.(strTriggerName) = vecTriggerSecs;
		end
	end
	
	%% close libraries
	ptrLib.CloseTank;
	ptrLib.ReleaseServer;
	release(ptrLib);
	%delete(ptrLib);
	close(ptrFig);
	
	%% retrieve trial-based timings
	%retrieve
	if isfield(sMetaData, 'strons')
		cellFieldNames = fieldnames(sMetaData.strons);
		for intTriggerType = 1:length(cellFieldNames)
			%get trigger
			strTrigger = cellFieldNames{intTriggerType};
			
			%check which type
			if strcmpi(strTrigger,'word')
				[matWord, Idx] = sort(sMetaData.strons.(strTrigger)(1,:).');
				matWord(:,2) = sMetaData.strons.(strTrigger)(2,Idx).';
				%assign to output
				sMetaData.Trials.word = matWord;
				
			elseif strcmpi(strTrigger,'stim') || strcmpi(strTrigger,'StOn')
				vecStimOn = sort(sMetaData.strons.(strTrigger).');
				%assign to output
				sMetaData.Trials.stim_onset = vecStimOn;
				
			elseif strcmpi(strTrigger,'StOf')
				vecStimOff = sort(sMetaData.strons.(strTrigger).');
				%assign to output
				sMetaData.Trials.stim_offset = vecStimOff;
				
			elseif strcmpi(strTrigger,'Tria')
				vecTrial = sort(sMetaData.strons.(strTrigger).');
				%assign to output
				sMetaData.Trials.trial = vecTrial;
				
			elseif strcmpi(strTrigger,'Resp')
				vecResponse = sort(sMetaData.strons.(strTrigger).');
				
				%assign to output
				sMetaData.Trials.response = vecResponse;
				
			elseif strcmpi(strTrigger,'targ')
				vecTarget = sort(sMetaData.strons.(strTrigger).');
				
				%assign to output
				sMetaData.Trials.target_onset = vecTarget;
				
			elseif strcmpi(strTrigger,'micr')
				vecMicroStim = sort(sMetaData.strons.(strTrigger).');
				
				%assign to output
				sMetaData.Trials.micro_stim_time = vecMicroStim;
				
			end
		end
	else
		%send warning
		warning([mfilename ':NoTriggers'],'No triggers found!');
	end
end

