%% This is the syntax you normally use for getting the ephys data into matlab.
clear all

%% get Raw data from tank
%Define which data to use
sMetaData.Mytank = 'D:\Data\Raw\ePhys\DataTanksTDT\Roku_20180514';
sMetaData.Myblock = 'Block-2';

%% open library
sMetaData = getMetaDataTDT(sMetaData);

%% Get data from Tank into MATLAB
[vecTimestamps,matData] = getRawDataTDT(sMetaData);

%24.414 kHz