classdef stMatrixPlot

    properties
        Data
        Text = []
        X
        Y
        imHandle = []
        gridHandles = {}
        textHandles = []
        XLabelHandles = []
        YLabelHandles = []
        fontSize = 16
        gridColor = [0 0 0];
        XLabels = []
        YLabels = []
        XLabelLoc = 'top'
        YLabelLoc = 'left'
        XDir = []
        YDir = []
        Colormap = []
        CLims = []
        SymmetrizeCLims = true
        Parent = []
        nanColor = [0.5 0.5 0.5] 
        showText = true
    end

    methods
        function obj = stMatrixPlot(data,opts)
            arguments
                data
                opts.Text = []                
                opts.Colormap = []
                opts.gridColor = []
                opts.XLabels = []
                opts.YLabels = []
                opts.fontSize = []
                opts.CLims = []
                opts.SymmetrizeCLims = []
                opts.Parent = []
                opts.XDir = []
                opts.YDir = []
            end
            obj.Data = data;
            obj.X = 1:size(data,2);
            obj.Y = 1:size(data,1);
            obj = handleObjectContructorInputs(obj,opts);
        end

        function obj = plot(obj,opts)
            arguments
                obj
                opts.Parent = [];
                opts.FormatStr = '%1.2f'
                opts.showText = true
                opts.HideValues = []
                opts.useAxisLabels = true
            end
            opts = handleMethodInputs(obj,opts);
            if isempty(opts.Parent)
                fig = get(groot, 'CurrentFigure');
                hasAxes = ~isempty(fig) && ~isempty(get(fig, 'CurrentAxes'));
                if hasAxes
                    opts.Parent = gca;
                else
                    opts.Parent = axes('Position',[0.1 0.01 0.01 0.15]);
                end
            end
            obj.Parent = opts.Parent;
            axes(opts.Parent);
            obj.imHandle = imagesc(obj.Data); hold(opts.Parent,'on');

            if ~isempty(obj.nanColor) && any(isnan(obj.Data(:)))
                [r,c] = find(isnan(obj.Data));
                for i=1:numel(r)
                    fill(c(i)+[-1 -1 1 1]*0.5,r(i)+[-1 1 1 -1]*0.5,obj.nanColor,'EdgeColor','none');
                end
            end

            if ~isempty(obj.Colormap), set(opts.Parent,'Colormap',obj.Colormap); end
            if isempty(obj.CLims)
                obj.CLims = [min(obj.Data(:)), max(obj.Data(:))];
            end
            if obj.SymmetrizeCLims
                if ~isscalar(unique(sign(obj.CLims)))
                    obj.CLims = [-1 1]*max(abs(obj.CLims));
                end
            end
            if isscalar(unique(obj.CLims))
                obj.CLims = obj.CLims(1)+[0 1];
            end
            set(opts.Parent,'CLim',obj.CLims);
            axis(opts.Parent,'tight');
            obj = obj.drawGrid(Color=obj.gridColor,LineWidth=0.5);
            if opts.showText
                obj = obj.drawText(FormatStr=opts.FormatStr,HideValues=opts.HideValues);
            end
            set(opts.Parent,'TickLen',[0 0]);

            opts.Parent.XTick = 1:numel(obj.XLabels);
            opts.Parent.YTick = 1:numel(obj.YLabels);            
            opts.Parent.XTickLabel = obj.XLabels;
            opts.Parent.YTickLabel = obj.YLabels;
            opts.Parent.XAxisLocation = obj.XLabelLoc;
            opts.Parent.YAxisLocation = obj.YLabelLoc;
            if ~isempty(obj.XDir), opts.Parent.XDir = obj.XDir; end
            if ~isempty(obj.YDir), opts.Parent.YDir = obj.YDir; end

            if ~opts.useAxisLabels
                switch(obj.XLabelLoc)
                    case 'top'
                        yoff = obj.Parent.YLim(1); verti = 'bot'; hori = 'c';
                    case 'bottom'
                        yoff = obj.Parent.YLim(2); verti = 'top'; hori = 'c';
                end
                switch(obj.YLabelLoc)
                    case 'left'
                        xoff = obj.Parent.XLim(1); verti = 'mid'; hori = 'right';
                    case 'right'
                        xoff = obj.Parent.XLim(2); verti = 'mid'; hori = 'left';
                end

                for i=1:numel(opts.Parent.XTickLabel)
                    obj.XLabelHandles(i) = text(opts.Parent.XTick(i),yoff,opts.Parent.XTickLabel(i),'verti',verti,'hori',hori);
                end                
                for i=1:numel(opts.Parent.YTickLabel)
                    obj.YLabelHandles(i) = text(xoff,opts.Parent.YTick(i),opts.Parent.YTickLabel(i),'Hori',hori,'verti',verti);
                end
                opts.Parent.XTickLabel = [];
                opts.Parent.YTickLabel = [];
            end

        end

        function obj = drawGrid(obj,opts)
            arguments
                obj
                opts.Color = [1 1 1]
                opts.LineWidth = 0.5
            end

            h={};            
            if all(xlim==ylim)
                ix = min(xlim):max(xlim);
                h{1} = line(repmat(xlim,length(ix),1)',repmat(ix,2,1));
                h{2} = line(repmat(ix,2,1),repmat(ylim,length(ix),1)');                
            else
                ixx = min(xlim):max(xlim);
                ixy = min(ylim):max(ylim);
                h{1} = line(repmat(xlim,length(ixy),1)',repmat(ixy,2,1));
                h{2} = line(repmat(ixx,2,1),repmat(ylim,length(ixx),1)');
            end
            set(vertcat(h{:}),'LineWidth',opts.LineWidth,'Color',opts.Color);
            obj.gridHandles{1} = h(:,1);
            obj.gridHandles{2} = h(:,2);
        end

        function obj = drawText(obj,opts)
            arguments
                obj
                opts.FontSize = get(0,'defaultaxesFontSize');                
                opts.FontWeight = 'normal'
                opts.InversionThreshold = 0.66
                opts.FormatStr = '%1.2f'
                opts.Diagonal = true
                opts.HideValues = []
            end

            if ~isempty(obj.Text)
                str = obj.Text;
            elseif isscalar(string(opts.FormatStr))
                str = arrayfun(@(c)string(sprintf(opts.FormatStr,c)),obj.Data);
            else
                % One format per column, e.g. so columns spanning very
                % different magnitudes aren't all rounded to the same
                % number of decimals.
                fmts = string(opts.FormatStr);
                str = strings(size(obj.Data));
                for c = 1:size(obj.Data,2)
                    str(:,c) = arrayfun(@(v)string(sprintf(fmts(c),v)),obj.Data(:,c));
                end
            end

            if ~isempty(obj.fontSize)
                opts.FontSize = obj.fontSize;
            end

            colors = repmat(reshape([0 0 0],1,1,3),size(str,1),size(str,2),1);
            
            luminance = @(color)sum([0.299 0.587 0.1140].*color);
            clims = get(obj.imHandle.Parent,'CLim');
            cmap = colormap(obj.imHandle.Parent);
            cixvals = linspace(clims(1),clims(2),size(cmap,1));
            cmap_luminances = arrayfun(@(c)luminance(cmap(c,:)),(1:size(cmap,1))');


            for a=1:size(obj.Data,1)
                for b=1:size(obj.Data,2)
                    ix = find(cixvals>=obj.imHandle.CData(a,b),1,'first');
                    if isempty(ix), ix = length(cixvals); end
                    dataCmapIxs(a,b) = ix;
                    dataLuminances(a,b) = luminance(cmap(dataCmapIxs(a,b),:));
                end
            end

            invert = dataLuminances<opts.InversionThreshold;

            % if cmap_luminances(end)<cmap_luminances(1)
            %     invert = ~invert;
            % end
            % 
            invert = repmat(invert,1,1,3);
            colors(invert) = 1-colors(invert);

            th = gobjects(size(obj.Data));
            for r = 1:size(obj.Data,1)
                for c=1:size(obj.Data,2)
                    if ~isempty(obj.nanColor) && isnan(obj.Data(r,c))
                        th(r,c) = text(obj.X(c),obj.Y(r),"",...
                            'hori','center', ...
                            'verti','mid', ...
                            'color',obj.nanColor, ...
                            'fontsize',opts.FontSize, ...
                            'fontweight',opts.FontWeight);
                    else

                        th(r,c) = text(obj.X(c),obj.Y(r),str(r,c),...
                            'hori','center', ...
                            'verti','mid', ...
                            'color',colors(r,c,:), ...
                            'fontsize',opts.FontSize, ...
                            'fontweight',opts.FontWeight);
                    end
                end
            end

            if ~opts.Diagonal
                set(th(logical(eye(size(th)))),'Visible','off');
            end
            if ~isempty(opts.HideValues)
                ixHide = ismember(obj.Data,opts.HideValues);
                set(th(ixHide),'Visible','off');
            end

            obj.textHandles = th;
        end
    end
end