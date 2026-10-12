classdef plotParent
    % Resolve plot destinations without creating figures during lookup.
    methods (Static)
        function parent = target(parent)
            if isa(parent,'stFig'), parent = parent.Handle; end
            if isempty(parent)
                parent = get(groot,'CurrentFigure');
                if isempty(parent), return; end
                ax = get(parent,'CurrentAxes');
                if ~isempty(ax) && isgraphics(ax,'axes'), parent = ax; end
            end
            if ~(all(isgraphics(parent,'axes')) || ...
                    (isscalar(parent) && isgraphics(parent,'figure')))
                error('plotParent:InvalidParent','Parent must be live axes or a figure.');
            end
        end

        function ax = axes(parent,factory)
            parent = plotParent.target(parent);
            if isempty(parent)
                if nargin < 2
                    fig = stFig(1);
                else
                    fig = factory();
                end
                ax = fig.Axes(1);
            elseif isgraphics(parent,'figure')
                ax = parent.CurrentAxes;
                if isempty(ax) || ~isgraphics(ax,'axes')
                    ax = axes('Parent',parent);
                end
            else
                ax = parent;
            end
            if ~isscalar(ax)
                error('plotParent:SingleAxes','This plot requires one axes.');
            end
        end

        function fig = layout(parent,varargin)
            parent = plotParent.target(parent);
            fig = stFig(varargin{:},Parent=parent);
        end
    end
end
