function [dsImage, dsLabel] = loadSegmentationArchive(varargin)
	% LOADSEGMENTATIONARCHIVE
	%
	% ==============================================
	% INPUTS (Local Search) (Required, can be empty)
	% ==============================================
	% databaseLocation (1,N) string
	%		Absolute or relative path to a desired Segmentation Archive (includes
	%		image and label sub-folders) or a NEXRAD Level 2 Archive Folder
	%		A recursive check will grab every file below irrespective of content
	%		(duplicates will be filtered). When this is empty, allows the manual
	%		selection of a folder.
	%
	% For a NEXRAD query, files hosted by at the NOAA National Climate Data
	% Center [1]_ as well as on the UCAR THREDDS Data Server [2]_ have been
	% tested. Other NEXRAD Level 2 Archive files may or may not work. Message
	% type 1 file and message type 31 files are supported.
	%
	% ============================================
	% INPUTS (Cloud Search, replaces Local Search)
	% ============================================
	% The following inputs operate the cloud search executed by nexrad.io.readCloud.
	% The inputs should be entered as normal to the call, replacing the above
	% databaseLocation variable.
	%
	% =================================
	% INPUTS  (Cloud Search) (Required)
	% =================================
	% radarID (1,N) nexrad.utility.radarID or convertible
	%		Four letter ICAO name of the NEXRAD station from which the scans are
	%		desired. For a mapping of ICAO to station name, see
	%		https://www.roc.noaa.gov/branches/program-branch/site-id-database/site-id-network-sites.php.
	%
	% startTime (1,N) datetime
	%		Start of the time range between which scans are desired. If not
	%		specified, timezone is assumed UTC.
	%
	% endTime (1,N) datetime
	%		End of the time range between which scans are desired. If not
	%		specified, timezone is assumed UTC.
	%
	% ==================================
	% INPUTS (Cloud Search) (Name-Value)
	% ==================================
	% saveLocation (1,1) string
	%		Local folder to save downloaded scans to. Also provides the location
	%		to check whether any scans are already downloaded.
	%		(tempdir/nexrad-database, default).
	%
	% awsStructure (1,1) logical
	%		Maintain AWS bucket folder structure (true, default). Download all
	%		files into same folder (false).
	%
	% nThreads (1,1) double
	%		The number of processor threads used to concurrently download
	%		files. This is the number of physical cores of a system rather than
	%		virtual threads.
	%
	% ==================================
	% INPUTS (Segmentation) (Name-Value)
	% ==================================
	% fieldname (1,1) string
	%		Name of the field from which the point cloud data should be
	%		retrieved.
	%
	% sweep (1,M) double
	%		Sweep number(s) to retrieve data for.
	%
	% resolution (1,1) double
	%		Step size of the box grid filter to apply during point cloud
	%		downsampling.
	%
	% amountOfJitter (1,1) double
	%		The amount of per-point jitter to apply to the raw point cloud data.
	%
	% imageSize (1,2) double
	%		Dimensions of the encoded images and labels (forms a sub-folder
	%		below databaseLocation).
	%
	% =======
	% OUTPUTS
	% =======
	% dsImage (1,1) matlab.io.datastore.ImageDatastore
	%		Datastore containing each of the RGB encoded NEXRAD Level II image
	%		files.
	%
	% dsLabel (1,1) matlab.io.datastore.PixelLabelDatastore
	%		Datastore containing each of the pixel labelled NEXRAD Level II image
	%		files.
	
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