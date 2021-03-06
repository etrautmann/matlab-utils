function sz = figSize(varargin)
% figsize(figh, height, width)
% figsize(height, width) - uses gcf by default
% 
% Sizes figure to height x width in cm

if nargin < 2
    if nargin == 0
        figh = gcf;
    else
        figh = varargin{1};
    end
    
    % return current figsize as [h w] in cm
    set(figh, 'PaperUnits' ,'centimeters');
    set(figh, 'Units', 'centimeters');
    figPos = get(figh,'Position');
    sz = [figPos(4), figPos(3)];
    return;
end

% set the position

if(nargin == 3)
    figh = varargin{1};
    height = varargin{2};
    width = varargin{3};
elseif(nargin == 2)
    if ishandle(varargin{1})
        figh = varargin{1};
        width = varargin{2}(2);
        height = varargin{2}(1);
    else
        figh = gcf;
        height = varargin{1};
        width = varargin{2};
    end
else
    error('Requires 2 or 3 arguments: [figh=gcf], height, width');
end

% undock figure
set(figh, 'WindowStyle', 'normal');
drawnow;

set(figh, 'PaperUnits' ,'centimeters');
set(figh, 'Units', 'centimeters');
figPos = get(figh,'Position');

set(figh, 'PaperPositionMode', 'auto');
newPos = [figPos(1), figPos(2), width, height];

if ~strcmp(get(figh, 'WindowStyle'), 'docked')
    set(figh, 'Position', newPos);
end

if ~isempty(get(gcf, 'CurrentAxes'))
    au = AutoAxis.recoverForAxis(gca);
    if ~isempty(au)
        au.update();
    end
end

sz = [height, width];

