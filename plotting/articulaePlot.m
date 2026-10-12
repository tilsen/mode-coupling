classdef articulaePlot
% ARTICULAEPLOT  Plots over an articulae inventory.
%
%   articulaePlot(A).plotPhoneGestureMap()
%   A.plotPhoneGestureMap()           % the usual route
%
%   Extracted from articulae, which keeps only a thin delegation so the
%   inventory code can be read and run without the graphics code.

    properties
        Model articulae     % the inventory being drawn
    end

    methods
        function p = articulaePlot(model)
            if nargin > 0, p.Model = model; end
        end

        function [m] = plotPhoneGestureMap(p,opts)
            arguments
                p
                opts.?plotopts.PhoneGestureMap
            end
            opts = plotopts.Base.resolve(opts,plotopts.PhoneGestureMap());

            obj = p.Model;

            opts.Parent = plotParent.axes(opts.Parent,@()stFig(1,[0.05 0.02 0.01 0.20]));

            % color each gesture (column) by its Class; cells with no
            % mapping are left NaN so stMatrixPlot draws them via
            % nanColor (set to white below) instead of a colormap value
            classOrder = articulae.ClassLevels;              % ["C";"V";"G";"N";"L";"R"], code == row index
            cmap = cell2mat(arrayfun(@(c)opts.ClassColors.(char(c)),classOrder,'UniformOutput',false));

            codes = obj.Gestures.ClassCode(:)';              % 1 x nGestures
            codes(isnan(codes)) = 0;
            plotData = double(obj.Map).*codes;
            plotData(~obj.Map) = nan;

            m = stMatrixPlot(plotData,XLabels=obj.Gestures.Name,YLabels=obj.Phones.Name,Parent=opts.Parent);
            m.Colormap = cmap;
            m.CLims = [0.5 numel(classOrder)+0.5];
            m.SymmetrizeCLims = false;
            m.nanColor = [1 1 1];
            m = m.plot(showText=false);
            opts.Parent.XTickLabelRotation = 90;

            if opts.ShowKey
                p.drawKey(opts.Parent,classOrder,cmap,plotData,opts.KeyFontSize);
            end

        end

        function drawKey(~,ax,classOrder,cmap,plotData,fontSize)
            % One swatch and label per class that appears in the matrix,
            % in the lower right, where the vowel columns leave it empty.
            names = dictionary(["V" "C" "N" "G" "L" "R"], ...
                ["V-class: vocalic" "C-class: oral/consonantal" "N-class: nasal" ...
                 "G-class: glottal" "L-class: laryngeal" "R-class: rounding"]);
            codes = unique(plotData(~isnan(plotData)))';
            [~,order] = ismember(["V" "C" "N" "G" "R" "L"],string(classOrder));
            order = order(ismember(order,codes));
            if isempty(order), return; end

            % bottom edge and the direction "up the page" in data units
            if ax.YDir=="reverse", yb = ax.YLim(2)-0.5; up = -1;
            else, yb = ax.YLim(1)+0.5; up = 1; end
            xr = ax.XLim(2)-0.5;                            % key's right edge
            w = 20;  dy = 1.9;  pad = 0.6;                  % widths in columns, heights in rows
            n = numel(order);
            patch(ax,xr-[w w 0 0],yb+up*[0 n*dy+2*pad n*dy+2*pad 0], ...
                [1 1 1],'EdgeColor',[0 0 0],'LineWidth',0.5,'Clipping','off');
            for k = 1:n
                y = yb + up*(pad + (n-k)*dy + dy/2);        % first class at the top
                code = order(k);
                patch(ax,xr-w+0.8+[0 3 3 0],y+0.6*[-1 -1 1 1],cmap(code,:), ...
                    'EdgeColor',[0 0 0],'LineWidth',0.5);
                text(ax,xr-w+4.4,y,names(string(classOrder(code))), ...
                    'FontSize',fontSize,'VerticalAlignment','middle', ...
                    'HorizontalAlignment','left','Interpreter','none');
            end
        end
    end

end
