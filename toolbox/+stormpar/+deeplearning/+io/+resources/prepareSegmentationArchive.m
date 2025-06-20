function [databaseLocation, imageSize] = prepareSegmentationArchive(databaseLocation, varargin)
	%PREPARESEGMENTATIONARCHIVE Performs input checks for stormpar.deeplearning.io functions.
	% This is an internal validation function. databaseLocation is separated
	% from varargin to enforce convertibility to a row-major string array and for
	% convenience when invoking cloud-based search.
	
	arguments
		databaseLocation (1,:) string = [];
	end
	
	arguments (Repeating)
		varargin
	end
	
	% Parse optional arguments
	[nexradOpts, segOpts] = parseOptionalArgs(varargin{:});
	
	% Extract imageSize parameter for output
	imageSize = extractEncodedImageSize(segOpts{:});
	
	% If nexradOpts is not empty, assume cloud search is desired
	if ~isempty(nexradOpts)
		% Check that empty array was not deliberately passed as first input
		if isempty(databaseLocation), error("STORMPAR:IO:InvalidInput", "No radar ICAO ID given"); end
		
		% Perform nexrad-toolbox cloud search
		dsNexrad = nexrad.io.loadArchive(databaseLocation, nexradOpts{:});
		
		% databaseLocation is actually a list of radar ICAO IDs, so need to
		% overwrite with the saveLocation
		databaseLocation = extractCloudSaveLocation(nexradOpts{:});
		
		% Encode the archive data into RGB and label images for sematic
		% segmentation
		stormpar.deeplearning.core.encodeWeatherData(dsNexrad, databaseLocation, segOpts{:});
		
		% databaseLocation is now a guarantied segmentation archive
		return
	end
	
	if isempty(databaseLocation)
		% Promp user to choose a folder(s) and/or file(s) (must be in same
		% folder)
		databaseLocation = stormpar.utility.uiget("Title", "Choose a Segmentation or a NEXRAD Level II Data Archive Folder", ...
			"SelectionMode", "folders");
		
		% If uiget returns 0, assume ui was cancelled and error
		if isnumeric(databaseLocation), error("STORMPAR:IO:InvalidCode", "No local folder selected"); end
	end
	
	% Now we only have local archives which have been given (could still be
	% either NEXRAD Level II data or pre-converted segmentation images)
	
	% Pull imageSize into a string to get the dedicated folder for it.
	sizeString = sprintf("%ix%i", imageSize(1,1), imageSize(1,2));
	
	% Form path to segmentation archive required sub-folders
	imageLocation = fullfile(databaseLocation, "Images", sizeString);
	labelLocation = fullfile(databaseLocation, "Labels", sizeString);
	
	% Check if the folder(s) given contain the two folders needed to be a
	% segmentation archive
	validSegArchive = all([isfolder(imageLocation); isfolder(labelLocation)], 1);
	
	% Make new list for invalid folders and remove entries from databaseLocation
	dbLocationNexrad = databaseLocation(~validSegArchive);
	databaseLocation(~validSegArchive) = [];
	
	if ~isempty(dbLocationNexrad)
		% If there are invalid segmentation archives, assume they are nexrad
		% archives and perform checks through nexrad-toolbox.
		dsNexrad = nexrad.io.loadArchive(dbLocationNexrad);
		
		if ~isscalar(dbLocationNexrad)
			% If multiple nexrad archive are given
			if isscalar(databaseLocation)
				% Check if there is a single valid segmentation archive
				saveLocation = databaseLocation;
				
			else
				% Otherwise use the default path
				saveLocation = fullfile(tempdir, "stormpar-database");
			end
			
		else
			% If only one is given, pass through
			saveLocation = dbLocationNexrad;
		end
		
		% Encode the archive data into RGB and label images for sematic
		% segmentation
		stormpar.deeplearning.core.encodeWeatherData(dsNexrad, saveLocation, segOpts{:});
		
		% Append the new converted saveLocation to the list of valid
		% segmentation archives
		databaseLocation = [databaseLocation, saveLocation];
	end
	
	% Make a final unique check
	databaseLocation = unique(databaseLocation);
	
	% If no folders are left then error
	if isempty(databaseLocation)
		error("STORMPAR:IO:InvalidFolder", "None of the chosen folders are valid");
	end
	
	%%
function [nexradOpts, segOpts] = parseOptionalArgs(startTime, endTime, cloudOpts, segOpts)
	%PARSEOPTIONALARGS Separate nexrad-toolbox cloud search parameters from
	% the segmentation variables.
	
	arguments
		startTime (1,:) datetime = NaT;
		endTime (1,:) datetime = NaT;
		cloudOpts.saveLocation (1,1) string = fullfile(tempdir, "stormpar-database");
		cloudOpts.awsStructure (1,1) logical = true;
		cloudOpts.nThreads (1,1) double = 6;
	end
	
	arguments
		segOpts.fieldname (1,1) string = 'reflectivity';
		segOpts.sweep (1,:) double = 1;
		segOpts.resolution (1,1) double = 1500;
		segOpts.amountOfJitter (1,1) double = 0.01;
		segOpts.imageSize (1,2) double = [360, 360];
	end
	
	if isnat(startTime) || isnat(endTime)
		% If either start or end times have not been given the cloud search will
		% not work, so assume it is not desired.
		nexradOpts = cell.empty(1,0);
		
	else
		% Otherwise combine with name-value pairs and output as cell
		nexradOpts = [{startTime, endTime}, namedargs2cell(cloudOpts)];
	end
	
	% Convert segmentation variables to cell
	segOpts = namedargs2cell(segOpts);
	
	%%
function imageSize = extractEncodedImageSize(segOpts)
	%EXTRACTENCODEDIMAGESIZE Extract the imageSize parameter from the
	%initialised segOpts cell
	
	arguments
		segOpts.fieldname (1,1) string = 'reflectivity';
		segOpts.sweep (1,:) double = 1;
		segOpts.resolution (1,1) double = 1500;
		segOpts.amountOfJitter (1,1) double = 0.01;
		segOpts.imageSize (1,2) double = [360, 360];
	end
	
	% Assign to outputs
	imageSize = segOpts.imageSize;
	
	%%
function saveLocation = extractCloudSaveLocation(~, ~, cloudOpts)
	%EXTRACTCLOUDSAVELOCATION Extract the saveLocation parameter from the
	% initialised nexradOpts cell. startTime / endTime are always first and are
	% not needed so are ignored.
	
	arguments
		~
		~
		cloudOpts.saveLocation (1,1) string = fullfile(tempdir, "stormpar-database");
		cloudOpts.awsStructure (1,1) logical = true;
		cloudOpts.nThreads (1,1) double = 6;
	end
	
	% Assign to outputs
	saveLocation = cloudOpts.saveLocation;