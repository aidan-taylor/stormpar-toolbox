function [dsTrain, dsVal, dsTest] = partitionSegmentationData(dsImage, dsLabel, nameValueArgs)
	% PARTITIONSEGMENTATIONLABEL Split the datastore into training, validation,
	% and testing sets and apply randomised augmentation to training data to
	% prevent over-fitting. 
	%
	% =================
	% INPUTS (Required)
	% =================
	% dsImage (1,1) matlab.io.datastore.ImageDatastore
	%		Datastore containing each of the RGB encoded NEXRAD Level II image
	%		files. Must contain the same number of files as dsLabel.
	%
	% dsLabel (1,1) matlab.io.datastore.PixelLabelDatastore
	%		Datastore containing each of the pixel labelled NEXRAD Level II image
	%		files. Must contain the same number of files as dsImage.
	%
	% ===================
	% INPUTS (Name-Value)
	% ===================
	% rngSeed (1,1) double
	%		Random number seed for generator. Used when shuffling the order of
	%		images in each datastore
	%
	% rngGenerator (1,1) string
	%		Random number algorithm for generator. Used when shuffling the order of
	%		images in each datastore
	%
	% partitionRatios (1,2) double
	%		The ratio of training images to validation images (this should not
	%		sum to unity as the remaining files will be used for testing).
	%
	% xTranslation (1,2) double
	%		Lower and Upper bounds for a randomised translation augmentation
	%		in the x-axis.
	%
	% yTranslation (1,2) double
	%		Lower and Upper bounds for a randomised translation augmentation
	%		in the y-axis.
	%
	% =======
	% OUTPUTS
	% =======
	% dsTrain (1,1) matlab.io.datastore.TransformedDatastore
	%		Datastore containing the augmented combination of encoded NEXRAD
	%		Level II images for training.
	%
	% dsVal (1,1) matlab.io.datastore.CombinedDatastore
	%		Datastore containing the combination of encoded NEXRAD Level II
	%		images for validation.
	%
	% dsTest (1,1) matlab.io.datastore.CombinedDatastore
	%		Datastore containing the combination of encoded NEXRAD Level II
	%		images for testing.
	
	arguments
		dsImage (1,1) matlab.io.datastore.ImageDatastore
		dsLabel (1,1) matlab.io.datastore.PixelLabelDatastore
	end
	
	arguments
		nameValueArgs.rngSeed (1,1) double = 0;
		nameValueArgs.rngGenerator (1,1) string = "twister";
		nameValueArgs.partitionRatios (1,2) double = [0.60, 0.20];
		nameValueArgs.xTranslation (1,2) double = [-10, 10];
		nameValueArgs.yTranslation (1,2) double = [-10, 10];
	end
	
	% Ensure both datastores contain the same number of files
	if numpartitions(dsImage) ~= numpartitions(dsLabel)
		error("STORMPAR:CORE:InvalidInput", "Both datastores must contain the same number of files");
	end
	
	% Set initial random state for example reproducibility.
	rng(nameValueArgs.rngSeed, nameValueArgs.rngGenerator);
	numFiles = numpartitions(dsImage);
	shuffledIndices = randperm(numFiles);
	
	% Ensure partition ratios are not percentages
	if any(nameValueArgs.partitionRatios > 1)
		nameValueArgs.partitionRatios = nameValueArgs.partitionRatios ./ 100;
	end
	
	% Get training subset indices
	numTrain = round(nameValueArgs.partitionRatios(1,1) * numFiles);
	trainIdx = shuffledIndices(1:numTrain);
	
	% Get vailation subset indices
	numVal = round(nameValueArgs.partitionRatios(1,2) * numFiles);
	valIdx = shuffledIndices(numTrain+1:numTrain+numVal);
	
	% Use remaining indices for testing.
	testIdx = shuffledIndices(numTrain+numVal+1:end);
	
	% Partition and combine the image and label datastores
	dsTrain = combine(subset(dsImage, trainIdx), subset(dsLabel, trainIdx));
	dsVal = combine(subset(dsImage, valIdx), subset(dsLabel, valIdx));
	dsTest = combine(subset(dsImage, testIdx), subset(dsLabel, testIdx));
	
	% Pull out augmentation variables to reduce overhead
	xTranslation = nameValueArgs.xTranslation;
	yTranslation = nameValueArgs.yTranslation;
	
	% Apply randomised augmentation to training data to prevent over-fitting
	dsTrain = transform(dsTrain, @augmentImageAndLabel);
	
	%% Custom augmentation function
	function dataOut = augmentImageAndLabel(data)
		% Augment RGB images and pixel label images using random reflection and
		% translation.
		
		% Initialise output
		dataOut = cell(size(data));
		
		for iImage = 1:size(data, 1)
			
			tform = randomAffine2d(...
				XReflection=true, ...
				YReflection=true, ...
				XTranslation=xTranslation, ...
				YTranslation=yTranslation);
			
			% Center the view at the center of image in the output space while
			% allowing translation to move the output image out of view.
			rout = affineOutputView(size(data{iImage, 1}), tform, BoundsStyle='centerOutput');
			
			% Warp the image and pixel labels using the same transform.
			dataOut{iImage, 1} = imwarp(data{iImage, 1}, tform, OutputView=rout);
			dataOut{iImage, 2} = imwarp(data{iImage, 2}, tform, OutputView=rout);
		end
	end
end