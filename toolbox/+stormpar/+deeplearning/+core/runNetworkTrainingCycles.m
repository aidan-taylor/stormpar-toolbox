function [metrics, trainedNetwork] = runNetworkTrainingCycles(databaseLocation, networkName, nameValueArgs)
	
	arguments
		databaseLocation (1,1) string
		networkName (1,1) string {mustBeMember(networkName, ["resnet18", "mobilenetv2", "xception"])}
	end
	
	arguments
		nameValueArgs.saveLocation (1,1) string = pwd;
		nameValueArgs.imageSize (1,2) double = [360, 360];
		nameValueArgs.xTranslation (1,2) double = [-10, 10];
		nameValueArgs.yTranslation (1,2) double = [-10, 10];
		nameValueArgs.nCycles (1,1) double = 1;
	end
	
	% Encode the Level II data files to RGB image
	stormpar.deeplearning.core.encodeWeatherData(databaseLocation, ...
		'imageSize', nameValueArgs.imageSize);
	
	% Load the RGB images into an imageDatastore for use with the neural network
	[dsImage, dsLabel] = stormpar.deeplearning.io.loadSegmentationArchive(databaseLocation, ...
		"imageSize", nameValueArgs.imageSize);
	
	% Count labels to generate class weights (put this in stormpar.deeplearning.io.loadSegmentationArchive??)
	% tbl = countEachLabel(dsLabel);
	% imageFreq = tbl.PixelCount ./ tbl.ImagePixelCount;
	% classWeights = median(imageFreq) ./ imageFreq;
	
	% Split the datastore into training and validation sets (60% / 20% / 20%)
	[dsTrain, dsVal, dsTest] = stormpar.deeplearning.core.partitionSegmentationData(dsImage, dsLabel);
	
	% Apply randomised augmentation to training data to prevent over-fitting
	dsTrain = stormpar.deeplearning.core.createImageAndLabelAugmentation(dsTrain, ...
		nameValueArgs.xTranslation, nameValueArgs.yTranslation);
	
	% Get the name and number of classes to segment with
	classNames = string(enumeration('stormpar.deeplearning.utility.reflectivityScale'));
	numClasses = length(classNames);
	
	% Initialise Layers / Network
	intialisedNetwork = deeplabv3plus(nameValueArgs.imageSize, numClasses, networkName);
	
	% Setup training options. TODO this should be abstracted into a helper
	% function and parameterised.
	
	opts = trainingOptions("sgdm", ...
		ValidationData=dsVal, ...
		ValidationFrequency=30, ...
		Metrics="accuracy", ...
		ObjectiveMetricName="accuracy", ...
		Verbose=false, ...
		MiniBatchSize=1, ...
		OutputNetwork="best-validation", ...
		ValidationPatience=10);
	
	% Loop over the number of training cycles
	for iCycle  = 1:nameValueArgs.nCycles
		
		% Train network
		[trainedNetwork, trainingInfo] = trainnet(dsTrain, intialisedNetwork, "index-crossentropy", opts);
		
		% Form save path
		savePath = fullfile(nameValueArgs.saveLocation, 'NetworkOutputs', networkName, ...
			sprintf("%ix%i", nameValueArgs.imageSize(1,1), nameValueArgs.imageSize(1,2)), ...
			sprintf("TrainingCycle-%02i", iCycle));
		if ~isfolder(savePath), mkdir(savePath); end
		
		% Test Performance (this should be abstracted into a helper function)
		dsResults = semanticseg(dsTest, trainedNetwork, Classes=classNames, WriteLocation=savePath);
		metrics = evaluateSemanticSegmentation(dsResults, dsTest.UnderlyingDatastores{2});
		
		% Confusion histogram
		% figure;
		% cm = confusionchart(metrics.ConfusionMatrix.Variables, ...
		% classNames,Normalization="row-normalized");
		% cm.Title = "Normalized Confusion Matrix (%)";
		
		% Save outputs		
		save(fullfile(savePath, 'trainedNetwork.mat'), 'trainedNetwork');
		save(fullfile(savePath, 'trainingInfo.mat'), 'trainingInfo')
		save(fullfile(savePath, 'metrics.mat'), 'metrics');
	end