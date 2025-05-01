function [dsImage, dsLabel] = loadSegmentationArchive(filename, nameValueArgs)
	% LOADSEGMENTATIONARCHIVE
	%
	
	arguments
		filename (1,:) string = [];
		nameValueArgs.imageSize (1,2) double = [224, 224];
	end
	
	if isempty(filename)
		% Promp user to choose a folder(s) and/or file(s) (must be in same folder)
		[file, location] = stormpar.deeplearning.utility.uiget(pwd, 'Title', 'Choose a NEXRAD Image Archive', 'MultiSelect', true);
		
		% If location returns an "empty" string array ("" shows as 1x1 array) assume ui was cancelled and error
		if isempty(location{:}), error('STORMPAR:IO:InvalidID', 'No local folder or file selected'); end
		
		% Form full path to chosen files
		filename = string(fullfile(location, file));
	end
	
	% Pull the imageSize into a string to make a dedicated folder for it.
	sizeString = sprintf("%ix%i", nameValueArgs.imageSize(1,1), nameValueArgs.imageSize(1,2));
	
	% Initialise ImageDatastore
	imageLocation = fullfile(filename, 'Images', sizeString);
	dsImage  = imageDatastore(imageLocation, "IncludeSubfolders", true, "FileExtensions", '.png');
	
	% Initialise pixelLabelDatastore
	labelLocation = fullfile(filename, 'Labels', sizeString);
	[pixelLabelIDs, classNames] = enumeration('stormpar.deeplearning.utility.reflectivityScale');
	dsLabel = pixelLabelDatastore(labelLocation, classNames, pixelLabelIDs, 'IncludeSubfolders', true, 'FileExtensions', '.png');
end