classdef AutoAxis < handle & matlab.mixin.Copyable
% Class for redrawing axis annotations and aligning them according to 
% relative to each other using paper units. Automatically updates this
% placement whenever the axis is panned, zoomed, etc.
% 
% Try ax = AutoAxis.replace(gca) to get started.
%
% Author: Dan O'Shea, {my first name} AT djoshea.com (c) 2014
%
% NOTE: This class graciously utilizes code from the following authors:
%
% Malcolm Lidierth: For the isMultipleCall utility to prevent callback
%   re-entrancy
%   http://undocumentedmatlab.com/blog/controlling-callback-re-entrancy/
%

    properties(Dependent) % Utility properties that read/write through 
        axisPaddingLeft
        axisPaddingBottom
        axisPaddingRight
        axisPaddingTop
        
        axisMarginLeft
        axisMarginBottom
        axisMarginRight
        axisMarginTop 
        
        % note that these are only used when addXLabelAnchoredToAxis is
        % used to anchor the label directly to the axis, not to the
        % decorations on that side of the axis.
        axisLabelOffsetLeft
        axisLabelOffsetBottom
        axisLabelOffsetTop
        axisLabelOffsetRight
        
        % these are used when addXLabel or addYLabel are used to anchor the
        % x and y labels off of the known decorations on that side of the
        % axis, rather than the axes themselves. This is more typical of
        % the way Matlab positions the labels, but reduces the likelihood
        % of getting consistent positioning among axes
        decorationLabelOffsetLeft
        decorationLabelOffsetBottom
        decorationLabelOffsetTop
        decorationLabelOffsetRight
    end

    properties
        % units used by all properties and anchor measurements
        % set this before creating any anchors
        units = 'centimeters';
        
        % ticks and tick labels
        tickColor = [0 0 0];
        tickLength = 0.05; % 0.15
        tickLineWidth = 0.5; % not in centimeters, this is stroke width
        tickFontColor
        tickFontSize
        
        % size of marker diameter
        markerDiameter = 0.2;
        % interval thickness. Note that intervals should be thinner than
        % the marker diameter for the vertical alignment to work correctly 
        % Note that interval location and label location is determined by
        % markerDiameter
        intervalThickness = 0.1;
        
        % this controls both the gap between tick lines and tick labels,
        % and between tick labels and axis label offset
        tickLabelOffset = 0.1; % cm
        
        markerLabelOffset = 0.1; % cm
        
        % axis x/y labels
        labelFontSize
        labelFontColor
        
        % plot title
        titleFontSize
        titleFontColor
        
        % scale bar 
        scaleBarThickness = 0.15; % cm
        xUnits = '';
        yUnits = '';
        keepAutoScaleBarsEqual = false;
        scaleBarColor
        scaleBarFontColor
        scaleBarFontSize
        
        debug = false;
    end
    
    properties(Hidden)
        % gap between axis limits (Position) and OuterPosition of axes
        % only used when axis is not managed by panel
%         axisMargin = [2.5 2.5 1.5 1.5]; % [left bottom right top] 
        axisMargin = [1.5 1.0 0.75 0.75]; % [left bottom right top] 
        % left: room for y-axis
        % bottom: room for x-axis
        % right: room for y-scale bar and label
        % top: room for title
        
        % spacing between axes and any ticks, lines, marks along each axis
        axisPadding = [0.1 0.1 0.1 0.1]; % [left bottom right top] 
     
        % when x or y label is anchored to the axis directly, these offsets
        % are used. This will be the case if addXLabelAnchoredToAxis is
        % used.
        axisLabelOffset = [0.55 0.55 0.55 0.55]; % cm
        
        % when x or y label is anchored to the outer edge of the axis
        % decorations, e.g. belowX or leftY, these smaller offsets are
        % used. This will be the case if addXLabelAnchoredToDecorations is
        % used
        decorationLabelOffset = [0.1 0.05 0.1 0.1]; % cm
    end
    
    properties(SetAccess=protected)
        requiresReconfigure = true;
        installedCallbacks = false;
        hListeners = [];
        currentlyRepositioningAxes = false;
        
        hClaListener = [];
    end
      
    methods % Implementations for dependent properties above
        function set.axisPadding(ax, v)
            if numel(v) == 1
                ax.axisPadding = [v v v v];
            elseif numel(v) == 2 % assume horz, vert
                ax.axisPadding = [makerow(v), makerow(v)];
            else
                ax.axisPadding = makerow(v);
            end
        end
                        
        function v = get.axisPaddingLeft(ax)
            v = ax.axisPadding(1);
        end
        
        function set.axisPaddingLeft(ax, v)
            ax.axisPadding(1) = v;
        end
        
        function v = get.axisPaddingBottom(ax)
            v = ax.axisPadding(2);
        end
        
        function set.axisPaddingBottom(ax, v)
            ax.axisPadding(2) = v;
        end
        
        function v = get.axisPaddingRight(ax)
            v = ax.axisPadding(3);
        end
        
        function set.axisPaddingRight(ax, v)
            ax.axisPadding(3) = v;
        end
        
        function v = get.axisPaddingTop(ax)
            v = ax.axisPadding(4);
        end
        
        function set.axisPaddingTop(ax, v)
            ax.axisPadding(4) = v;
        end
        
        function set.axisMargin(ax, v)
            if numel(v) == 1
                ax.axisMargin = [v v v v];
            elseif numel(v) == 2 % assume horz, vert
                ax.axisMargin = [makerow(v), makerow(v)];
            else
                ax.axisMargin = makerow(v);
            end
        end
        
        function v = get.axisMarginLeft(ax)
            v = ax.axisMargin(1);
        end
        
        function set.axisMarginLeft(ax, v)
            ax.axisMargin(1) = v;
        end
        
        function v = get.axisMarginBottom(ax)
            v = ax.axisMargin(2);
        end
        
        function set.axisMarginBottom(ax, v)
            ax.axisMargin(2) = v;
        end
        
        function v = get.axisMarginRight(ax)
            v = ax.axisMargin(3);
        end
        
        function set.axisMarginRight(ax, v)
            ax.axisMargin(3) = v;
        end
        
        function v = get.axisMarginTop(ax)
            v = ax.axisMargin(4);
        end
        
        function set.axisMarginTop(ax, v)
            ax.axisMargin(4) = v;
        end
        
        function v = get.axisLabelOffsetLeft(ax)
            v = ax.axisLabelOffset(1);
        end
        
        function set.axisLabelOffsetLeft(ax, v)
            ax.axisLabelOffset(1) = v;
        end
        
        function v = get.axisLabelOffsetBottom(ax)
            v = ax.axisLabelOffset(2);
        end
        
        function set.axisLabelOffsetBottom(ax, v)
            ax.axisLabelOffset(2) = v;
        end
        
        function v = get.axisLabelOffsetRight(ax)
            v = ax.axisLabelOffset(3);
        end
        
        function set.axisLabelOffsetRight(ax, v)
            ax.axisLabelOffset(3) = v;
        end
        
        function v = get.axisLabelOffsetTop(ax)
            v = ax.axisLabelOffset(4);
        end
        
        function set.axisLabelOffsetTop(ax, v)
            ax.axisLabelOffset(4) = v;
        end
        
        function v = get.decorationLabelOffsetLeft(ax)
            v = ax.decorationLabelOffset(1);
        end
        
        function set.decorationLabelOffsetLeft(ax, v)
            ax.decorationLabelOffset(1) = v;
        end
        
        function v = get.decorationLabelOffsetBottom(ax)
            v = ax.decorationLabelOffset(2);
        end
        
        function set.decorationLabelOffsetBottom(ax, v)
            ax.decorationLabelOffset(2) = v;
        end
        
        function v = get.decorationLabelOffsetRight(ax)
            v = ax.decorationLabelOffset(3);
        end
        
        function set.decorationLabelOffsetRight(ax, v)
            ax.decorationLabelOffset(3) = v;
        end
        
        function v = get.decorationLabelOffsetTop(ax)
            v = ax.decorationLabelOffset(4);
        end
        
        function set.decorationLabelOffsetTop(ax, v)
            ax.decorationLabelOffset(4) = v;
        end
    end
        
    properties(Hidden, SetAccess=protected)
        axh % axis handle to which I am attached (client axis)
        
        usingOverlay = false;
        axhDraw % axis handle into which I am drawing (private axis, though may be the same as axh when usingOverlay is false)
        
        anchorInfo % array of AutoAxisAnchorInfo objects that I enforce on update()
        
        % contains a copy of the anchors in anchor info where all handle collection and property value references are looked up 
        % see .derefAnchorInfo
        anchorInfoDeref
        
        refreshNeeded = true;
        
        % map graphics to LocationCurrent objects
        mapLocationHandles
        mapLocationCurrent
        
        collections = struct(); % struct which contains named collections of handles
        
        nextTagId = 0; % integer indicating the next free index to use when generating tags for handles
        
        % maps handles --> tag strings
        handleTagObjects
        handleTagStrings
        
        tagOverlayAxis = ''; % tag used for the overlay axis
        
        % these hold on to specific special objects that have been added
        % to the plot
        autoAxisX
        autoAxisY
        autoScaleBarX
        autoScaleBarY
        hTitle
        hXLabel
        hYLabel
        
        lastXLim
        lastYLim
    end

    properties(Hidden, SetAccess=protected)
        xDataToUnits
        yDataToUnits
        
        xDataToPoints
        yDataToPoints
        
        xDataToPixels
        yDataToPixels
        
        xReverse % true/false if xDir is reverse
        yReverse % true/false if yDir is reverse
    end
    
    methods
        function ax = AutoAxis(axh)
            if nargin < 1 || isempty(axh)
                axh = gca;
            end
            
            ax = AutoAxis.createOrRecoverInstance(ax, axh);
        end
    end
    
    methods(Static)
        function hideInLegend(h)
            % prevent object h from appearing in legend by default
            for i = 1:numel(h)
                ann = get(h(i), 'Annotation');
                leg = get(ann, 'LegendInformation');
                set(leg, 'IconDisplayStyle', 'off');
            end
        end
        
        function figureCallback(figh, varargin)
            if AutoAxis.isMultipleCall(), return, end;
            AutoAxis.updateFigure(figh);
        end
        
%         function figureDeferredCallback(figh, varargin)
%             figData = get(figh, 'UserData');
%             hTimer = [];
%             if isstruct(figData) && isfield(figData, 'hTimer') 
%                 hTimer = figData.hTimer;
%             end
%             if ~isempty(hTimer) && isa(hTimer, 'timer')
%                 % stop the timer to delay it's triggering
%                 stop(hTimer);
%             else
%                 % create the timer
%                 hTimer = timer('StartDelay', 0.1, 'TimerFcn', @(varargin) AutoAxis.figureCallback(figh));
%                 if ~isstruct(figData), figData = struct(); end
%                 figData.hTimer = hTimer;
%                 set(figh, 'UserData', figData);
%             end
%             
%             % start it soon
%             tStart = now + 0.1 / (60^2*24);
%             startat(hTimer, tStart);
%         end
        
        function flag = isMultipleCall()
            % determine whether callback is being called within itself
            flag = false; 
            % Get the stack
            s = dbstack();
            if numel(s) <= 2
                % Stack too short for a multiple call
                return
            end

            % How many calls to the calling function are in the stack?
            names = {s(:).name};
            TF = strcmp(s(2).name,names);
            count = sum(TF);
            if count>1
                % More than 1
                flag = true; 
            end
        end
        
        function hvec = allocateHandleVector(num)
            if verLessThan('matlab','8.4.0')
                hvec = nan(num, 1);
            else
                hvec = gobjects(num, 1);
            end
        end
        
        function hn = getNullHandle()
            if verLessThan('matlab','8.4.0')
                hn = NaN;
            else
                hn = matlab.graphics.GraphicsPlaceholder();
            end
        end
        
        function tag = generateFigureUniqueTag(figh, prefix)
            if nargin < 2
                prefix = 'autoAxis';
            end
            while true
                validChars = ['a':'z', 'A':'Z', '0':'9'];
                tag = sprintf('%s_%s', prefix, randsample(validChars, 20));
                if nargin >= 1
                    obj = findall(figh, 'Tag', tag);
                    if isempty(obj)
                        return;
                    end
                else
                    return;
                end
            end  
        end
        
        function updateFigure(figh)
            % call auto axis update for every managed axis in a figure
            if nargin < 1
                figh = gcf;
            end
            
            axCell = AutoAxis.recoverForFigure(figh);
            for i = 1:numel(axCell)
                axCell{i}.update();
            end
        end
        
        function updateIfInstalled(axh)
            % supports either axis or figure handle
            if nargin < 1
                axh = gca;
            end
            if isa(axh, 'matlab.graphics.axis.Axes')
                au = AutoAxis.recoverForAxis(axh);
                if ~isempty(au)
                    au.update();
    %                 au.installCallbacks();
                end
            elseif isa(axh, 'matlab.ui.Figure');
                AutoAxis.updateFigure(axh);
            end
        end
        
        function fig = getParentFigure(axh)
            % if the object is a figure or figure descendent, return the
            % figure. Otherwise return [].
            fig = axh;
            while ~isempty(fig) && ~strcmp('figure', get(fig,'type'))
              fig = get(fig,'parent');
            end
        end
        
        function p = getPanelForFigure(figh)
            % return a handle to the panel object associated with figure
            % figh or [] if not associated with a panel
            p = panel.recover(figh);
%             if isempty(p)
%                 p = panel.recover(figh);
%             end
        end
        
        function axCell = recoverForFigure(figh)
            % recover the AutoAxis instances associated with all axes in
            % figure handle figh
            if nargin < 1, figh = gcf; end;
            hAxes = findall(figh, 'Type', 'axes');
            axCell = cell(numel(hAxes), 1);
            for i = 1:numel(hAxes)
                axCell{i} = AutoAxis.recoverForAxis(hAxes(i));
            end
            
            axCell = axCell(~cellfun(@isempty, axCell));
        end
        
        function ax = recoverForAxis(axh)
            % recover the AutoAxis instance associated with the axis handle
            if nargin < 1, axh = gca; end
            ax = getappdata(axh, 'AutoAxisInstance');
        end
        
        function ax = createOrRecoverInstance(ax, axh)
            % if an instance is stored in this axis' UserData.autoAxis
            % then return the existing instance, otherwise create a new one
            % and install it
            
            axTest = AutoAxis.recoverForAxis(axh);
            if isempty(axTest)
                % not installed, create new
                ax.initializeNewInstance(axh);
                ax.installInstanceForAxis(axh);
            else
                % return the existing instance
                ax = axTest;
            end
        end
        
        function claCallback(axh, varargin)
            % reset the autoaxis associated with this axis if the axis is
            % cleared
            ax = AutoAxis.recoverForAxis(axh);
            if ~isempty(ax)
                %disp('resetting auto axis');
                ax.reset();
            end
        end
    end
    
    methods % Installation, callbacks, tagging, collections
        function ax = saveobj(ax)
             % delete the listener callbacks
             delete(ax.hListeners);
             ax.hListeners = [];
             ax.pruneStoredHandles();
             ax.requiresReconfigure = true;
             
             % on a timer, reinstall my callbacks since the listeners have
             % been detached for the save
             timer('StartDelay', 0.2, 'TimerFcn', @(varargin) ax.installCallbacks());
          end
        
        function initializeNewInstance(ax, axh)
            ax.axh = axh;
            
            % this flag is used for save/load reconfiguration
            ax.requiresReconfigure = false;
            
            % initialize handle tagging (for load/copy
            % auto-reconfiguration)
            ax.handleTagObjects = AutoAxis.allocateHandleVector(0);
            ax.handleTagStrings = {};
            ax.nextTagId = 1;
            
            % determine whether we're drawing into an overlay axis
            % or directly into this axis
            figh = AutoAxis.getParentFigure(ax.axh);
            if strcmp(get(figh, 'Renderer'), 'OpenGL')
                % create the overlay axis
                ax.usingOverlay = true;
                
                % create the overlay axis on top, without changing current
                % axes
                oldCA = gca; % cache gca
                ax.axhDraw = axes('Position', [0 0 1 1], 'Parent', figh);
                axis(ax.axhDraw, axis(ax.axh));
                axes(oldCA); % restore old gca
                
                % tag overlay axis with a random figure-unique string so
                % that we can recover it later (don't use tagHandle here, 
                % which is for the contents of axhDraw which don't need to
                % be figure unique). Don't overwrite the tag if it exists
                % to play nice with tagging by MultiAxis.
                tag = get(ax.axhDraw, 'Tag');
                if isempty(tag)
                    ax.tagOverlayAxis = AutoAxis.generateFigureUniqueTag(figh, 'autoAxisOverlay');
                    set(ax.axhDraw, 'Tag', ax.tagOverlayAxis);
                else
                    ax.tagOverlayAxis = tag;
                end
                hold(ax.axhDraw, 'on');
                
                ax.updateOverlayAxisPositioning();
            else
                ax.usingOverlay = false;
                ax.axhDraw = ax.axh;
            end
            
            %ax.hMap = containers.Map('KeyType', 'char', 'ValueType', 'any'); % allow handle arrays too
            ax.anchorInfo = AutoAxis.AnchorInfo.empty(0,1);
            ax.anchorInfoDeref = [];
            ax.collections = struct();
            
            sz = get(ax.axh, 'FontSize');
            tc = get(ax.axh, 'DefaultTextColor');
            lc = get(ax.axh, 'DefaultLineColor');
            %ax.tickColor = lc;
            ax.tickFontSize = sz;
            ax.tickFontColor = tc;
            ax.labelFontColor = tc;
            ax.labelFontSize = sz;
            ax.titleFontSize = sz;
            ax.titleFontColor = tc;
            ax.scaleBarColor = lc;
            ax.scaleBarFontSize = sz;
            ax.scaleBarFontColor = tc;

            ax.mapLocationHandles = AutoAxis.allocateHandleVector(0);
            ax.mapLocationCurrent = {};
        end
             
        function installInstanceForAxis(ax, axh)
            setappdata(axh, 'AutoAxisInstance', ax); 
            ax.addTitle();
            ax.addXLabelAnchoredToAxis();
            ax.addYLabelAnchoredToAxis();
            ax.installCallbacks();
            ax.installClaListener();
        end
        
        function installCallbacks(ax)
            figh = AutoAxis.getParentFigure(ax.axh);
           
            % these work faster than listening on xlim and ylim, but can
            % not update depending on how the axis limits are set
            set(zoom(ax.axh),'ActionPreCallback',@ax.prePanZoomCallback);
            set(pan(figh),'ActionPreCallback',@ax.prePanZoomCallback);
            set(zoom(ax.axh),'ActionPostCallback',@ax.postPanZoomCallback);
            set(pan(figh),'ActionPostCallback',@ax.postPanZoomCallback);

            % updates entire figure at once
            set(figh, 'ResizeFcn', @(varargin) AutoAxis.figureCallback(figh));
            
            % listeners need to be cached so that we can delete them before
            % saving.
            hl(1) = addlistener(ax.axh, {'XDir', 'YDir'}, 'PostSet', @ax.axisCallback);
            hl(2) = addlistener(ax.axh, {'XLim', 'YLim'}, 'PostSet', @ax.axisIfLimsChangedCallback);
            ax.hListeners = hl;
            
            p = AutoAxis.getPanelForFigure(figh);
            if ~isempty(p)
                p.setCallback(@(varargin) AutoAxis.figureCallback(figh));
            end
            
            ax.installedCallbacks = true;
            
            %set(figh, 'ResizeFcn', @(varargin) disp('resize'));
            %addlistener(ax.axh, 'Position', 'PostSet', @(varargin) disp('axis size'));
            %addlistener(figh, 'Position', 'PostSet', @ax.figureCallback);
        end
        
        function installClaListener(ax)
            % reset this instance if the axis is cleared
            ax.hClaListener = event.listener(ax.axh, 'Cla', @AutoAxis.claCallback);
        end
        
        function isActive = checkCallbacksActive(ax)
            % look in the callbacks to see if the callbacks are still
            % installed
            hax = get(zoom(ax.axh),'ActionPostCallback');
            figh = AutoAxis.getParentFigure(ax.axh);
            hfig = get(figh, 'ResizeFcn');
            isActive = ~isempty(hax) && ~isempty(hfig);
        end
        
%          function uninstall(~)
% %             lh(1) = addlistener(ax.axh, {'XLim', 'YLim'}, ...
% %                 'PostSet', @ax.updateLimsCallback);
%             return;
%             figh = ax.getParentFigure();
%             set(pan(figh),'ActionPostCallback', []);
%             set(figh, 'ResizeFcn', []);
%             %addlistener(ax.axh, 'Position', 'PostSet', @ax.updateFigSizeCallback);
%         end
        
        function tf = checkLimsChanged(ax)
            tf = ~isequal(get(ax.axh, 'XLim'), ax.lastXLim) || ...
                ~isequal(get(ax.axh, 'YLim'), ax.lastYLim);
%             
%             if tf
%                 xl = get(ax.axh, 'XLim');
%                 yl = get(ax.axh, 'YLim');
%                 fprintf('Change [%.1f %.1f / %.1f %.1f] to [%.1f %.1f / %.1f %.1f]\n', ...
%                     ax.lastXLim(1), ax.lastXLim(2), ax.lastYLim(1), ax.lastYLim(1), ...
%                     xl(1), xl(2), yl(1), yl(2));
%             else
%                 fprintf('No Change [%.1f %.1f / %.1f %.1f]\n', ax.lastXLim(1), ax.lastXLim(2), ax.lastYLim(1), ax.lastYLim(1));
%             end
        end
        
        function prePanZoomCallback(ax, varargin)
            % first, due to weird issues with panning, make sure we have
            % the right auto axis for this update
            if numel(varargin) >= 2 && isstruct(varargin{2}) && isfield(varargin{2}, 'Axes')
                 axh = varargin{2}.Axes;
                 if ax.axh ~= axh
                     % try finding an AutoAxis for the axh that was passed in
                     ax = AutoAxis.recoverForAxis(axh);
                     if isempty(ax)
                         return;
                     end
                 end
            end
            ax.currentlyRepositioningAxes = true;
%             disp('Deleting listeners');
            delete(ax.hListeners);
            ax.hListeners = [];
        end
        
        function postPanZoomCallback(ax, varargin)
            % first, due to weird issues with panning, make sure we have
            % the right auto axis for this update
            if numel(varargin) >= 2 && isstruct(varargin{2}) && isfield(varargin{2}, 'Axes')
                 axh = varargin{2}.Axes;
                 if ax.axh ~= axh
                     % try finding an AutoAxis for the axh that was passed in
                     ax = AutoAxis.recoverForAxis(axh);
                     if isempty(ax)
                         return;
                     end
                 end
            end
            ax.currentlyRepositioningAxes = false;
            ax.axisCallback(varargin{:});
%             disp('Readding listeners');
            ax.installCallbacks();
        end 
        
        function axisIfLimsChangedCallback(ax, varargin)
            % similar to axis callback, but skips update if the limits
            % haven't changed since the last update
            if ax.isMultipleCall(), return, end;
            
            if ax.currentlyRepositioningAxes
                % suppress updates when panning / zooming
                return;
            end
            
            % here we get clever. when panning or zooming, LocSetLimits is
            % used to set XLim, then YLim, which leads to two updates. We
            % check whether we're being called via LocSetLimits and then
            % don't update if we're setting the XLim, only letting the YLim
            % update pass through. This cuts our update time in half
            if numel(varargin) >= 1 && isa(varargin{1}, 'matlab.graphics.internal.GraphicsMetaProperty') 
                if strcmp(varargin{1}.Name, 'XLim')
                    %disp('X Update');
                    
                    % setting XLim, skip if in LocSetLimits
                    st = dbstack();
                    if ismember('LocSetLimits', {st.name})
                        %disp('Skipping X Update');
                        return;
                    end
                elseif strcmp(varargin{1}.Name, 'YLim')
                    %disp('Y Update');
                end
                
                
            end

            if ax.checkLimsChanged()
                ax.axisCallback();
            end
        end
        
        function axisCallback(ax, varargin)
            if ax.isMultipleCall(), return, end;
            
             if numel(varargin) >= 2 && isstruct(varargin{2}) && isfield(varargin{2}, 'Axes')
                 axh = varargin{2}.Axes;
                 if ax.axh ~= axh
                     % try finding an AutoAxis for the axh that was passed in
                     axOther = AutoAxis.recoverForAxis(axh);
                     if ~isempty(axOther)
                         axOther.update();
                     else
                         % axis handle mismatch, happens sometimes if we save/load
                         % a figure. might need to remap handle pointers,
                         % though this should have happened automatically
                         % during load already
                         warning('AutoAxis axis callback triggered for different axis which has no AutoAxis itself.');
                         return;
%                          ax.axh = axh;
%                          ax.reconfigurePostLoad();
                     end
                 end
             end
             if ~isempty(ax.axh)
                 ax.update();
             end
        end
        
        function reconfigurePostLoad(ax)
            % when loading from .fig files, all of the handles for the
            % graphics objects will have changed. go through each
            % referenced handle, look up its tag, and then replace the
            % reference with the new handle number.
            
            % loop through all of the tags we've stored, and build a map
            % from old handle to new handle
            
            % first find the overlay axis
            figh = AutoAxis.getParentFigure(ax.axh);
            if ~isempty(ax.tagOverlayAxis)
                ax.axhDraw = findall(figh, 'Tag', ax.tagOverlayAxis, 'Type', 'axis');
                if isempty(ax.axhDraw)
                    error('Could not locate overlay axis. Uninstalling');
                    %ax.uninstall();
                end
            end
            
            % build map old handle -> new handle
            oldH = ax.handleTagObjects;
            newH = oldH;
            tags = ax.handleTagStrings;
            for iH = 1:numel(oldH)
                % special case when searching for the axis itself
                if strcmp(ax.axhDraw.Tag, tags{iH})
                    continue;
                end
                hNew = findall(ax.axhDraw, 'Tag', tags{iH});
                if isempty(hNew)
                    warning('Could not recover tagged handle');
                    hNew = AutoAxis.getNullHandle();
                end
                
                newH(iH) = hNew(1);
            end
            
            % go through anchors and replace old handles with new handles
            for iA = 1:numel(ax.anchorInfo)
                if ~ischar(ax.anchorInfo(iA).ha)
                    ax.anchorInfo(iA).ha = updateHVec(ax.anchorInfo(iA).ha, oldH, newH);
                end
                if ~ischar(ax.anchorInfo(iA).h)
                    ax.anchorInfo(iA).h  = updateHVec(ax.anchorInfo(iA).h, oldH, newH);
                end
            end
            
            % go through collections and relace old handles with new
            % handles
            cNames = fieldnames(ax.collections);
            for iC = 1:numel(cNames)
                ax.collections.(cNames{iC}) = updateHVec(ax.collections.(cNames{iC}), oldH, newH);
            end
            
            % last, reinstall callbacks if they were installed originally
            if ax.installedCallbacks
                ax.installCallbacks();
            end
            
            ax.requiresReconfigure = false;
            
            function new = updateHVec(old, oldH, newH)
                new = old;
                for iOld = 1:numel(old)
                    [tf, idx] = ismember(old(iOld), oldH);
                    if tf
                        new(iOld) = newH(idx);
                    else
                        new(iOld) = AutoAxis.getNullHandle();
                    end
                end
            end     
        end
        
        function tags = tagHandle(ax, hvec)
            % for each handle in vector hvec, set 'Tag'
            % on that handle to be something unique, and add this handle and
            % its tag to the .handleTag lookup table. 
            % This is used by recoverTaggedHandles
            % to repopulate stored handles upon figure loading or copying
            
            tags = cell(numel(hvec), 1);
            for iH = 1:numel(hvec)
                tags{iH} = ax.lookupHandleTag(hvec(iH));
                if isempty(tags{iH})
                    % doesn't already exist in map
                    tag = get(hvec(iH), 'Tag');
                    if isempty(tag)
                        tag = sprintf('autoAxis_%d', ax.nextTagId);
                    end
                    tags{iH} = tag;
                    ax.nextTagId = ax.nextTagId + 1;
                    ax.handleTagObjects(end+1) = hvec(iH);
                    ax.handleTagStrings{end+1} = tags{iH};
                end
                
                set(hvec(iH), 'Tag', tags{iH});
            end
        end
        
        function tag = lookupHandleTag(ax, h)
            [tf, idx] = ismember(h, ax.handleTagObjects);
            if tf
                tag = ax.handleTagStrings{idx(1)};
            else
                tag = '';
            end
        end
        
        function pruneStoredHandles(ax)
            % remove any invalid handles from my collections and tag lists
            
            % remove from tag cache
            mask = isvalid(ax.handleTagObjects);
            ax.handleTagObjects = ax.handleTagObjects(mask);
            ax.handleTagStrings = ax.handleTagStrings(mask);
            names = ax.listHandleCollections();
            
            % remove invalid handles from all handle collections
            for i = 1:numel(names)
                hvec = ax.collections.(names{i});
                ax.collections.(names{i}) = hvec(isvalid(hvec));
            end
        end
        
        function addHandlesToCollection(ax, name, hvec)
            % add handles in hvec to the list ax.(name), updating all
            % anchors that involve that handle
            
            if ~isfield(ax.collections, name)
                oldHvec = [];
            else
                oldHvec = ax.collections.(name);
            end

            newHvec = makecol(union(oldHvec, hvec));
            
            % install the new collection
            ax.collections.(name) = newHvec;
            
            % make sure the handles are tagged
            ax.tagHandle(hvec);
            
            ax.refreshNeeded = true;
        end
        
        function names = listHandleCollections(ax)
            % return a list of all handle collection properties
            names = fieldnames(ax.collections);
        end
        
        function h = getHandlesInCollection(ax, name)
            if isfield(ax.collections, name)
                h = ax.collections.(name);
            elseif isfield(ax, name)
                h = ax.(name);
            else
                h = AutoAxis.allocateHandleVector(0);
            end
        end

        function removeHandles(ax, hvec)
            % remove handles from all handle collections and from each
            % anchor that refers to it. Prunes anchors that become empty
            % after pruning.
            if isempty(hvec)
                return;
            end
            
            % remove from tag list
            mask = truevec(numel(ax.handleTagObjects));
            for iH = 1:numel(hvec)
                mask(hvec(iH) == ax.handleTagObjects) = false;
            end
            ax.handleTagObjects = ax.handleTagObjects(mask);
            ax.handleTagStrings = ax.handleTagStrings(mask);
            
            names = ax.listHandleCollections();
            
            % remove from all handle collections
            for i = 1:numel(names)
                ax.collections.(names{i}) = setdiff(ax.collections.(names{i}), hvec);
            end
            
            % remove from all anchors
            remove = false(numel(ax.anchorInfo), 1);
            for i = 1:numel(ax.anchorInfo)
                ai = ax.anchorInfo(i);
                if ai.isHandleH % char would be collection reference, ignore
                    ai.h = setdiff(ai.h, hvec);
                    if isempty(ai.h), remove(i) = true; end
                end
                if ai.isHandleHa % char would be collection reference, ignore
                    ai.ha = setdiff(ai.ha, hvec);
                    if isempty(ai.ha), remove(i) = true; end
                end
            end
            
            % filter the anchors for ones that still have some handles in
            % them
            ax.anchorInfo = ax.anchorInfo(~remove);
        end
    end
    
    methods(Static) % Static user-facing utilities
        function ax = replace(axh)
            % automatically replace title, axis labels, and ticks

            if nargin < 1
                axh = gca;
            end

            ax = AutoAxis(axh);
            axis(axh, 'off');
            ax.addAutoAxisX();
            ax.addAutoAxisY();
            ax.addTitle();
            ax.update();
            ax.installCallbacks();
        end
        
        function ax = replaceScaleBars(varargin)
            % automatically replace title, axis labels, and ticks

            p = inputParser();
            p.addOptional('axh', gca, @ishandle);
            p.addOptional('xUnits', '', @ischar);
            p.addOptional('yUnits', '', @ischar);
            p.addParameter('axes', 'xy', @ischar);
            p.parse(varargin{:});

            ax = AutoAxis(p.Results.axh);
            axis(p.Results.axh, 'off');
            ax.xUnits = p.Results.xUnits;
            ax.yUnits = p.Results.yUnits;
            if ismember('x', p.Results.axes)
                ax.addAutoScaleBarX();
            end
            if ismember('y', p.Results.axes)
                ax.addAutoScaleBarY();
            end
            ax.addTitle();
            ax.update();
            ax.installCallbacks();
        end
    end

    methods % Annotation configuration
        function reset(ax)
        	ax.removeAutoAxisX();
            ax.removeAutoAxisY();
            ax.removeAutoScaleBarX();
            ax.removeAutoScaleBarY();
            
            % delete all generated content
            if isfield(ax.collections, 'generated')
                generated = ax.collections.generated;
                ax.removeHandles(generated);
                delete(generated(isvalid(generated)));
            end
            
            % and update to prune anchors
            ax.update();
        end
        
        function clearX(ax)
            ax.removeAutoAxisX();
            ax.removeAutoScaleBarX();
            
            % delete all generated content
            if isfield(ax.collections, 'belowX')
                generated = ax.collections.belowX;
                ax.removeHandles(generated);
                delete(generated(isvalid(generated)));
            end
            
            ax.xlabel('');
            
            % and update to prune anchors
            ax.update();
        end
        
        function clearY(ax)
            ax.removeAutoAxisY();
            ax.removeAutoScaleBarY();
            
            % delete all generated content
            if isfield(ax.collections, 'leftY')
                generated = ax.collections.leftY;
                ax.removeHandles(generated);
                delete(generated(isvalid(generated)));
            end
            
            ax.ylabel('');
            
            % and update to prune anchors
            ax.update();
        end
        
        function addXLabelAnchoredToAxis(ax, xlabel, varargin)
            if nargin < 2
                xlabel = get(get(ax.axh, 'XLabel'), 'String');
            end
            ax.addXLabel(xlabel, varargin{:}, 'anchorToAxis', true);
        end
        
        function addXLabelAnchoredToDecorations(ax, xlabel, varargin)
            if nargin < 2
                xlabel = get(get(ax.axh, 'XLabel'), 'String');
            end
            ax.addXLabel(xlabel, varargin{:}, 'anchorToAxis', false);
        end
        
        function addXLabel(ax, varargin)
            % anchors and formats the existing x label
            
            p = inputParser();
            p.addOptional('xlabel', '', @ischar);
            p.addParameter('anchorToAxis', false, @islogical);
            p.parse(varargin{:});
            
            % remove any existing anchors with XLabel
            ax.removeHandles(get(ax.axh, 'XLabel'));
            
            if ~isempty(p.Results.xlabel)
                xlabel(ax.axh, p.Results.xlabel);
            end
            
            import AutoAxis.PositionType;
            
%             if ~isempty(ax.hXLabel)
%                 return;
%             end
            
            hlabel = get(ax.axh, 'XLabel');
            set(hlabel, 'Visible', 'on', ...
                'FontSize', ax.labelFontSize, ...
                'Margin', 0.1, ...
                'Color', ax.labelFontColor, ...
                'HorizontalAlign', 'center', ...
                'VerticalAlign', 'top');
            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end
            
            if p.Results.anchorToAxis
                % anchor directly below axis
                ai = AutoAxis.AnchorInfo(hlabel, PositionType.Top, ...
                    ax.axh, PositionType.Bottom, 'axisLabelOffsetBottom', ...
                    'xlabel below axis');
            else
                % anchor below the belowX objects
                ai = AutoAxis.AnchorInfo(hlabel, PositionType.Top, ...
                    'belowX', PositionType.Bottom, 'decorationLabelOffsetBottom', ...
                    'xlabel below belowX');
            end
            ax.addAnchor(ai);
            
            % and in the middle of the x axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.HCenter, ...
                ax.axh, PositionType.HCenter, 0, 'xLabel centered on x axis');
            ax.addAnchor(ai);
            ax.hXLabel = hlabel;
        end
        
        function xlabel(ax, varargin)
            if nargin == 2
                str = varargin{1};
            else
                str = sprintf(varargin{:});
            end
            xlabel(ax.axh, str);
        end
        
        function addYLabelAnchoredToAxis(ax, ylabel, varargin)
            if nargin < 2
                ylabel = get(get(ax.axh, 'YLabel'), 'String');
            end
            ax.addYLabel(ylabel, varargin{:}, 'anchorToAxis', true);
        end
        
        function addYLabelAnchoredToDecorations(ax, ylabel, varargin)
            if nargin < 2
                ylabel = get(get(ax.axh, 'YLabel'), 'String');
            end
            ax.addYLabel(ylabel, varargin{:}, 'anchorToAxis', false);
        end
        
        function addYLabel(ax, varargin)
            % anchors and formats the existing y label
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addOptional('ylabel', '', @ischar);
            p.addParameter('anchorToAxis', false, @islogical);
            p.parse(varargin{:});
            
            % remove any existing anchors with XLabel
            ax.removeHandles(get(ax.axh, 'YLabel'));
            
            if ~isempty(p.Results.ylabel)
                ylabel(ax.axh, p.Results.ylabel);
            end
            
            hlabel = get(ax.axh, 'YLabel');
            set(hlabel, 'Visible', 'on', ...
                'FontSize', ax.labelFontSize, ...
                'Rotation', 90, 'Margin', 0.1, 'Color', ax.labelFontColor, ...
                'HorizontalAlign', 'center', 'VerticalAlign', 'bottom');
            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end

            if p.Results.anchorToAxis
                % anchor directly left of axis
                ai = AutoAxis.AnchorInfo(hlabel, PositionType.Right, ...
                    ax.axh, PositionType.Left, 'axisLabelOffsetLeft', ...
                    'ylabel left of axis');
            else
                % anchor below the belowX objects
                ai = AutoAxis.AnchorInfo(hlabel, PositionType.Right, ...
                    'leftY', PositionType.Left, 'decorationLabelOffsetLeft', ...
                    'ylabel left of leftY');
            end
            
            ax.addAnchor(ai);
            
            % and in the middle of the y axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.VCenter, ...
                ax.axh, PositionType.VCenter, 0, 'yLabel centered on y axis');
            ax.addAnchor(ai);
            
            ax.hYLabel = hlabel;
        end
        
        function ylabel(ax, varargin)
            if nargin == 2
                str = varargin{1};
            else
                str = sprintf(varargin{:});
            end
            ylabel(ax.axh, str);
        end
        
        function addAutoAxisX(ax, varargin)
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisX)
                firstTime = false;
                
                % delete the old axes
                try delete(ax.autoAxisX.h); catch, end
                remove = ax.autoAxisX.h;
            else
                firstTime = true;
                remove = [];
            end
            
            hlist = ax.addTickBridge('x', ...
                'useAutoAxisCollections', true, ...
                'addAnchors', firstTime);
            ax.autoAxisX.h = hlist;
            
            % remove after the new ones are added by addTickBridge
            % so that anchors aren't deleted
            ax.removeHandles(remove);
            
            if firstTime
                ax.addXLabel();
            end
        end
        
        function removeAutoAxisX(ax, varargin)
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisX)
                % delete the old axes
                try delete(ax.autoAxisX.h); catch, end
                ax.removeHandles(ax.autoAxisX.h);
                ax.autoAxisX = [];
            end
        end
        
        function addAutoAxisY(ax, varargin)
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisY)
                firstTime = false;
                % delete the old objects
                try
                    delete(ax.autoAxisY.h);
                catch
                end
                
                % remove from handle collection
                remove = ax.autoAxisY.h;
            else
                firstTime = true;
                remove = [];
            end
            
            hlist = ax.addTickBridge('y', ...
                'useAutoAxisCollections', true, ...
                'addAnchors', firstTime);
            ax.autoAxisY.h = hlist;
            
            % remove after the new ones are added by addTickBridge
            % so that anchors aren't deleted
            ax.removeHandles(remove);
            
            if firstTime
                ax.addYLabel();
            end
        end
        
        function removeAutoAxisY(ax, varargin)
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisY)
                % delete the old axes
                try delete(ax.autoAxisY.h); catch, end
                ax.removeHandles(ax.autoAxisY.h);
                ax.autoAxisY = [];
            end
        end
        
        function addAutoScaleBarX(ax, varargin)
            % adds a scale bar to the x axis that will automatically update
            % its length to match the major tick interval along the x axis
            if ~isempty(ax.autoScaleBarX)
                firstTime = false;
                
                % delete the old objects
                try delete(ax.autoScaleBarX.h); catch, end
                
                % remove from handle collection
                remove = ax.autoScaleBarX.h;
            else
                firstTime = true;
                remove = [];
            end
            
            ax.autoScaleBarX.h = ax.addScaleBar('x', ...
                'units', ax.xUnits, ...
                'useAutoScaleBarCollection', true, 'addAnchors', firstTime);
            
            % remove after the new ones are added by addTickBridge
            % so that the existing anchors aren't deleted
            ax.removeHandles(remove);
        end
        
        function removeAutoScaleBarX(ax, varargin)
            if ~isempty(ax.autoScaleBarX)
                try delete(ax.autoScaleBarX.h); catch, end
                ax.removeHandles(ax.autoScaleBarX.h);
                ax.autoScaleBarX = [];
            end
        end
        
        function addAutoScaleBarY(ax, varargin)
            % adds a scale bar to the x axis that will automatically update
            % its length to match the major tick interval along the x axis
            if ~isempty(ax.autoScaleBarY)
                firstTime = false;
                
                % delete the old objects
                try
                    delete(ax.autoScaleBarY.h);
                catch
                end
                
                % remove from handle collection
                remove = ax.autoScaleBarY.h;
            else
                firstTime = true;
                remove = [];
            end
            
            ax.autoScaleBarY.h = ax.addScaleBar('y', 'units', ax.yUnits, ...
                'useAutoScaleBarCollections', true, 'addAnchors', firstTime);
            
            % remove after the new ones are added by addTickBridge
            % so that the existing anchors aren't deleted
            ax.removeHandles(remove);
        end
        
        function removeAutoScaleBarY(ax, varargin)
            if ~isempty(ax.autoScaleBarY)
                try delete(ax.autoScaleBarY.h); catch, end
                ax.removeHandles(ax.autoScaleBarY.h);
                ax.autoScaleBarY = [];
            end
        end
        
        function addTitle(ax, varargin)
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addOptional('title', '', @ischar);
            p.parse(varargin{:});
            
            if ~isempty(p.Results.title)
                title(ax.axh, p.Results.title);
            end
            
            hlabel = get(ax.axh, 'Title');
            set(hlabel, 'FontSize', ax.titleFontSize, 'Color', ax.titleFontColor, ...
                'Margin', 0.1, 'HorizontalAlign', 'center', ...
                'VerticalAlign', 'bottom');
            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end
            
            % anchor title vertically above axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.Bottom, ...
                ax.axh, PositionType.Top, ...
                'axisPaddingTop', 'Title above axis');
            ax.addAnchor(ai);
            
            % anchor title horizontally centered on axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.HCenter, ...
                ax.axh, PositionType.HCenter, ...
                0, 'Title centered on axis');
            ax.addAnchor(ai);
            
            ax.hTitle = hlabel;
        end
        
        function title(ax, varargin)
            if nargin == 2
                str = varargin{1};
            else
                str = sprintf(varargin{:});
            end
            title(ax.axh, str);
        end
        
        function addTicklessLabels(ax, varargin)
            % add labels to x or y axis where ticks would appear but
            % without the tick marks, i.e. positioned labels
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('tick', [], @isvector);
            p.addParameter('tickLabel', {}, @(x) isempty(x) || iscellstr(x));
            p.addParameter('tickAlignment', [], @(x) isempty(x) || iscellstr(x));
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh;
            useX = strcmp(p.Results.orientation, 'x');
            if ~isempty(p.Results.tick)
                ticks = p.Results.tick;
                labels = p.Results.tickLabel;
            else
                ticks = get(axh, 'XTick');
                labels = get(axh, 'XTickLabel');
                labels = strtrim(mat2cell(labels, ones(size(labels,1),1), size(labels, 2)));
            end
            
            if isempty(labels)
                labels = sprintfc('%g', ticks);
            end
            
            if isempty(p.Results.tickAlignment)
                if useX
                    tickAlignment = repmat({'center'}, numel(ticks), 1);
                else
                    tickAlignment = repmat({'middle'}, numel(ticks), 1);
                end
            else
                tickAlignment = p.Result.tickAlignment;
            end
            
            color = ax.tickColor;
            fontSize = ax.tickFontSize;
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                xtext = ticks;
                ytext = 0 * ticks;
                ha = tickAlignment;
                va = repmat({'top'}, numel(ticks), 1);
                offset = 'axisPaddingBottom';
                
            else
                % y axis labels
                xtext = 0* ticks;
                ytext = ticks;
                ha = repmat({'right'}, numel(ticks), 1);
                va = tickAlignment;
                offset = 'axisPaddingLeft';
            end
            
            ht = AutoAxis.allocateHandleVector(numel(ticks));
            for i = 1:numel(ticks)
                ht(i) = text(xtext(i), ytext(i), labels{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Interpreter', 'none', 'Parent', ax.axhDraw);
            end
            set(ht, 'Clipping', 'off', 'Margin', 0.1, 'FontSize', fontSize, ...
                    'Color', color);
                
            if ax.debug
                set(ht, 'EdgeColor', 'r');
            end
            
            % build anchor for labels to axis
            if useX
                ai = AnchorInfo(ht, PositionType.Top, ax.axh, ...
                    PositionType.Bottom, offset, 'xTicklessLabels below axis');
                ax.addAnchor(ai);
            else
                ai = AnchorInfo(ht, PositionType.Right, ...
                    ax.axh, PositionType.Left, offset, 'yTicklessLabels left of axis');
                ax.addAnchor(ai);
            end
            
            % add handles to handle collections
            ht = makecol(ht);
            if useX
                ax.addHandlesToCollection('belowX', ht);
            else
                ax.addHandlesToCollection('leftY', ht);
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', ht);
        end
        
        function [hlist] = addTickBridge(ax, varargin)
            % add line and text objects to the axis that replace the normal
            % axes
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('tick', [], @isvector);
            p.addParameter('tickLabel', {}, @(x) isempty(x) || iscellstr(x));
            p.addParameter('tickAlignment', [], @(x) isempty(x) || iscellstr(x));
            p.addParameter('tickRotation', 0, @isscalar);
            p.addParameter('useAutoAxisCollections', false, @islogical);
            p.addParameter('addAnchors', true, @islogical);
            
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROP>
            useX = strcmp(p.Results.orientation, 'x');
            if ~isempty(p.Results.tick)
                ticks = p.Results.tick;
                labels = p.Results.tickLabel;
            else
                if useX
                    ticks = get(axh, 'XTick');
                    labels = get(axh, 'XTickLabel');
                else
                    ticks = get(axh, 'YTick');
                    labels = get(axh, 'YTickLabel');
                end
                labels = strtrim(mat2cell(labels, ones(size(labels,1),1), size(labels, 2)));
            end
            
            if isempty(labels)
                labels = sprintfc('%g', ticks);
            end
            
            if isempty(p.Results.tickAlignment)
                if useX
                    tickAlignment = repmat({'center'}, numel(ticks), 1);
                else
                    tickAlignment = repmat({'middle'}, numel(ticks), 1);
                end
            else
                tickAlignment = p.Results.tickAlignment;
            end
            
%             tickLen = ax.tickLength;
            lineWidth = ax.tickLineWidth;
            tickRotation = p.Results.tickRotation;
            color = ax.tickColor;
            fontSize = ax.tickFontSize;
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                hi = 1;
                lo = 0;
                xvals = [makerow(ticks); makerow(ticks)];
                yvals = repmat([hi; lo], 1, numel(ticks));
                
                xbridge = [min(ticks); max(ticks)];
                ybridge = [hi; hi];
                
                xtext = ticks;
                ytext = repmat(lo, size(ticks));
                ha = tickAlignment;
                va = repmat({'top'}, numel(ticks), 1);
                offset = 'axisPaddingBottom';
                
            else
                % y axis ticks
                lo = 0;
                hi = 1;
                
                yvals = [makerow(ticks); makerow(ticks)];
                xvals = repmat([hi; lo], 1, numel(ticks));
                
                xbridge = [hi; hi];
                ybridge = [min(ticks); max(ticks)];
                
                xtext = repmat(lo, size(ticks));
                ytext = ticks;
                ha = repmat({'right'}, numel(ticks), 1);
                va = tickAlignment;
                offset = 'axisPaddingLeft';
            end
            
            % draw tick bridge
            hl = line(xvals, yvals, 'LineWidth', lineWidth, 'Color', color, 'Parent', ax.axhDraw);
            hb = line(xbridge, ybridge, 'LineWidth', lineWidth, 'Color', color, 'Parent', ax.axhDraw);
            
            AutoAxis.hideInLegend([hl; hb]);
            
            set([hl; hb], 'Clipping', 'off', 'YLimInclude', 'off', 'XLimInclude', 'off');
            
            % draw tick labels
            ht = AutoAxis.allocateHandleVector(numel(ticks));
            for i = 1:numel(ticks)
                ht(i) = text(xtext(i), ytext(i), labels{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Rotation', tickRotation, ...
                    'Parent', ax.axhDraw);
            end
            set(ht, 'Clipping', 'off', 'Margin', 0.1, 'FontSize', fontSize, ...
                    'Color', color);
                
            if ax.debug
                set(ht, 'EdgeColor', 'r');
            end
            
            if p.Results.useAutoAxisCollections
                if useX
                    ax.addHandlesToCollection('autoAxisXBridge', hb);
                    ax.addHandlesToCollection('autoAxisXTicks', ht);
                    ax.addHandlesToCollection('autoAxisXTickLabels', hl);
                    hbRef = 'autoAxisXBridge';
                    htRef = 'autoAxisXTicks';
                    hlRef = 'autoAxisXTickLabels';
                else
                    ax.addHandlesToCollection('autoAxisYBridge', hb);
                    ax.addHandlesToCollection('autoAxisYTicks', ht);
                    ax.addHandlesToCollection('autoAxisYTickLabels', hl);
                    hbRef = 'autoAxisYBridge';
                    htRef = 'autoAxisYTicks';
                    hlRef = 'autoAxisYTickLabels';
                end
            else
                hbRef = hb;
                htRef = ht;
                hlRef = hl;
            end
            
            % build anchor for lines
            if p.Results.addAnchors
                if useX
                    ai = AnchorInfo(hbRef, PositionType.Top, ax.axh, ...
                        PositionType.Bottom, offset, 'xTickBridge below axis');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hlRef, PositionType.Height, ...
                        [], 'tickLength', 0, 'xTick length');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hlRef, PositionType.Top, hbRef, ...
                        PositionType.Bottom, 0, 'xTick below xTickBridge');
                    ax.addAnchor(ai);
                    
                else
                    ai = AnchorInfo(hbRef, PositionType.Right, ...
                        ax.axh, PositionType.Left, offset, 'yTickBridge left of axis');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hlRef, PositionType.Width, ...
                        [], 'tickLength', 0, 'yTick length');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hlRef, PositionType.Right, ...
                        hbRef, PositionType.Left, 0, 'yTick left of yTickBridge');
                    ax.addAnchor(ai);
                end

                % anchor labels to lines
                if useX
                    ai = AnchorInfo(htRef, PositionType.Top, ...
                        hlRef, PositionType.Bottom, ax.tickLabelOffset, ...
                        'xTickLabels below ticks');
                    ax.addAnchor(ai);
                else
                    ai = AnchorInfo(htRef, PositionType.Right, ...
                        hlRef, PositionType.Left, ax.tickLabelOffset, ...
                        'yTickLabels left of ticks');
                    ax.addAnchor(ai);
                end
            end
            
            % add handles to handle collections
            hlist = cat(1, makecol(ht), makecol(hl), hb);
            if useX
                ax.addHandlesToCollection('belowX', hlist);
            else
                ax.addHandlesToCollection('leftY', hlist);
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
        end   
        
        function [hm, ht] = addMarkerX(ax, varargin)
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('x', @isscalar);
            p.addOptional('label', '', @ischar);
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('marker', 'o', @(x) isempty(x) || ischar(x));
            p.addParameter('markerColor', [0.1 0.1 0.1], @(x) isvector(x) || ischar(x) || isempty(x));
            p.addParameter('interval', [], @(x) isempty(x) || isvector(x)); % add a rectangle interval behind the marker to indicate a range of locations
            p.addParameter('intervalColor', [0.5 0.5 0.5], @(x) isvector(x) || ischar(x) || isempty(x));
            p.addParameter('textOffsetY', 0, @isscalar);
            p.addParameter('textOffsetX', 0, @isscalar);
            p.addParameter('horizontalAlignment', 'center', @ischar);
            p.addParameter('verticalAlignment', 'top', @ischar);
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            label = p.Results.label;
            
            yl = get(ax.axh, 'YLim');
            
            % add the interval rectangle if necessary, so that it sits
            % beneath the marker
            hr = [];
            hasInterval = false;
            if ~isempty(p.Results.interval)
                interval = p.Results.interval;
                assert(numel(interval) == 2, 'Interval must be a vector with length 2');
                
                if interval(2) - interval(1) > 0
                    hasInterval = true;
                    % set the height later
                    hr = rectangle('Position', [interval(1), yl(1), interval(2)-interval(1), 1], ...
                        'EdgeColor', 'none', 'FaceColor', p.Results.intervalColor, ...
                        'YLimInclude', 'off', 'XLimInclude', 'off', 'Clipping', 'off', 'Parent', ax.axhDraw);
                    AutoAxis.hideInLegend(hr);
                end
            end
            
            % plot marker
            hold(ax.axhDraw, 'on');
            hm = plot(ax.axhDraw, p.Results.x, yl(1), 'Marker', p.Results.marker, ...
                'MarkerSize', 1, 'MarkerFaceColor', p.Results.markerColor, ...
                'MarkerEdgeColor', 'none', 'YLimInclude', 'off', 'XLimInclude', 'off', ...
                'Clipping', 'off');
            AutoAxis.hideInLegend(hm);
            
            % marker label
            ht = text(p.Results.x, yl(1), p.Results.label, ...
                'FontSize', ax.tickFontSize, 'Color', p.Results.labelColor, ...
                'HorizontalAlignment', p.Results.horizontalAlignment, ...
                'VerticalAlignment', p.Results.verticalAlignment, ...
                'Parent', ax.axhDraw);
            set(ht, 'Clipping', 'off', 'Margin', 0.1);
            
            % anchor marker height
            ai = AutoAxis.AnchorInfo(hm, PositionType.MarkerDiameter, ...
                [], 'markerDiameter', 0, sprintf('markerX label ''%s'' height', label));
            ax.addAnchor(ai);
            
            % anchor marker to axis
            ai = AutoAxis.AnchorInfo(hm, PositionType.Top, ...
                ax.axh, PositionType.Bottom, 'axisPaddingBottom', ...
                sprintf('markerX ''%s'' to bottom of axis', label));
            ax.addAnchor(ai);
            
            % anchor label to bottom of axis factoring in marker size,
            % this makes it consistent with how addIntervalX's label is
            % anchored
            offY = p.Results.textOffsetY;
            pos = PositionType.verticalAlignmentToPositionType(p.Results.verticalAlignment);  
            ai = AutoAxis.AnchorInfo(ht, pos, ...
                ax.axh, PositionType.Bottom, @(ax, varargin) ax.axisPaddingBottom + ax.markerDiameter + ax.markerLabelOffset + offY, ...
                sprintf('markerX label ''%s'' to bottom of axis', label));
            ax.addAnchor(ai);
            
            % add lateral offset to label
            if p.Results.textOffsetX ~= 0
                pos = PositionType.horizontalAlignmentToPositionType(p.Results.horizontalAlignment);
                ai = AutoAxis.AnchorInfo(ht, pos, ...
                    p.Results.x, PositionType.Literal, p.Results.textOffsetX, ...
                    sprintf('markerX label ''%s'' offset %g from X=%g', ...
                    label, p.Results.textOffsetX, p.Results.x));
                ax.addAnchor(ai);
            end
                   
            % anchor error rectangle height and vcenter
            if hasInterval
                ai = AutoAxis.AnchorInfo(hr, PositionType.Height, ...
                    [], @(ax, info) ax.markerDiameter/3, 0, 'markerX interval rect height');
                ax.addAnchor(ai);
                ai = AutoAxis.AnchorInfo(hr, PositionType.VCenter, ...
                    hm, PositionType.VCenter, 0, 'markerX interval rect to marker');
                ax.addAnchor(ai);
            end
                        
            % add to belowX handle collection to update the dependent
            % anchors
            hlist = [hm; ht; hr];
            ax.addHandlesToCollection('belowX', hlist);
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('topLayer', hlist);
        end
        
        function ht = addLabelX(ax, varargin)
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('x', @isscalar);
            p.addRequired('label', @ischar);
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            label = p.Results.label;
            
            yl = get(ax.axh, 'YLim');
            
            ht = text(p.Results.x, yl(1), p.Results.label, ...
                'FontSize', ax.tickFontSize, 'Color', p.Results.labelColor, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                'Parent', ax.axhDraw);
            
            ai = AutoAxis.AnchorInfo(ht, PositionType.Top, ...
                ax.axh, PositionType.Bottom, 'axisPaddingBottom', ...
                sprintf('labelX ''%s'' to bottom of axis', label));
            ax.addAnchor(ai);
            
            % add to belowX handle collection to update the dependent
            % anchors
            ax.addHandlesToCollection('belowX', ht);
        end
        
        function hlist = addScaleBar(ax, varargin)
            % add rectangular scale bar with text label to either the x or
            % y axis, at the lower right corner
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('length', [], @isvector);
            p.addParameter('units', '', @(x) isempty(x) || ischar(x));
            p.addParameter('useAutoScaleBarCollections', false, @islogical);
            p.addParameter('addAnchors', true, @islogical);
            p.addParameter('color', ax.scaleBarColor, @(x) ischar(x) || isvector(x));
            p.addParameter('fontColor', ax.scaleBarFontColor, @(x) ischar(x) || isvector(x));
            p.addParameter('fontSize', ax.scaleBarFontSize, @(x) isscalar(x));
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROP>
            useX = strcmp(p.Results.orientation, 'x');
            if ~isempty(p.Results.length)
                len = p.Results.length;
            else
                if ax.keepAutoScaleBarsEqual && p.Results.useAutoScaleBarCollections
                    xticks = get(ax.axh, 'XTick');
                    yticks = get(ax.axh, 'YTick');
                    len = min([xticks(end) - xticks(end-1), yticks(end) - yticks(end-1)]);
                else
                    if useX
                        ticks = get(ax.axh, 'XTick');
                    else
                        ticks = get(ax.axh, 'YTick');
                    end
                    len = ticks(end) - ticks(end-1);
                end
            end
            units = p.Results.units;
            if isempty(units)
                if useX
                    units = ax.xUnits;
                else
                    units = ax.yUnits;
                end
            end
            if isempty(units)
                label = sprintf('%g', len);
            else
                label = sprintf('%g %s', len, units);
            end
           
            color = p.Results.color;
            fontColor = p.Results.fontColor;
            fontSize = p.Results.fontSize;
            % the two scale bars thicknesses must not be customized because
            % the placement of y depends on thickness of x and vice versa
            xl = get(axh, 'XLim');
            yl = get(axh, 'YLim');
            if useX
                hr = rectangle('Position', [xl(2) - len, yl(1), len, ax.scaleBarThickness], ...
                    'Parent', ax.axhDraw);
                AutoAxis.hideInLegend(hr);
                ht = text(xl(2), yl(1), label, 'HorizontalAlignment', 'right', ...
                    'VerticalAlignment', 'top', 'Parent', ax.axhDraw);
            else
                hr = rectangle('Position', [xl(2) - ax.scaleBarThickness, yl(1), ...
                    ax.scaleBarThickness, len], ...
                    'Parent', ax.axhDraw);
                AutoAxis.hideInLegend(hr);
                ht = text(xl(2), yl(1), label, 'HorizontalAlignment', 'right', ...
                    'VerticalAlignment', 'bottom', 'Parent', ax.axhDraw, ...
                    'Rotation', -90);
            end
            
            set(hr, 'FaceColor', color, 'EdgeColor', 'none', 'Clipping', 'off', ...
                'XLimInclude', 'off', 'YLimInclude', 'off');
            set(ht, 'FontSize', fontSize, 'Margin', 0.1, 'Color', fontColor, 'Clipping', 'off');
                
            if ax.debug
                set(ht, 'EdgeColor', 'r');
            end
            
            if p.Results.useAutoScaleBarCollections
                if useX
                    ax.addHandlesToCollection('autoScaleBarXRect', hr);
                    ax.addHandlesToCollection('autoScaleBarXText', ht);
                    hrRef = 'autoScaleBarXRect';
                    htRef = 'autoScaleBarXText';
                else
                    ax.addHandlesToCollection('autoScaleBarYRect', hr);
                    ax.addHandlesToCollection('autoScaleBarYText', ht);
                    hrRef = 'autoScaleBarYRect';
                    htRef = 'autoScaleBarYText';
                end
            else 
                hrRef = hr;
                htRef = ht;
            end
            
            % build anchor for rectangle and label
            if p.Results.addAnchors
                if useX
                    ai = AnchorInfo(hrRef, PositionType.Height, [], 'scaleBarThickness', ...
                        0, 'xScaleBar thickness');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hrRef, PositionType.Top, ax.axh, ...
                        PositionType.Bottom, 'axisPaddingBottom', ...
                        'xScaleBar at bottom of axis');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hrRef, PositionType.Right, ax.axh, ...
                        PositionType.Right, @(a, varargin) a.axisPaddingBottom + a.scaleBarThickness, ...
                        'xScaleBar flush with right edge of yScaleBar at right of axis');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(htRef, PositionType.Top, hrRef, PositionType.Bottom, 0, ...
                        'xScaleBarLabel below xScaleBar');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(htRef, PositionType.Right, hrRef, PositionType.Right, 0, ...
                        'xScaleBarLabel flush with left edge of xScaleBar');
                    ax.addAnchor(ai);
                else
                    ai = AnchorInfo(hrRef, PositionType.Width, [], 'scaleBarThickness', 0, ...
                        'yScaleBar thickness');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hrRef, PositionType.Left, ax.axh, ...
                        PositionType.Right, 'axisPaddingRight', ...
                        'yScaleBar at right of axis');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hrRef, PositionType.Bottom, ax.axh, ...
                        PositionType.Bottom, @(a, varargin) a.axisPaddingBottom + a.scaleBarThickness, ...
                        'yScaleBar flush with bottom of xScaleBar at bottom of axis');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(htRef, PositionType.Left, hrRef, PositionType.Right, 0, ...
                        'yScaleBarLabel right of yScaleBar');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(htRef, PositionType.Bottom, hrRef, PositionType.Bottom, 0, ...
                        'yScaleBarLabel bottom edge of xScaleBar');
                    ax.addAnchor(ai);
                end
            end
           
            % add handles to handle collections
            hlist = [hr; ht];
            if useX
                ax.addHandlesToCollection('belowX', hlist);
            else
                ax.addHandlesToCollection('hRightY', hlist);
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
        end
        
        function [hr, ht] = addIntervalX(ax, varargin)
            % add rectangular bar with text label to either the x or
            % y axis, at the lower right corner
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('interval', @(x) isvector(x) && numel(x) == 2);
            p.addOptional('label', '', @ischar);
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('color', [0.1 0.1 0.1], @(x) isvector(x) || ischar(x) || isempty(x));    
            p.addParameter('errorInterval', [], @(x) isempty(x) || (isvector(x) && numel(x) == 2)); % a background rectangle drawn to indicate error in the placement of the main interval
            p.addParameter('errorIntervalColor', [0.5 0.5 0.5], @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('leaveInPlace', false, @islogical); % if true, don't anchor overall position, only internal relationships
            p.addParameter('manualPos', 0, @isscalar); % when leaveInPlace is true, where to place overall top along y
            p.addParameter('textOffsetY', 0, @isscalar);
            p.addParameter('textOffsetX', 0, @isscalar);
            p.addParameter('horizontalAlignment', 'center', @ischar);
            p.addParameter('verticalAlignment', 'top', @ischar);
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROP>
            %leaveInPlace = p.Results.leaveInPlace;
            %manualPos = p.Results.manualPos;
            
            interval = p.Results.interval;
            color = p.Results.color;
            label = p.Results.label;
            errorInterval = p.Results.errorInterval;
            errorIntervalColor = p.Results.errorIntervalColor;
            fontSize = ax.tickFontSize;
            
            hr = [];
            ht = [];
            if interval(2) <= interval(1)
                warning('Skipping interval: endpoints must be monotonically increasing');
                return;
            end
            
            yl = get(axh, 'YLim');
            if ~isempty(errorInterval)
                if errorInterval(2) > errorInterval(1)
                    hre = rectangle('Position', [errorInterval(1), yl(1), ...
                        errorInterval(2)-errorInterval(1), 1], ...
                        'Parent', ax.axhDraw);
                    AutoAxis.hideInLegend(hre);
                    set(hre, 'FaceColor', errorIntervalColor, 'EdgeColor', 'none', ...
                        'Clipping', 'off', 'XLimInclude', 'off', 'YLimInclude', 'off');
                end
            else
                hre = [];
            end
           
            hri = rectangle('Position', [interval(1), yl(1), interval(2)-interval(1), 1], ...
                'Parent', ax.axhDraw);
            AutoAxis.hideInLegend(hri);
            
            hr = [hri; hre];
            ht = text(mean(interval), yl(1), label, 'HorizontalAlignment', p.Results.horizontalAlignment, ...
                'VerticalAlignment', p.Results.verticalAlignment, 'Parent', ax.axhDraw);
            set(ht, 'FontSize', fontSize, 'Margin', 0.1, 'Color', p.Results.labelColor);
            
            set(hri, 'FaceColor', color, 'EdgeColor', 'none', 'Clipping', 'off', ...
                'XLimInclude', 'off', 'YLimInclude', 'off');
           
            if ax.debug
                set(ht, 'EdgeColor', 'r');
            end
            
            % build anchor for rectangle and label
            ai = AnchorInfo(hri, PositionType.Height, [], 'intervalThickness', 0, ...
                sprintf('interval ''%s'' thickness', label));
            ax.addAnchor(ai);
            
            % we'd like the VCenters of the markers (height = markerDiameter)
            % to match the VCenters of the intervals (height =
            % intervalThickness). Marker tops sit at axisPaddingBottom from the
            % bottom of the axis. Note that this assumes markerDiameter >
            % intervalThickness.
            ai = AnchorInfo(hri, PositionType.VCenter, ax.axh, ...
                PositionType.Bottom, @(ax,varargin) ax.axisPaddingBottom + ax.markerDiameter/2, ...
                sprintf('interval ''%s'' below axis', label));
            ax.addAnchor(ai);

            % add custom or default y offset from bottom of rectangle
            textOffsetY = p.Results.textOffsetY;
            pos = PositionType.verticalAlignmentToPositionType(p.Results.verticalAlignment);
            ai = AnchorInfo(ht, pos, ...
                ax.axh, PositionType.Bottom, @(ax, varargin) ax.axisPaddingBottom + ax.markerDiameter + ax.markerLabelOffset + textOffsetY, ...
                sprintf('interval label ''%s'' below axis', label));
            ax.addAnchor(ai);
  
            % add x offset in paper units to label 
            if p.Results.textOffsetX ~= 0
                pos = PositionType.horizontalAlignmentToPositionType(p.Results.horizontalAlignment);
                ai = AutoAxis.AnchorInfo(ht, pos, ...
                    p.Results.x, PositionType.Literal, p.Results.textOffsetX, ...
                    sprintf('interval label ''%s'' offset %g from X=%g', ...
                    label, p.Results.textOffsetX, p.Results.x));
                ax.addAnchor(ai);
            end

            if ~isempty(hre)
                % we use marker diameter here to make all error intervals
                % the same height
                ai = AnchorInfo(hre, PositionType.Height, [], @(ax,varargin) ax.markerDiameter/3, 0, ...
                    sprintf('interval ''%s'' error thickness', label));
                ax.addAnchor(ai);
                ai = AnchorInfo(hre, PositionType.VCenter, hri, PositionType.VCenter, 0, ...
                    sprintf('interval ''%s'' error centered in interval', label));
                ax.addAnchor(ai);
            end  
           
            % add handles to handle collections
            hlist = [hr; ht];
            ax.addHandlesToCollection('belowX', hlist);
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('topLayer', hlist);
        end
        
        function [hl, ht] = addLabeledSpan(ax, varargin)
            % add line and text objects to the axis that replace the normal
            % axes. 'span' is 2 x N matrix
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('span', [], @ismatrix); % 2 X N matrix of [ start; stop ] limits
            p.addParameter('label', {}, @(x) isempty(x) || ischar(x) || iscell(x));
            p.addParameter('color', {}, @(x) ischar(x) || iscell(x) || ismatrix(x));
            p.addParameter('leaveInPlace', false, @islogical);
            p.addParameter('manualPos', 0, @isscalar); % position to place along non-orientation axis, when leaveInPlace is true
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            useX = strcmp(p.Results.orientation, 'x');
            span = p.Results.span;
            label = p.Results.label;
            fontSize = ax.tickFontSize;
            lineWidth = ax.tickLineWidth;
            color = p.Results.color;
            leaveInPlace = p.Results.leaveInPlace;
            manualPos = p.Results.manualPos;
            
            % check sizes
            nSpan = size(span, 2);
            assert(size(span, 1) == 2, 'span must be 2 x N matrix of limits');
            if ischar(label)
                label = {label};
            end
            assert(numel(label) == nSpan, 'numel(label) must match size(span, 2)');
            
            if ischar(color)
                color = {color};
            end
            if isscalar(color) && nSpan > 1
                color = repmat(color, nSpan, 1);
            end
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                % x axis lines
                xvals = [span(1, :); span(2, :)];
                yvals = ones(size(xvals)) * manualPos;
                xtext = mean(span, 1);
                ytext = zeros(size(xtext));
                ha = repmat({'center'}, size(xtext));
                va = repmat({'top'}, size(xtext));
                offset = 'axisPaddingBottom';
                
            else
                % y axis lines
                yvals = [span(1, :); span(2, :)];
                xvals = ones(size(yvals)) * manualPos;
                ytext = mean(span, 1);
                xtext = zeros(size(ytext));
                ha = repmat({'right'}, size(xtext));
                va = repmat({'middle'}, size(xtext));
                offset = 'axisPaddingLeft';
            end
            
            hl = line(xvals, yvals, 'LineWidth', lineWidth, 'Parent', ax.axhDraw);
            for i = 1:nSpan
                if iscell(color)
                    set(hl(i), 'Color', color{i});
                else
                    set(hl(i), 'Color', color(i, :));
                end
            end
            AutoAxis.hideInLegend(hl);
            set(hl, 'Clipping', 'off', 'YLimInclude', 'off', 'XLimInclude', 'off');
            ht = AutoAxis.allocateHandleVector(nSpan);
            for i = 1:nSpan
                ht(i) = text(xtext(i), ytext(i), label{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Parent', ax.axhDraw);
                if iscell(color)
                    set(ht(i), 'Color', color{i});
                else
                    set(ht(i), 'Color', color(i, :));
                end
            end
            set(ht, 'Clipping', 'off', 'Margin', 0.1, 'FontSize', fontSize);
                
            if ax.debug
                
                set(ht, 'EdgeColor', 'r');
            end
            
            if ~leaveInPlace
                % build anchor for lines
                if useX
                    ai = AnchorInfo(hl, PositionType.Top, ax.axh, ...
                        PositionType.Bottom, offset, 'xLabeledSpan below axis');
                    ax.addAnchor(ai);
                else
                    ai = AnchorInfo(hl, PositionType.Right, ...
                        ax.axh, PositionType.Left, offset, 'yLabeledSpan left of axis');
                    ax.addAnchor(ai);
                end
            end

            % anchor labels to lines (always)
            if useX
                ai = AnchorInfo(ht, PositionType.Top, ...
                    hl, PositionType.Bottom, 'tickLabelOffset', ...
                    'xLabeledSpan below ticks');
                ax.addAnchor(ai);
            else
                ai = AnchorInfo(ht, PositionType.Right, ...
                    hl, PositionType.Left, 'tickLabelOffset', ...
                    'yLabeledSpan left of ticks');
                ax.addAnchor(ai);
            end
            
            ht = makecol(ht);
            hl = makecol(hl);
            hlist = [hl; ht];
            if ~leaveInPlace
                % add handles to handle collections
                if useX
                    ax.addHandlesToCollection('belowX', hlist);
                else
                    ax.addHandlesToCollection('leftY', hlist);
                end
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('topLayer', hlist);
        end 
        
        function addColoredLabels(ax, labels, colors, varargin)
            import AutoAxis.PositionType;
            import AutoAxis.AnchorInfo;
            
            p = inputParser();
            p.addParameter('posX', PositionType.Right, @(x) isa(x, 'AutoAxis.PositionType'));
            p.addParameter('posY', PositionType.Top, @(x) isa(x, 'AutoAxis.PositionType'));
            p.addParameter('fontSize', ax.labelFontSize, @isscalar);
            p.addParameter('spacing', 'tickLabelOffset', @(x) true);
            p.parse(varargin{:});
            posX = p.Results.posX;
            posY = p.Results.posY;
            
            N = numel(labels);
            
            if nargin < 3 || isempty(colors)
                colors = get(ax.axh, 'ColorOrder');
            end
            
            hvec = AutoAxis.allocateHandleVector(N);
            
            if strcmp(get(gca, 'YDir'), 'reverse')
                rev = true;
            else
                rev = false;
            end
            
            top = posY == PositionType.Top;
            if top
                root = 1;
                anchorToOffset = -1;
            else
                root = N;
                anchorToOffset = 1;
            end  
            
            for i = 1:N
                label = labels{i};
                if iscell(colors)
                    c = colors{i};
                else
                    c = colors(i, :);
                end
 
                hvec(i) = text(0, (~rev * -i), label, 'FontSize', p.Results.fontSize, ...
                    'Color', c, 'HorizontalAlignment', posX.toHorizontalAlignment(), ...
                    'VerticalAlignment', posY.flip().toVerticalAlignment());
            end
            
            % put in top layer
            ax.addHandlesToCollection('topLayer', hvec);
            
            for i = 1:N
                if i == root
                    % anchor to axis
                    ai = AnchorInfo(hvec(i), posY, ax.axh, posY, 0, ...
                        sprintf('colorLabel %s %s to axis %s', labels{i}, char(posY), char(posY)));
                else
                    % anchor to text above/below
                    ai = AnchorInfo(hvec(i), posY, hvec(i+anchorToOffset), posY.flip(), p.Results.spacing, ...
                        sprintf('colorLabel %s %s to %s %s', labels{i}, char(posY), labels{i+anchorToOffset}, char(posY.flip())));
                end
                ax.addAnchor(ai);
            end
            
            ai = AnchorInfo(hvec, posX, ax.axh, posX, 0, ...
                sprintf('colorLabels to axis %s', char(posX), char(posX)));
            ax.addAnchor(ai);
            
            % list as generated content
            ax.addHandlesToCollection('generated', hvec);
        end
    end
    
    methods
        function addAnchor(ax, info)
            ind = numel(ax.anchorInfo) + 1;
            % sort here so that we can use ismembc later
            if info.isHandleH
                info.h = sort(info.h);
                ax.tagHandle(info.h);
            end
            if info.isHandleHa
                info.ha = sort(info.ha);
                ax.tagHandle(info.ha);
            end
            ax.anchorInfo(ind) = info;
            
            % force an update of the dependency graph and reordering of the
            % anchors
            ax.refreshNeeded = true;
           
        end
        
        function update(ax)
            if ~ishandle(ax.axh)
                %ax.uninstall();
                return;
            end
            
            % complete the reconfiguration process after loading
            if ax.requiresReconfigure
                ax.reconfigurePostLoad();
            end
                    
            %disp('autoaxis.update!');
            axis(ax.axh, 'off');
            if ax.usingOverlay
                axis(ax.axhDraw, 'off');
                set(ax.axhDraw, 'Color', 'none');
            end
            
            % update constants converting pixels to paper units
            ax.updateAxisScaling();
            
            if ax.usingOverlay
                % reposition and set limits on overlay axis
                ax.updateOverlayAxisPositioning();
            end
            
            if ax.refreshNeeded
                % re-order .anchorInfo so that dependencies are correctly resolved
                % i.e. order the anchors so that no anchor preceeds anchors
                % it depends upon.
                ax.prioritizeAnchorOrder();
                ax.refreshNeeded = false;
            end
            
            % recreate the auto axes and scale bars if installed
            if ~isempty(ax.autoAxisX)
                ax.addAutoAxisX();
            end
            if ~isempty(ax.autoAxisY)
                ax.addAutoAxisY();
            end
            if ~isempty(ax.autoScaleBarX)
                ax.addAutoScaleBarX();
            end
            if ~isempty(ax.autoScaleBarY)
                ax.addAutoScaleBarY();
            end
            
            % restore the X and Y label handles and make them visible since
            % they have a tendency to get hidden (presumably by axis off)
            if ~isempty(ax.hXLabel)
                ax.hXLabel = get(ax.axh, 'XLabel');
                set(ax.hXLabel, 'Visible', 'on');
            end
            if ~isempty(ax.hYLabel)
                ax.hYLabel = get(ax.axh, 'YLabel');
                set(ax.hYLabel, 'Visible', 'on');
            end

            if ~isempty(ax.anchorInfo)                
                % dereference all anchors into .anchorInfoDeref
                % i.e. replace collection names with handle vectors
                ax.derefAnchors();
                
                % query the locations of each handle and put them into the
                % handle to LocationInfo map
                ax.updateLocationCurrentMap();
            
                % process all dereferenced anchors in order
                for i = 1:numel(ax.anchorInfoDeref)
                    if i == 14
                        a = 1;
                    end
                    ax.processAnchor(ax.anchorInfoDeref(i));
                end
                
                % filter out invalid anchors
                valid = [ax.anchorInfoDeref.valid];
                ax.anchorInfo = ax.anchorInfo(valid);
            end
            
            ax.updateAxisStackingOrder();
            
            % cache the current limits for checking for changes in
            % callbacks
            ax.lastXLim = get(ax.axh, 'XLim');
            ax.lastYLim = get(ax.axh, 'YLim');
           
        end
        
        function updateAxisStackingOrder(ax)
            % update the visual stacking order for annotations that are
            % added to ensure visual consistency
            
            % put 'topLayer' markers and intervals at the top
            hvec = ax.getHandlesInCollection('topLayer');
            if ~isempty(hvec)
                hvec = hvec(isvalid(hvec));
                uistack(hvec, 'top');
            end
        end
        
        function updateOverlayAxisPositioning(ax)
            % we want overlay axis to fill the figure,
            % but want the portion overlaying the axis to have the same
            % "limits" as the real axis
            if ax.usingOverlay
                set(ax.axhDraw, 'Position', [0 0 1 1], 'HitTest', 'off', 'Color', 'none'); 
                set(ax.axhDraw, 'YDir', get(ax.axh, 'YDir'), 'XDir', get(ax.axh, 'XDir'));
                axUnits = get(ax.axh, 'Units');
                set(ax.axh, 'Units', 'normalized');
                pos = get(ax.axh, 'Position');

                % convert normalized coordinates of [ 0 0 1 1 ]
                % into what they would be in expanding the
                % limits in data coordinates of axh to fill the figure
                lims = axis(ax.axh);
                normToDataX = @(n) (n - pos(1))/pos(3) * (lims(2) - lims(1)) + lims(1);
                normToDataY = @(n) (n - pos(2))/pos(4) * (lims(4) - lims(3)) + lims(3);
                limsDraw = [ normToDataX(0) normToDataX(1) normToDataY(0) normToDataY(1) ];
                axis(ax.axhDraw, limsDraw);
                
                uistack(ax.axhDraw, 'top');

                set(ax.axh, 'Units', axUnits);
            end
        end

        function updateAxisScaling(ax)
            % set x/yDataToUnits scaling from data to paper units
            axh = ax.axh;
            axUnits = get(axh, 'Units');

            set(axh,'Units','centimeters');
            set(axh, 'LooseInset', ax.axisMargin);
            
            axlim = axis(axh);
            axwidth = diff(axlim(1:2));
            axheight = diff(axlim(3:4));
            axpos = get(axh,'Position');
            ax.xDataToUnits = axpos(3)/axwidth;
            ax.yDataToUnits = axpos(4)/axheight;
            
            % get data to points conversion
            set(axh,'Units','points');
            axpos = get(axh,'Position');
            ax.xDataToPoints = axpos(3)/axwidth;
            ax.yDataToPoints = axpos(4)/axheight;
            
            % get data to pixels conversion
            set(axh,'Units','pixels');
            axpos = get(axh,'Position');
            ax.xDataToPixels = axpos(3)/axwidth;
            ax.yDataToPixels = axpos(4)/axheight;
            
            ax.xReverse = strcmp(get(axh, 'XDir'), 'reverse');
            ax.yReverse = strcmp(get(axh, 'YDir'), 'reverse');
            
            set(axh, 'Units', axUnits);
        end
        
        function derefAnchors(ax)
            % go through .anchorInfo, dereference all referenced handle
            % collections and property values, and store in
            % .anchorInfoDeref
            
            ax.anchorInfoDeref = ax.anchorInfo.copy();
            
            for i = 1:numel(ax.anchorInfoDeref)
                info = ax.anchorInfoDeref(i);
                
                % lookup h as handle collection
                if ischar(info.h)
                    info.h = sort(ax.getHandlesInCollection(info.h));
                end
                
                % lookup ha as handle collection
                if ischar(info.ha)
                    info.ha = sort(ax.getHandlesInCollection(info.ha));
                end
                
                % lookup margin as property value or function handle
                if ischar(info.margin)
                    info.margin = ax.(info.margin);
                elseif isa(info.margin, 'function_handle')
                    info.margin = info.margin(ax, info);
                end
                
                % look property or eval fn() for .pos or .posa
                if ischar(info.pos)
                    info.pos = ax.(info.pos);
                elseif isa(info.pos, 'function_handle')
                    info.pos = info.pos(ax, info);
                end
                
                if ischar(info.posa)
                    info.posa = ax.(info.posa);
                elseif isa(info.posa, 'function_handle')
                    info.posa = info.posa(ax, info);
                end
            end
        end

        function updateLocationCurrentMap(ax)
            % update .mapLocationCurrent (handle --> LocationCurrent)
            % to remove unused handles and add new ones
            
            maskH = [ax.anchorInfoDeref.isHandleH];
            maskHa = [ax.anchorInfoDeref.isHandleHa];
            hvec = unique(cat(1, ax.anchorInfoDeref(maskHa).ha, ax.anchorInfoDeref(maskH).h));
            
            % remove handles no longer needed
            [ax.mapLocationHandles, idxKeep] = intersect(ax.mapLocationHandles, hvec);
            ax.mapLocationCurrent = ax.mapLocationCurrent(idxKeep);
            
            % update handles which are considered "dynamic" whose position
            % changes unknowingly between calls to update()
            locCell = ax.mapLocationCurrent;
            for iH = 1:numel(locCell)
                if locCell{iH}.isDynamic
                    locCell{iH}.queryPosition(ax.xDataToPoints, ax.yDataToPoints, ...
                        ax.xReverse, ax.yReverse);
                end
            end
            
            % and build a LocationCurrent for missing handles
            missing = setdiff(hvec, ax.mapLocationHandles);
            for iH = 1:numel(missing)
                ax.setLocationCurrent(missing(iH), ...
                    AutoAxis.LocationCurrent.buildForHandle(missing(iH), ...
                    ax.xDataToPoints, ax.yDataToPoints, ax.xReverse, ax.yReverse));
            end
        end
        
        function setLocationCurrent(ax, h, loc)
            [tf, idx] = ismember(h, ax.mapLocationHandles);
            if tf
                ax.mapLocationCurrent{idx} = loc;
            else
                idx = numel(ax.mapLocationHandles) + 1;
                ax.mapLocationHandles(idx) = h;
                ax.mapLocationCurrent{idx} = loc;
            end
        end
        
        function loc = getLocationCurrent(ax, h)
            [tf, idx] = ismember(h, ax.mapLocationHandles);
            if ~tf
                loc = AutoAxis.LocationCurrent.empty();
            else
                loc = ax.mapLocationCurrent{idx};
            end
        end
                 
        function valid = processAnchor(ax, info)
            import AutoAxis.PositionType;
            
            if isempty(info.h) || ~all(ishandle(info.h)) || ...
                (info.isHandleHa && ~all(ishandle(info.ha)))
                info.valid = false;
                valid = false;
                
                if ax.debug
                    warning('Invalid anchor %s encountered', info.desc);
                end
                return;
            end
            
            if isempty(info.ha)
                % this anchor specifies a height or width in raw paper units
                % convert the scalar value from paper to data units
                pAnchor = info.posa;
                if info.pos.isX
                    pAnchor = pAnchor / ax.xDataToUnits;
                else
                    pAnchor = pAnchor / ax.yDataToUnits;
                end
            elseif info.posa == PositionType.Literal
                % ha is a literal value in data coordinates
                pAnchor = info.ha;
            else
                % get the position of the anchoring element
                pAnchor = ax.getCurrentPositionData(info.ha, info.posa);
            end

            % add margin to anchor in the correct direction if possible
            if ~isempty(info.ha) && ~isempty(info.margin) && ~isnan(info.margin)
                offset = 0;
                
                if info.posa == PositionType.Top
                    offset = info.margin / ax.yDataToUnits;
                elseif info.posa == PositionType.Bottom
                    offset = -info.margin / ax.yDataToUnits;
                elseif info.posa == PositionType.Left
                    offset = -info.margin / ax.xDataToUnits;
                elseif info.posa == PositionType.Right
                    offset = info.margin / ax.xDataToUnits;
                elseif info.posa == PositionType.Literal && info.pos.isX()
                    offset = info.margin / ax.xDataToUnits;
                elseif info.posa == PositionType.Literal && info.pos.isY()
                    offset = info.margin / ax.yDataToUnits;
                end
                
                if (info.pos.isY() && ax.yReverse) || (info.pos.isX() && ax.xReverse)
                    offset = -offset;
                end
                
                pAnchor = pAnchor + offset;
            end
            
            % and actually set the position of the data
            % this will also create / update the position information
            % in the LocationCurrent for that object
            ax.updatePositionData(info.h, info.pos, pAnchor);
            
            valid = true;
        end
        
        function prioritizeAnchorOrder(ax)
            % re-order .anchorInfo so that they can be processed in order, 
            % such that later anchors are dependent only on the positions
            % of objects positioned by earlier (and thus already processed)
            % anchors
            
            import AutoAxis.PositionType;
            
            ax.derefAnchors();
            
            % first loop through and build a list of dependencies,
            % building the adjacency matrix of a directed acyclic graph
            nAnchors = numel(ax.anchorInfo);
            dependencyMat = false(nAnchors, nAnchors); % does anchor i depend on anchor j
            for i = 1:nAnchors
                anchor = ax.anchorInfoDeref(i);
                
                if ~anchor.isHandleH
                    continue; % must specify a literal since it's already dereferenced
                end
                
                if anchor.isHandleHa
                    % add dependencies on any anchor that determines the
                    % corresponding position (posa) of this anchor's anchor
                    % object (ha)
                    dependencyMat(i, :) = ax.findAnchorsSpecifying(anchor.ha, anchor.posa);
                end
                
                % if this anchor sets the position of h, add dependencies
                % on any anchors which affect the size of this object so
                % that sizing happens before positioning
                if ~anchor.pos.specifiesSize()
                    if anchor.pos.isX()
                        dependencyMat(i, :) = dependencyMat(i, :) | ax.findAnchorsSpecifying(anchor.h, PositionType.Width);
                    else
                        dependencyMat(i, :) = dependencyMat(i, :) | ax.findAnchorsSpecifying(anchor.h, PositionType.Height);
                    end
                end

                % add dependencies on anchors such that MarkerDiameter is
                % always specified before size or position
                if anchor.pos ~= PositionType.MarkerDiameter
                    dependencyMat(i, :) = dependencyMat(i, :) | ax.findAnchorsSpecifying(anchor.h, PositionType.MarkerDiameter);
                end
            end
            
            % then sort the DAG in topographic order
            issuedWarning = false;
            sortedIdx = nan(nAnchors, 1);
            active = true(nAnchors, 1);
            iter = 1;
            while any(active)
                % find an anchor which has no dependencies
                depCount = sum(dependencyMat, 2);
                idxNoDep = find(depCount == 0 & active, 1, 'first');
                if isempty(idxNoDep)
                    if ~issuedWarning
                        warning('AutoAxis:AcyclicDependencies', 'AutoAxis anchor dependency graph is cyclic, anchors may be successfully implemented');
                        issuedWarning = true;
                    end
                    
                    depCount(~active) = Inf;
                    [~, idxNoDep] = min(depCount);
                end
                
                sortedIdx(iter) = idxNoDep;
                
                iter = iter + 1;
                
                % remove dependencies on this anchor
                dependencyMat(:, idxNoDep) = false;
                active(idxNoDep) = false;
            end
            
            % reorder the anchors to resolve dependencies
            ax.anchorInfo = ax.anchorInfo(sortedIdx);
        end
        
        function mask = findAnchorsSpecifying(ax, hVec, posType)
            % returns a list of AnchorInfo which could specify position posa of object h
            % this includes 
            import AutoAxis.PositionType;
            
            % first find any anchors that specify any subset of the handles in
            % hVec
            
            % not using strings anymore since we do this all on
            % dereferenced anchors
            
%             if ischar(hVec)
%                 maskH = cellfun(@(v) isequal(hVec, v), {ax.anchorInfoDeref.h});
%             else
                maskH = arrayfun(@(info) info.isHandleH && any(ismember(hVec, info.h)), ax.anchorInfoDeref);
%             end
            
            if ~any(maskH)
                mask = maskH;
                return;
            end
            
            % then search for any directly or indirectly specifying anchors
            info = ax.anchorInfoDeref(maskH); % | maskExact);

            maskTop = [info.pos] == PositionType.Top;
            maskBottom = [info.pos] == PositionType.Bottom;
            maskVCenter = [info.pos] == PositionType.VCenter;
            maskLeft = [info.pos] == PositionType.Left;
            maskRight = [info.pos] == PositionType.Right;
            maskHCenter = [info.pos] == PositionType.HCenter;
            maskHeight = [info.pos] == PositionType.Height; 
            maskWidth = [info.pos] == PositionType.Width;

            % directly specified anchors
            maskDirect = [info.pos] == posType;

            % placeholder for implicit "combination" specifying anchors,
            % e.g. height and/or bottom specifying the top position
            maskImplicit = false(size(info));

            switch posType
                case PositionType.Top
                    if sum([any(maskBottom) any(maskHeight) any(maskVCenter)]) >= 1 % specifying any of these will affect the top
                        maskImplicit = maskBottom | maskHeight | maskVCenter; 
                    end

                case PositionType.Bottom
                    if sum([any(maskTop) any(maskHeight) any(maskVCenter)]) >= 1
                        maskImplicit = maskTop | maskHeight | maskVCenter; 
                    end

                case PositionType.Height
                    if sum([any(maskTop) any(maskBottom) any(maskVCenter)]) >= 2 % specifying any 2 of these will dictate the height, specifying only one will keep the height as is
                        maskImplicit = maskTop | maskBottom | maskVCenter;
                    end

                case PositionType.VCenter
                    if sum([any(maskTop) any(maskBottom) any(maskHeight)]) >= 1
                        maskImplicit = maskTop | maskBottom | maskHeight;
                    end

                case PositionType.Left
                    if sum([any(maskRight) any(maskWidth) any(maskHCenter)]) >= 1
                        maskImplicit = maskRight | maskWidth | maskHCenter;
                    end

                case PositionType.Right
                    if sum([any(maskLeft) any(maskWidth) any(maskHCenter)]) >= 1
                        maskImplicit = maskLeft | maskWidth | maskHCenter; 
                    end

                case PositionType.Width
                    if sum([any(maskLeft) && any(maskRight) any(maskHCenter)]) >= 2
                        maskImplicit = maskLeft | maskRight | maskHCenter;
                    end

                case PositionType.HCenter
                    if sum([any(maskLeft) && any(maskRight) any(maskWidth)]) >= 1
                        maskImplicit = maskLeft | maskRight | maskWidth;
                    end
            end
            
            %info = info(maskDirect | maskImplicit);
            idx = find(maskH);
            idx = idx(maskDirect | maskImplicit);
            mask = false(size(maskH));
            mask(idx) = true;
        end
        
        function pos = getCurrentPositionData(ax, hvec, posType)
            % grab the specified position / size value for object h, in figure units
            % when hvec is a vector of handles, uses the outer bounding
            % box for the objects instead
            
            import AutoAxis.PositionType;
            import AutoAxis.LocationCurrent;
            
            if isempty(hvec)
                % pass thru for specifying length or width directly
                pos = posa;
                return;
            end
            
            % grab all current values from LocationCurrent for each handle
            clocVec = arrayfun(@(h) ax.getLocationCurrent(h), hvec, 'UniformOutput', false);
            clocVec = cat(1, clocVec{:});

            % and compute aggregate value across all handles
            pos = LocationCurrent.getAggregateValue(clocVec, posType, ax.xReverse, ax.yReverse);
        end
        
        function updatePositionData(ax, hVec, posType, value)
            % update the position of handles in vector hVec using the LocationCurrent in 
            % ax.locMap. When hVec is a vector of handles, linearly shifts
            % each object to maintain the relative positions and to
            % shift the bounding box of the objects
            
            import AutoAxis.*;
            
            if ~isscalar(hVec)
                % here we linearly scale / translate the bounding box
                % in order to maintain internal anchoring, scaling should
                % be done before any "internal" anchorings are computed,
                % which should be taken care of by findAnchorsSpecifying
                %
                % note that this will recursively call updatePositionData, so that
                % the corresponding LocationCurrent objects will be updated
                
                if posType == PositionType.Height
                    % scale everything vertically, but keep existing
                    % vcenter (of bounding box) in place
                    
                    % first find the existing extrema of the objects
                    oldTop = ax.getCurrentPositionData(hVec, PositionType.Top);
                    oldBottom = ax.getCurrentPositionData(hVec, PositionType.Bottom);
                    newBottom = (oldTop+oldBottom) / 2 - value/2;
                    
                    % build affine scaling fns for inner objects
                    newPosFn = @(p) (p-oldBottom) * (value / (oldTop-oldBottom)) + newBottom;
                    newHeightFn = @(h) h * (value / (oldTop-oldBottom));
                    
                    % loop over each object and shift its position by offset
                    for i = 1:numel(hVec)
                       h = hVec(i);
                       t = ax.getCurrentPositionData(h, PositionType.Top);
                       he = ax.getCurrentPositionData(h, PositionType.Height);
                       ax.updatePositionData(h, PositionType.Height, newHeightFn(he));
                       ax.updatePositionData(h, PositionType.Top, newPosFn(t));
                    end
                
                elseif posType == PositionType.Width
                    % scale everything horizontally, but keep existing
                    % hcenter (of bounding box) in place if anchored
                    
                    % first find the existing extrema of the objects
                    oldRight = ax.getCurrentPositionData(hVec, PositionType.Right);
                    oldLeft = ax.getCurrentPositionData(hVec, PositionType.Left);
 
                    newLeft = (oldRight+oldLeft) / 2 - value/2;
                    
                    % build affine scaling fns
                    newPosFn = @(p) (p-oldLeft) * (value / (oldRight-oldLeft)) + newLeft;
                    newWidthFn = @(w) w * value / (oldRight-oldLeft);
                    
                    % loop over each object and shift its position by offset
                    for i = 1:numel(hVec)
                       h = hVec(i);
                       l = ax.getCurrentPositionData(h, PositionType.Left);
                       w = ax.getCurrentPositionData(h, PositionType.Width);
                       ax.updatePositionData(h, PositionType.Width, newWidthFn(w));
                       ax.updatePositionData(h, PositionType.Left, newPosFn(l));
                    end
                    
                else
                    % simply shift each object by the same offset, thereby shifting the bounding box 
                    offset = value - ax.getCurrentPositionData(hVec,  posType);
                    for i = 1:numel(hVec)
                       h = hVec(i);
                       p = ax.getCurrentPositionData(h, posType);
                       ax.updatePositionData(h, posType, p + offset);
                    end
                end

            else
                % scalar handle, move it directly via the LocationCurrent
                % handle 
                h = hVec(1);
                
                % use the corresponding LocationCurrent for this single
                % object to move the graphics object
                cloc = ax.getLocationCurrent(h);
                cloc.setPosition(posType, value, ...
                    ax.xDataToPoints, ax.yDataToPoints, ax.xReverse, ax.yReverse);
            end
        end
    end
end
