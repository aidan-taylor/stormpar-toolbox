function encodeWeatherData(ds, saveLocation, nameValueArgs)
	% ENCODEWEATHERDATA Generate semantic segmentation data (RGB image and
	% labels) from NEXRAD Level II binary archives.
	% 
	% TODO -- Save in single HDF5 file rather than lots of separate PNGs?
	% =================
	% INPUTS (Required)
	% =================
	% ds (1,1) matlab.io.datastore.FileDatastore
	%		Datastore containing NEXRAD Level II binary files.
	%
	% =================
	% INPUTS (Optional)
	% =================
	% saveLocation (1,1) string
	%		Local folder to save encoded NEXRAD Level II data to.
	%
	% ===================
	% INPUTS (Name-Value)
	% ===================
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
	% ==========
	% References
	% ==========
	% ..[1] https://www.noaa.gov/jetstream/reflectivity
	
	arguments
		ds (1,1) matlab.io.datastore.FileDatastore
		saveLocation (1,1) string = fullfile(tempdir, "stormpar-database");
	end
	
	arguments
		nameValueArgs.fieldname (1,1) string = 'reflectivity';
		nameValueArgs.sweep (1,:) double = 1;
		nameValueArgs.resolution (1,1) double = 1500;
		nameValueArgs.amountOfJitter (1,1) double = 0.01;
		nameValueArgs.imageSize (1,2) double = [360, 360];
	end
	
	% Pull out augmentation variables to reduce overhead
	fieldname = nameValueArgs.fieldname;
	sweep = nameValueArgs.sweep;
	resolution = nameValueArgs.resolution;
	amountOfJitter = nameValueArgs.amountOfJitter;
	
	% Downsample and augment point cloud with jitter
	ds = transform(ds, @augmentPointCloudData);
	
	% Pull out encoding variables to reduce overhead
	imageSize = nameValueArgs.imageSize;
	
	% Apply encoding to RGB data
	ds = transform(ds, @encodePointCloudData);
	
	% Format the imageSize into a string to make a dedicated sub-folder for it.
	sizeString = sprintf("%ix%i", nameValueArgs.imageSize(1,1), nameValueArgs.imageSize(1,2));
	
	% Create image and label folders
	imageFolder  =  fullfile(saveLocation, 'Images', sizeString);
	if ~isfolder(imageFolder), mkdir(imageFolder); end
	
	labelFolder = fullfile(saveLocation, 'Labels', sizeString);
	if ~isfolder(labelFolder), mkdir(labelFolder); end
	
	% Get the number of partitions needed for the pool (starts a default parallel pool on Processes)
	nPartitions = numpartitions(ds, gcp);
	
	parfor iPartition = 1:nPartitions
		
		% Get partition of datastore and number of files in it
		subds = partition(ds, nPartitions, iPartition);
		nFiles = numpartitions(subds);
		
		% Loop through data and save to disk
		for iFile = 1:nFiles
			
			% Check if data can actually be read (safety if loop goes too many times)
			if ~hasdata(subds)
				warning('STORMPAR:CORE:InvalidCode', ...
					'Index %i exceeds the number of readable files in the datastore', iFile);
				break
			end
			
			% Form path to possible png file
			[~, name] = fileparts(subds.UnderlyingDatastores{1}.Files{iFile});
			pngPath = fullfile(imageFolder, [name, '.png']);
			
			% Check if png doesn't exist (assumes label also doesn't exists)
			if isfile(pngPath), continue, end
			
			% Get data (indexes sequentially through datastore)
			imgData = read(subds);
			
			% Write RGB image to disk (doesn't overwrite existing file)
			imwrite(imgData{1}, pngPath);
			
			% Write label to disk (overwrites existing file)
			labelPath = fullfile(labelFolder, [name, '.png']);
			imwrite(imgData{2}, labelPath);
		end
	end
	
	%% Custom point cloud augmentation function
	function ptCloud = augmentPointCloudData(radar)
		
		% Extract point cloud data
		ptCloud = radar.pointCloud(fieldname, sweep);
		
		% Downsample
		ptCloud = pcdownsample(ptCloud, 'gridAverage', resolution);
		
		% Initialise
		numPoints = size(ptCloud.Location, 1);
		D = zeros(size(ptCloud.Location), 'like', ptCloud.Location);
		
		% Form array
		D(:,1) = diff(ptCloud.XLimits) * rand(numPoints,1);
		D(:,2) = diff(ptCloud.YLimits) * rand(numPoints,1);
		D(:,3) = diff(ptCloud.ZLimits) * rand(numPoints,1);
		
		% Apply jitter to each point in point cloud
		D = amountOfJitter .* D;
		ptCloud = pctransform(ptCloud, D);
	end
	
	%% Custom point cloud encoding function
	function dataOut = encodePointCloudData(ptCloud)
		
		% Intialise min/max radar sensitivity (from Level 2 Specifications)
		minSens = -32.0;
		maxSens = 92.5;
		offset = abs(minSens);
		
		% Form mesh to interpolate over
		xg = linspace(ptCloud.XLimits(1), ptCloud.XLimits(2), imageSize(1));
		yg = linspace(ptCloud.YLimits(1), ptCloud.YLimits(2), imageSize(2));
		[Xg, Yg] = meshgrid(xg, yg);
		
		% Shift negative intensity values to positive (dbZ values can be
		% negative but rgb cannot) This would be an issue if we were trying to
		% accurately predict reflectivity values as they would show as larger
		% than actual. (shifts by a constant 32.0 as this is the minimum sensitivity of WSR-88D)
		% Ensures that the very minimum values are shifted to 1 to allow 0 to be
		% the missing values background colour
		intensity = ptCloud.Intensity + offset + 1;
		
		% Perform surface interpolation and convert to uint8 (wraps NaN values to 0 and rounds floats)
		indexImage = griddata(double(ptCloud.Location(:,1)), double(ptCloud.Location(:,2)), ...
			double(intensity), double(Xg), double(Yg));
		indexImage = uint8(indexImage);
		
		% Get colourmap indices for the number of unique colours (nan values
		% are missing reflectivity values and will have been wrapped to 0, so mark
		% as black) (steps of 1 so get the range between the min and max sensitivities)
		nC = ceil(range([minSens, maxSens]));
		map = cat(1, [0, 0, 0], parula(nC));
		
		% Convert to RGB
		RGBimage = ind2rgb(indexImage, map);
		
		% Form image segmentation label -- TODO Optimise performance
		labelImage = zeros(size(indexImage), 'like', indexImage);
		
		for iRow = 1:size(indexImage, 1)
			for iColumn = 1:size(indexImage, 2)
				
				% Get the intensity of the reflectivity for this pixel
				pixelIntensity = indexImage(iRow, iColumn);
				
				% Assign the correct label to each intensity value based on
				% the NOAA General Reflectivity Guidelines [1]
				if (pixelIntensity <= (-32 + offset))
					labelImage(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.NoData;
					
				elseif (pixelIntensity > (-32 + offset)) && (pixelIntensity <= (0 + offset))
					labelImage(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.ExLight;
					
				elseif (pixelIntensity > (0 + offset)) && (pixelIntensity <= (20 + offset))
					labelImage(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.VeryLight;
					
				elseif (pixelIntensity > (20 + offset)) && (pixelIntensity <= (40 + offset))
					labelImage(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.Light;
					
				elseif (pixelIntensity > (40 + offset)) && (pixelIntensity <= (50 + offset))
					labelImage(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.Moderate;
					
				elseif (pixelIntensity > (50 + offset)) && (pixelIntensity <= (65 + offset))
					labelImage(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.Heavy;
					
				elseif (pixelIntensity > (65 + offset))
					labelImage(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.ExHeavy;
				end
			end
		end
		
		% Output RGB and label data
		dataOut = {RGBimage, labelImage};
	end
end