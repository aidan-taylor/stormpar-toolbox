function ds = loadImageArchive(filename)
	% LOADIMAGEARCHIVE
	%
	
	arguments
		filename (1,:) string = [];
	end
	
	if isempty(filename)
		% Promp user to choose a folder(s) and/or file(s) (must be in same folder)
		[file, location] = stormpar.deeplearning.utility.uiget(pwd, 'Title', 'Choose a NEXRAD Image Archive', 'MultiSelect', true);
		
		% If location returns an "empty" string array ("" shows as 1x1 array) assume ui was cancelled and error
		if isempty(location{:}), error('STORMPAR:IO:InvalidID', 'No local folder or file selected'); end
		
		% Form full path to chosen files
		filename = string(fullfile(location, file));
	end
	
	% Initialise ImageDatastore
	ds  = imageDatastore(filename, "IncludeSubfolders", true, "FileExtensions", '.png', LabelSource='foldernames');
	% 'ReadFcn', extractImage);
	
	% Add labels
	% labels = strings(size(ds.Files));
	% count = 1;
	% 
	% for sFile = ds.Files'
	% 	[location, name] = fileparts(sFile);
	% 	labelFile = fullfile(location, [name, '.txt']);
	% 
	% 	% Read the label file
	% 	labels(count) = fileread(labelFile);
	% 	count = count + 1;
	% end
	% 
	% ds.Labels = categorical(labels);
end


%%
function fcnHandle = extractImage %#ok<DEFNU>
	% EXTRACTIMAGE
	%
	
	% Output function handle
	fcnHandle = @extractImage;
	
	
	%% Custom imageDatastore read function
	function dataOut = extractImage(filename)
		
		% Read the image
		img = imread(filename);
		
		% Get the path to the label (should be in same folder with extension .txt)
		[location, name] = fileparts(filename);
		labelFile = fullfile(location, [name, '.txt']);
		
		% Read the label file
		label = fileread(labelFile);
		label = categorical(string(label));
		
		% Output the image and label in cell for neural network training format
		dataOut = {img, label};
	end
end