function dsAugmented = createImageAugmentation(ds, imageSize)
	%CREATEIMAGEAUGMENTATION Summary of this function goes here
	%   Detailed explanation goes here
	
	arguments
		ds (1,1) {isa(ds, 'matlab.io.datastore.ImageDatastore'), isa(ds, 'matlab.io.datastore.TransformedDatastore')}
		imageSize (1,2) double = [240, 240];
	end
	
	% Create image augmenter
	imageAugmenter = imageDataAugmenter('RandRotation', [0 360], ...
		'RandXReflection', true, 'RandYReflection', true);
	
	% Create augmented datastore
	dsAugmented = augmentedImageDatastore(imageSize, ds, ...
		'DataAugmentation', imageAugmenter, 'DispatchInBackground', true);
end