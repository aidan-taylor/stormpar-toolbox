function pathname = uiget(varargin)
	% UIGET Generic folder and/or file selection dialog box
	% Uses Java Swing package (built-in)
	%
	% ==================================
	% INPUTS (Name-Value)
	% ==================================
	%
	% ExtensionFilter  (:,2) cell 
	%		Specify a custom file extension filter where each
	%		row is {extension(s), description} as follows uigetfile syntax.
	%
	% MultiSelect (1,1) logical 
	%		Specify whether a user can select multiple files and/or folders
	%
	% Title (1,1) string 
	%		Specify a custom dialog title
	%
	% SelectionMode (1,1) string {"default", "folders", "files"}
	%		Specify whether only files / folders / both can be selected by the
	%		dialog
	%
	% =======
	% OUTPUTS
	% =======
	%
	% pathname (1,:) string 
	%		String containing the absolute paths to the chosen file(s) and/or folder(s).
	%
	% ==========
	% References
	% ==========
	% .. [1] https://docs.oracle.com/javase/8/docs/api/javax/swing/UIManager.html
	% .. [2] https://docs.oracle.com/javase/8/docs/api/javax/swing/JFileChooser.html
	%
	% See also UIGETDIR, UIGETFILE
	
	% arguments
	% 	nameValueArgs.MultiSelect (1,1) logical = false;
	% 	nameValueArgs.Title (1,1) string = "Select File or Folder";
	% end
	
	% Check if supported in execution context
	validateModalDialogsCapability(AllowInNoFigureWindows=true);
	
	% Parse inputs
	p = inputParser;
	p.addParameter('ExtensionFilter', [], @(x)iscell(x));
	p.addParameter('MultiSelect', false, @(x)islogical(x))
	p.addParameter('Title', 'Select File or Folder', @(x)mustBeTextScalar(x))
	p.addParameter('SelectionMode', 'default', @(x)mustBeTextScalar(x))
	p.parse(varargin{:});
	
	% First disable the ability of the ui to rename file(s) and folder(s) [1]
	javax.swing.UIManager.put('FileChooser.readOnly', true);
	
	% Initialize JFileChooser interface [2]
	jFC = javax.swing.JFileChooser(pwd);
	jFC.setDialogTitle(p.Results.Title);
	
	% Specify selection mode
	if strncmpi(p.Results.SelectionMode, "files", 4)
		jFC.setFileSelectionMode(jFC.FILES_ONLY);
	elseif strncmpi(p.Results.SelectionMode, "folders", 6)
		jFC.setFileSelectionMode(jFC.DIRECTORIES_ONLY);
	else
		jFC.setFileSelectionMode(jFC.FILES_AND_DIRECTORIES);
	end
	
	
	% Sort file filter. TODO -- Clean up extension handling
	if ~isempty(p.Results.ExtensionFilter)
		extensions = parsefilter(p.Results.ExtensionFilter(:, 1));
		
		nfilters = size(p.Results.ExtensionFilter, 1);
		for ii = 1:nfilters
			if isempty(extensions{ii})
				% Catch invalid extension specs
				continue
			end
			jExtensionFilter = javax.swing.filechooser.FileNameExtensionFilter(p.Results.ExtensionFilter{ii, 2}, extensions{ii});
			jFC.addChoosableFileFilter(jExtensionFilter)
		end
		
		tmp = jFC.getChoosableFileFilters();
		jFC.setFileFilter(tmp(2))
	end
	
	% Handle multiple file/folder selection
	if p.Results.MultiSelect
		jFC.setMultiSelectionEnabled(true)
		
		% Change title if default is being used. TODO -- Does this needs
		% changing to use arguments block?
		if any(strcmp(p.UsingDefaults, 'Title'))
			jFC.setDialogTitle('Select File(s) and/or Folder(s)')
		end
	else
		jFC.setMultiSelectionEnabled(false)
	end
	
	% Interact with dialog (implicitly suspends matlab window)
	success = jFC.showOpenDialog([]);
	
	% Handle dialog return options
	switch success
		
		case jFC.APPROVE_OPTION
			% getSelectedFiles is empty when MultiSelect is disabled and
			% getSelectedFile is scalar on enable.
			if jFC.isMultiSelectionEnabled
				pathname = string(jFC.getSelectedFiles())';
			else
				pathname = string(jFC.getSelectedFile());
			end
			
		case jFC.CANCEL_OPTION
			% Short-circuit: Return numeric array on cancel (easier to parse
			% than an initialised but empty string)
			pathname = 0;
			return
			
		otherwise
			% Handled error in JFileChooser
			error('UIGET:DIALOG:JavaException', 'Unsupported result returned from JFileChooser: %i.', success);
	end
	
	% TODO -- Do I need more handling?
	
	%%
function extensions = parsefilter(incell)
	% Parse the extension filter extensions into a format usable by
	% javax.swing.filechooser.FileNameExtensionFilter
	%
	% Since we're keeping with the uigetdir-esque extension syntax
	% (e.g. *.extension), we need strip off '*.' from each for compatibility
	% with the Java component.
	extensions = cell(size(incell));
	for ii = 1:numel(incell)
		exp = '\*\.(\w+)';
		extensions{ii} = string(regexp(incell{ii}, exp, 'tokens'));
	end