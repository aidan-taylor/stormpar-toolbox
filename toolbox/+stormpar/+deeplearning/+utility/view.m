function viewer = view(ptCloud)
% VIEW View a point cloud object using pcviewer.
%

% Initialise point cloud viewer
viewer = pcviewer(ptCloud, 'CameraProjection', 'orthographic', 'ViewPlane', 'XY', 'ColorSource', 'Intensity', ...
	'PointSize', 0.1);