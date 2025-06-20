function [dsTrain, dsVal, dsTest] = partitionSegmentationData(dsImage, dsLabel, nameValueArgs)
	% PARTITIONSEGMENTATIONLABEL Split the datastore into training, validation,
	% and testing sets and apply randomised augmentation to training data to
	% prevent over-fitting. 
	%
	%
	
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