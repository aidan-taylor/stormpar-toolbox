classdef reflectivityScale < uint8
	% REFLECTIVITYSCALE
	%
	
	enumeration
		NoData (0)
		ExLight (1)
		VeryLight (2)
		Light (3)
		Moderate (4)
		Heavy (5)
		ExHeavy (6)
	end
	
	methods
		function out = pixelColour(obj)
			%
			map = obj.colourMap(obj.nEnum);
			out = map(obj, :);
		end
		
		function out = nEnum(obj)
			%
			out = length(obj.list);
		end
		
		function out = categories(obj)
			%
			out = categorical(obj.list);
		end
		
		function out = list(obj)
			%
			out = string(enumeration(obj));
		end
	end
	
	methods (Hidden, Static)
		function out = colourMap(num)
			%
			out = lines(num);
		end
	end
end