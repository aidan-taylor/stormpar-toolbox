function ds = loadLevel2Archive(filename, varargin, nameValueArgs)
%LOADLEVEL2ARCHIVE Load NEXRAD Level 2 data file(s) and return datastore object.
% Takes either binary file (internal conversion) or matfile with each field
% representing the radar data. Returns datastore of each file with
% nexrad.io.extractArchive as the custom read function. The output of the data
% store is the nexrad.core.Radar object(s) with radar
% data as fields.
%
% ==============================================
% INPUTS (Local Search) (Required, can be empty)
% ==============================================
%
% filename (1,N) string
%		Absolute or relative path to desired NEXRAD Level 2
%		Archive File. Can include file(s) or folder(s). When a folder is given,
%		a recursive check will grab every file below irrespective of content
%		(duplicates will be filtered). When this is empty (must still be
%		passed), allows either manual selection of file(s) or folder(s) or cloud
%		based search. 
%
% The files hosted by at the NOAA National Climate Data Center [1]_ as well as
% on the UCAR THREDDS Data Server [2]_ have been tested. Other NEXRAD Level 2
% Archive files may or may not work. Message type 1 file and message type 31
% files are supported.
%
% =================================
% INPUTS  (Cloud Search) (Required)
% =================================
%
% radarID (1,1) string
%		Four letter ICAO name of the NEXRAD station from which the scans are
%		desired. For a mapping of ICAO to station name, see
%		https://www.roc.noaa.gov/branches/program-branch/site-id-database/site-id-network-sites.php. 
%
% startTime (1,1) datetime
%		Start of the time range between which scans are desired. 
%
% endTime (1,1) datetime
%		End of the time range between which scans are desired. 
%
% ================================
% INPUTS (Cloud Search) (Optional)
% ================================
%
% saveLocation (1,1) string
%		Local folder to save downloaded scans to. Also provides the location to
%		check whether any scans are already downloaded.
%
% ==================================
% INPUTS (Cloud Search) (Name-Value) 
% ==================================
%
% awsStructure (1,1) logical
%		Maintain AWS bucket folder structure (true, default). Download all
%		files into same folder (false).
%
% =============================================
% INPUTS (Datastore read function) (Name-Value)
% =============================================
%
% fieldname (1,1) string
%		The name of the desired field to extract the point cloud data of.
%
% sweep (1,:) double
%		The index of the sweep(s) to extract the point cloud data of.
%
% =======
% OUTPUTS
% =======
%
% radar (1,N) nexrad.core.Radar
%		Radar object containing all moments and sweeps/cuts in the volume.
%
% ==========
% References
% ==========
% .. [1] http://www.ncdc.noaa.gov/
% .. [2] http://thredds.ucar.edu/thredds/catalog.html

arguments
	filename (1,:) string = [];
end

arguments (Repeating)
	varargin
end

arguments
	nameValueArgs.fieldname (1,1) string = 'reflectivity';
	nameValueArgs.sweep (1,:) double = 1;
	nameValueArgs.resolution (1,1) double = 1500;
end

% Validate inputs (assume any varargin inputs relate to cloud settings)
filename = nexrad.io.prepareForRead(filename, varargin{:});

% Initialise file data storage object with custom read function
ds = fileDatastore(filename, 'ReadFcn', extractLevel2Data(nameValueArgs.fieldname, ...
	nameValueArgs.sweep, nameValueArgs.resolution));
end


%%
function fcnHandle = extractLevel2Data(fieldName, sweep, resolution)
	% EXTRACTLEVEL2DATA
	%
	
	arguments
		fieldName (1,1) string = "reflectivity";
		sweep (1,:) double = 1;
		resolution (1,1) double = 1500;
	end
	
	% Return function handle to perform NEXRAD Level II data extraction
	fcnHandle = @extractData;
	
	% Custom fileDatastore read function
	function dataOut = extractData(filename)
		
		% Read the given file and return radar object
		radar = nexrad.io.readArchive(filename);
		
		% Extract point cloud data
		ptCloud = radar.pointCloud(fieldName, sweep);
		
		% Downsample
		ptCloud = pcdownsample(ptCloud, 'gridAverage', resolution);
		
		% Get the path to the label (should be in same folder with extension .txt)
		% [location, name] = fileparts(filename);
		% labelFile = fullfile(location, [name, '.txt']);
		
		% Read the label file
		% label = fileread(labelFile);
		% label = categorical(string(label));
		
		% TODO For now, just generate a txt file which would store a label (this
		% will need to be manually done afterwards);
		label = "Placeholder";
		
		% Output the point cloud and label in cell for neural network training format
		dataOut = {ptCloud, label};
	end
end