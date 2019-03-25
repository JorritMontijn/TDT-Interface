function [vecStimOnTime,matWord] = checkTriggersTDT(vecStimOnTime,matWord,sStimLogData)
	%checkTriggersTDT Removes double trigger events based on shortest ITI
	%   Syntax:  [vecStimOnTime,matWord] = checkTriggersTDT(vecStimOnTime,matWord)
	%
	%WARNING: THIS FUNCTION IS NOT FOOL-PROOF
	%
	%If you want to make sure your trigger events make sense, you'll have
	%to check them manually. This function only ensures that the number of
	%stim on and word events match, and removes the most likely culprit
	%(i.e., the event that follows with least delay after the previous event)
	%
	%Version History:
	%2019-02-08 Created trigger-fixer function. Use with caution.
	%				[by Jorrit Montijn]
	
	if vecStimOnTime > size(matWord,1)
		%check for double stim on
		vecStimDiff = diff(vecStimOnTime);
		%assume shortest ITI was incorrect
		[dummy,intRemIdx]=min(vecStimDiff);
		%remove double trigger
		vecStimOnTime(intRemIdx+1) = [];
		%send msg
		warning([mfilename ':DoubleStimOn'],'More stim on than word events detected!');
	elseif vecStimOnTime > size(matWord,1)
		%check for double word
		vecWordDiff=diff(matWord(:,1));
		%assume shortest ITI was incorrect
		[dummy,intRemIdx]=min(vecWordDiff);
		%remove double trigger
		matWord(intRemIdx+1,:) = [];
		%send msg
		warning([mfilename ':DoubleWord'],'More word than stim on events detected!');
	else
		%we don't have to do anything
	end
end

