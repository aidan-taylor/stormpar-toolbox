function [dsImage, dsLabel] = loadSegmentationArchive(varargin)
	% LOADSEGMENTATIONARCHIVE
	%

	% Validate inputs (extract current segmentation database or encode NEXRAD data)
	[databaseLocation, imageSize] = stormpar.deeplearning.io.resources.prepareSegmentationArchive(varargin{:});
	
	% Pull imageSize into a string to get the dedicated folder for it.
	sizeString = sprintf("%ix%i", imageSize(1,1), imageSize(1,2));
	
	% Initialise ImageDatastore
	imageLocation = fullfile(databaseLocation, "Images", sizeString);
	dsImage  = imageDatastore(imageLocation, "FileExtensions", ".png");
	
	% Initialise pixelLabelDatastore
	labelLocation = fullfile(databaseLocation, "Labels", sizeString);
	[pixelLabelIDs, classNames] = enumeration("stormpar.deeplearning.utility.reflectivityScale");
	dsLabel = pixelLabelDatastore(labelLocation, classNames, pixelLabelIDs, "FileExtensions", ".png");