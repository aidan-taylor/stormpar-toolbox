function [dsTrain, dsVal, dsTest] = partitionSegmentationData(imds, pxds)
	% PARTITIONSEGMENTATIONLABEL Partition data by randomly selecting 60% of the
	% data for training. The rest is used for testing.
	
	% Set initial random state for example reproducibility.
	rng(0);
	numFiles = numpartitions(imds);
	shuffledIndices = randperm(numFiles);
	
	% Use 60% of the images for training.
	numTrain = round(0.60 * numFiles);
	trainingIdx = shuffledIndices(1:numTrain);
	
	% Use 20% of the images for validation
	numVal = round(0.20 * numFiles);
	valIdx = shuffledIndices(numTrain+1:numTrain+numVal);
	
	% Use the rest for testing.
	testIdx = shuffledIndices(numTrain+numVal+1:end);
	
	% Create image datastores for training and test.
	imdsTrain = subset(imds,trainingIdx);
	imdsVal = subset(imds,valIdx);
	imdsTest = subset(imds,testIdx);
	
	% Create pixel label datastores for training and test.
	pxdsTrain = subset(pxds,trainingIdx);
	pxdsVal = subset(pxds,valIdx);
	pxdsTest = subset(pxds,testIdx);
	
	% Combine the image and label datastores
	dsTrain = combine(imdsTrain, pxdsTrain);
	dsVal = combine(imdsVal, pxdsVal);
	dsTest = combine(imdsTest, pxdsTest);
end