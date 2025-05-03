function encodeWeatherData(databaseLocation, nameValueArgs)
	% ENCODEWEATHERDATA Convert binary radar data to PNG (lowest elevation sweep)
	% TODO -- Change so saves in a single HDF5 file rather than lots of PNGs>
	
	arguments
		% H5Filename (1,1) string = fullfile(tempdir, 'NEXRAD-Imagestore');
		databaseLocation (1,:) string = [];
	end
	
	% arguments (Repeating)
	% 	varargin
	% end
	
	arguments
		nameValueArgs.amountOfJitter (1,1) double = 0.01;
		nameValueArgs.imageSize (1,2) double = [240, 240];
	end
	
	% Start Parallel Pool on Processes (done by gcp to avoid clashes)
	% p = parpool('Processes');
	
	% Load the specified data (assumes within 'Data' subfolder)
	dataSubfolder = fullfile(databaseLocation, 'Data');
	ds = stormpar.deeplearning.io.loadLevel2Archive(dataSubfolder);
	
	% Apply random jitter to each point
	ds = augmentLevel2Data(ds, nameValueArgs.amountOfJitter);
	
	% Apply encoding to RGB data
	ds = encodeLevel2Data(ds, nameValueArgs.imageSize);
	
	% Create a HDF5 file (if exists, does not overwrite)
	% H5fileID = H5F.create(H5Filename, "H5F_ACC_EXCL", "H5P_DEFAULT", "H5P_DEFAULT");
	
	% Open the specified file if it is the correct format
	% if H5F.is_hdf5(H5Filename)
	% H5fileID = H5F.open(H5Filename, "H5F_ACC_RDWR", "H5P_DEFAULT");
	% end
	
	% Pull the imageSize into a string to make a dedicated folder for it.
	sizeString = sprintf("%ix%i", nameValueArgs.imageSize(1,1), nameValueArgs.imageSize(1,2));
	
	% Form and create image and label folders
	imageFolder  =  fullfile(databaseLocation, 'Images', sizeString);
	if ~isfolder(imageFolder), mkdir(imageFolder); end
	
	labelFolder = fullfile(databaseLocation, 'Labels', sizeString);
	if ~isfolder(labelFolder), mkdir(labelFolder); end
	
	% Get the number of partitions needed for the pool (starts a default parallel pool on Processes)
	nPartitions = numpartitions(ds, gcp);
	
	parfor iPartition = 1:nPartitions
		
		% Get partition of datastore and number of files in it
		subds = partition(ds, nPartitions, iPartition);
		nFiles = length(subds.UnderlyingDatastores{1}.Files);
		
		% Loop through data and save to disk
		for iFiles = 1:nFiles
			
			% Check if data can actually be read (safety if loop goes too many times)
			if ~hasdata(subds)
				warning('STORMPAR:CORE:InvalidID', ...
					'Index %i exceeds the number of readable files in the datastore', iFiles);
				break
			end
			
			% Form path to possible png file (jump up a level to
			% get out the data folder) 
			[~, name] = fileparts(subds.UnderlyingDatastores{1}.Files{iFiles});
			pngPath = fullfile(imageFolder, [name, '.png']);
			
			% Check if png already exists, skip if so (assumes label also exists)
			if isfile(pngPath), continue, end
			
			% Get data (indexes sequentially through datastore)
			imgData = read(subds);
			
			% Write image to disk (doesn't overwrite existing file)
			RGBim = imgData{1};
			imwrite(RGBim, pngPath);
			
			% Write label to disk (overwrites existing file) (jump up a level to
			% get out the data folder) 
			label = imgData{2};
			
			labelPath = fullfile(labelFolder, [name, '.png']);
			imwrite(label, labelPath);
			
			% Parse folder structure for HDF5
			% radarID = fileName(1:4);
			% timeData = datetime(fileName(5:end), 'InputFormat', 'yyyyMMdd_HHmmss');
			
			% Get the dataset name the data would go into
			% datasetName = fullfile(timeData.Year, timeData.Month, timeData.Day, radarID, fileName);
		end
	end
	
	% Close HDF5 file
	% H5F.close(H5fileID);
end


%%
function dsAugmented = augmentLevel2Data(ds, amountOfJitter)
	%AUGMENTLEVEL2DATA Summary of this function goes here
	%   Detailed explanation goes here
	
	arguments
		ds (1,1) {isa(ds, 'matlab.io.datastore.FileDatastore'), isa(ds, 'matlab.io.datastore.TransformedDatastore')}
		amountOfJitter (1,1) double = 0.01;
	end
	
	% Augment data using custom function
	dsAugmented = transform(ds, @augmentPointCloud);
	
	%% Custom augmentation function
	function dataOut = augmentPointCloud(data)
		
		ptCloud = data{1};
		
		% Apply randomized rotation about Z axis.
		% tform = randomAffine3d('Rotation',@() deal([0 0 1],360*rand), ...
		% 	'Scale',[0.98,1.02],'XReflection',true,'YReflection',true);
		% ptCloud = pctransform(ptCloud,tform);
		
		% Apply jitter to each point in point cloud
		numPoints = size(ptCloud.Location,1);
		D = zeros(size(ptCloud.Location),'like',ptCloud.Location);
		D(:,1) = diff(ptCloud.XLimits)*rand(numPoints,1);
		D(:,2) = diff(ptCloud.YLimits)*rand(numPoints,1);
		D(:,3) = diff(ptCloud.ZLimits)*rand(numPoints,1);
		D = amountOfJitter.*D;
		ptCloud = pctransform(ptCloud,D);
		
		% Output noisy point cloud and label
		label = data{2};
		dataOut = {ptCloud, label};
	end
end


%%
function dsEncoded = encodeLevel2Data(ds, imageSize)
	%ENCODELEVEL2DATA Summary of this function goes here
	%   Detailed explanation goes here
	
	arguments
		ds (1,1) {isa(ds, 'matlab.io.datastore.FileDatastore'), isa(ds, 'matlab.io.datastore.TransformedDatastore')}
		imageSize (1,2) double = [240, 240];
	end
	
	% Encode data using custom function
	dsEncoded = transform(ds, @formIndexedImage);
	
	%% Custom voxel encoding function
	% function dataOut = formOccupancyGrid(data)
	%
	% 	grid = pcbin(data{1},[720 720, 24]);
	% 	occupancyGrid = cellfun(@(c) ~isempty(c),grid);
	% 	label = data{2};
	% 	dataOut = {occupancyGrid,label};
	% end
	
	%% Custom image encoding function
	function dataOut = formIndexedImage(data)
		
		% Intialise min/max radar sensitivity (from Level 2 Specifications)
		minSens = -32.0;
		maxSens = 92.5;
		
		pc = data{1};
		
		% Form mesh to interpolate over
		xg = linspace(pc.XLimits(1), pc.XLimits(2), imageSize(1));
		yg = linspace(pc.YLimits(1), pc.YLimits(2), imageSize(2));
		[Xg, Yg] = meshgrid(xg, yg);
		
		% Shift negative intensity values to positive (dbZ values can be
		% negative but rgb cannot) This would be an issue if we were trying to
		% accurately predict reflectivity values as they would show as larger
		% than actual. (shifts by a constant 32.0 as this is the minimum sensitivity of WSR-88D)
		% Ensures that the very minimum values are shifted to 1 to allow 0 to be
		% the missing values background colour
		intensity = pc.Intensity + abs(minSens) + 1;
		
		% Perform surface interpolation and convert to uint8 (wraps NaN values to 0 and rounds floats)
		indexImage = griddata(double(pc.Location(:,1)), double(pc.Location(:,2)), double(intensity), double(Xg), double(Yg));
		indexImage = uint8(indexImage);
		
		% Form image segmentation label -- TODO Optimise performance
		label = generateSegmentationLabel(indexImage, abs(minSens));
		
		% Get colourmap indices for the number of unique colours (nan values
		% are missing reflectivity values and will have been wrapped to 0, so mark
		% as black) (steps of 1 so get the range between the min and max sensitivities)
		nC = ceil(range([minSens, maxSens]));
		map = cat(1, [0, 0, 0], parula(nC));
		
		% Convert to RGB and output
		RGBimage = ind2rgb(indexImage, map);
		dataOut = {RGBimage, label};
		
		%% Custom Nested Image Segementation Label Generator
		function label = generateSegmentationLabel(indexImage, offset)
			%
			% References
			% [1] https://www.noaa.gov/jetstream/reflectivity
			
			% Intialise label form
			label = zeros(size(indexImage), 'like', indexImage);
			
			for iRow = 1:size(indexImage, 1)
				for iColumn = 1:size(indexImage, 2)
					
					% Get the intensity of the reflectivity for this pixel
					pixelIntensity = indexImage(iRow, iColumn);
					
					% Assign the correct label to each intensity value based on
					% the NOAA General Reflectivity Guidelines [1]
					if (pixelIntensity <= (-32 + offset))
						label(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.NoData;
						
					elseif (pixelIntensity > (-32 + offset)) && (pixelIntensity <= (0 + offset))
						label(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.ExLight;
						
					elseif (pixelIntensity > (0 + offset)) && (pixelIntensity <= (20 + offset))
						label(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.VeryLight;
						
					elseif (pixelIntensity > (20 + offset)) && (pixelIntensity <= (40 + offset))
						label(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.Light;
						
					elseif (pixelIntensity > (40 + offset)) && (pixelIntensity <= (50 + offset))
						label(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.Moderate;
						
					elseif (pixelIntensity > (50 + offset)) && (pixelIntensity <= (65 + offset))
						label(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.Heavy;
						
					elseif (pixelIntensity > (65 + offset))
						label(iRow, iColumn) = stormpar.deeplearning.utility.reflectivityScale.ExHeavy;
					end
				end
			end
		end
	end
end