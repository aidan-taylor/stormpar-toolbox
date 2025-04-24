function dsTrain = createImageAndLabelAugmentation(dsTrain, xTrans, yTrans)
	%CREATEIMAGEANDLABELAUGMENTATION
	%
	
	arguments
		dsTrain (1,1) {isa(dsTrain, 'matlab.io.datastore.CombinedDatastore')}
		xTrans (1,2) = [-10, 10];
		yTrans (1,2) = [-10, 10];
	end
	
	% Augment data using custom function
	dsTrain = transform(dsTrain, @augmentImageAndLabel);
	
	%% Custom augmentation function
	function dataOut = augmentImageAndLabel(data)
		% Augment images and pixel label images using random reflection and
		% translation.
		
		for i = 1:size(data,1)
			
			tform = randomAffine2d(...
				XReflection=true, ...
				YReflection=true, ...
				XTranslation=xTrans, ...
				YTranslation=yTrans);
			
			% Center the view at the center of image in the output space while
			% allowing translation to move the output image out of view.
			rout = affineOutputView(size(data{i,1}), tform, BoundsStyle='centerOutput');
			
			% Warp the image and pixel labels using the same transform.
			dataOut{i,1} = imwarp(data{i,1}, tform, OutputView=rout); %#ok<AGROW>
			dataOut{i,2} = imwarp(data{i,2}, tform, OutputView=rout); %#ok<AGROW>
		end
	end
end
