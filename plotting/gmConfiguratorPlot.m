classdef gmConfiguratorPlot < handle
% GMCONFIGPLOT  Plotting and interaction for a gmConfigurator.
%
%   p = gmConfiguratorPlot(cfg);
%   p.plotFinal();
%   p.inspect(startIter);
%   p.plotIters(1:5);
%
%   Handle class: the figure, axes and control handles built by inspect()
%   persist on the object between calls, so callbacks can reach them.

    properties
        Configurator gmConfigurator
        Fig                         % stFig the current view is drawn into
        Ax          = struct()      % named axes handles (see setupAxes)
        IterText    = gobjects(0)   % clickable iteration list
        Controls    = struct()      % uicontrol handles
        AltConfigs                  % alternatives shown for the current iteration
        MaxAlt                      % how many alternatives actually fit (see setupAxes)
        GridRows                    % rows in the energy-matrix grid
        ConfigPlots = struct()
        EnergyPlots = struct()
        Opts        = struct()      % options of the current inspect() call
    end

    methods

        function p = gmConfiguratorPlot(configurator)
            if nargin > 0
                p.Configurator = configurator;
            end
        end

        % ----------------------------------------------------------------
        function cPlot = plotFinal(p,opts)
            arguments
                p
                opts.?plotopts.Configuration
            end

            args = namedargs2cell(opts);
            cPlot = p.Configurator.IterConfigs(end).plot(args{:});

            if cPlot.Interactive
                clickThroughAxes(cPlot.configAxes,'on');
                cPlot.configAxes.ButtonDownFcn = @(~,~)p.inspect();
            end

            p.ConfigPlots.final = cPlot;
        end

        % ----------------------------------------------------------------
        function h = inspect(p,startIter,opts)
            arguments
                p
                startIter = 1;
                opts.?plotopts.Inspector
            end
            opts = plotopts.Base.resolve(opts,plotopts.Inspector());

            cfg = p.Configurator;

            h = struct('fig',[],'altConfigs',[],'configPlots',[], ...
                       'iterEnergyPlot',[],'altEnergyPlots',[]);

            if isempty(startIter), startIter = 1; end
            startIter = min(startIter,numel(cfg.IterConfigs)-1);

            p.Opts = opts;

            p.setupAxes();   % also resolves MaxAlt and energiesFontSize
            p.drawIterList();

            p.Fig.labelAxes([p.Ax.current p.Ax.next],p.iterLabel(startIter+(0:1)));
            fontsizeObjDim(p.Fig.AxesLabels,1,"x",parent=p.Ax.current);

            firstPlot = true;
            iter      = startIter;

            while iter <= numel(cfg.IterConfigs)-1
                p.highlightIter(iter);
                drawnow;

                p.drawConfigs(iter);
                p.renderEnergies(iter);

                if firstPlot
                    pos0 = plotboxpos(p.Ax.current);
                    shiftposx([p.Ax.current p.Ax.next],-(pos0(1)-p.Ax.current.Position(1)));
                    firstPlot = false;
                end

                if ~opts.interactive
                    h.fig            = p.Fig;
                    h.altConfigs     = p.AltConfigs;
                    h.configPlots    = p.ConfigPlots;
                    h.iterEnergyPlot = p.EnergyPlots.iter;
                    h.altEnergyPlots = p.EnergyPlots.alt;
                    return;
                end

                if ~isfield(p.Controls,'nextIter'), p.createControls(); end

                nextStep = p.handleUI(iter);
                if isempty(nextStep) || ~ishandle(p.Fig.Handle), return; end

                iter = max(iter+nextStep,1);
            end
        end

        % ----------------------------------------------------------------
        function configPlots = plotIters(p,plotIters,opts)
            arguments
                p
                plotIters = []
                opts.?plotopts.Iterations
            end
            opts = plotopts.Base.resolve(opts,plotopts.Iterations());

            cfg = p.Configurator;

            if isempty(plotIters)
                plotIters = 1:numel(cfg.IterConfigs)-1;
            end

            if isempty(opts.NumRows)
                opts.NumRows = ceil(numel(plotIters)/opts.autoMaxCols);
            end
            if isempty(plotIters), configPlots = []; return; end
            if opts.NumRows==1
                layout = 1:numel(plotIters);
            else
                nExtra = mod(-numel(plotIters),opts.NumRows);
                layout = reshape([1:numel(plotIters) nan(1,nExtra)],[],opts.NumRows)';
            end
            fig = plotParent.layout(opts.Parent,layout,[0.01 0.03 0.01 0.07],opts.intMargins);
            ax = fig.Axes;

            plots      = cell(1,numel(plotIters));
            for i = 1:numel(plotIters)
                configOpts = plotopts.Base.select(opts,plotopts.Configuration());
                configOpts.Parent = ax(i);
                configOpts.LabelPrefix = string(plotIters(i)) + ": " + string(opts.LabelPrefix);
                args = namedargs2cell(configOpts);
                plots{i} = cfg.IterConfigs(plotIters(i)).plot(args{:});
            end
            if isempty(plots)
                configPlots = [];
                return;
            end
            configPlots = [plots{:}];

            for i = 1:numel(configPlots)
                configPlots(i).realignUncoupled();
                if isempty(opts.ModeLabelHeightRatio) && isempty(opts.ModeLabelFontSize)
                    fontsizeObjDim(configPlots(i).Modes.LabelHandle,0.05,'xy',parent=ax(i));
                end
            end

            % Each panel's fitSystemLabels() grows its own axes just enough
            % to fit its own labels, so panels end up at different zoom
            % levels. Re-center every panel on its own content, then widen
            % all of them to the largest range needed by any one panel, so
            % every axes box renders at the same size.
            configAxes  = [configPlots.configAxes];
            maxXRange   = max(arrayfun(@(a)diff(a.XLim),configAxes));
            maxYRange   = max(arrayfun(@(a)diff(a.YLim),configAxes));
            for i = 1:numel(configAxes)
                xMid = mean(configAxes(i).XLim);
                yMid = mean(configAxes(i).YLim);
                configAxes(i).XLim = xMid + [-1 1]*maxXRange/2;
                configAxes(i).YLim = yMid + [-1 1]*maxYRange/2;
            end

            configPlots.finalizeLayout(FitLimits=false);

            p.Fig = fig;
            p.ConfigPlots.iters = configPlots;
        end

    end


    methods
        function e = drawEnergies(p,iter,opts)
            % Resolve a public plot destination; inspector redraws use renderEnergies.
            arguments
                p
                iter (1,1) double {mustBeInteger,mustBePositive}
                opts.?plotopts.EnergyPanels
            end
            opts = plotopts.Base.resolve(opts,plotopts.EnergyPanels());
            if iter >= numel(p.Configurator.IterConfigs)
                error('gmConfiguratorPlot:InvalidIteration', ...
                    'Choose an iteration with a following configuration.');
            end
            fig = plotParent.layout(opts.Parent,1);
            panelIx = 1;
            p.Opts = opts;
            nRows = height(p.Configurator.IterConfigs(iter).Modes);
            [layout,p.GridRows] = p.energyLayout(fig,panelIx,nRows);
            nEnergy = max(layout(:),[],'omitnan');
            fig.subAxes(panelIx,layout, ...
                intMargins=[opts.energyColGap*(opts.energyCols>1) opts.energyRowGap]);
            ax.energy = fig.Axes(panelIx:panelIx+nEnergy-1);
            ax.iterEnergy = ax.energy(1);
            ax.altEnergy = ax.energy(2:end);
            ax.baseColor = ax.altEnergy(1).YColor;
            ax.baseLineWidth = ax.altEnergy(1).LineWidth;
            ax.altLabelIx = ((2:opts.energyCols)-1)*(p.GridRows-1)+1;
            set(ax.energy,'XTick',[],'YTick',[]);
            shiftposy(ax.iterEnergy,0.015);
            p.Fig = fig;
            p.Ax = ax;
            p.MaxAlt = min(numel(ax.altEnergy),opts.maxAlt);
            if isempty(p.Opts.energiesFontSize)
                p.Opts.energiesFontSize = p.rowFontSize(fig);
            end
            if ~isempty(opts.ColumnLabelFontSize)
                p.Opts.ColumnLabelFontSize = opts.ColumnLabelFontSize;
            end
            p.renderEnergies(iter);
            e = p.EnergyPlots;
        end

    end

    methods (Access = private)

        % --- figure / axes layout ----------------------------------------
        function setupAxes(p)
            opts = p.Opts;

            switch opts.showIterations
                case true
                    axpan = [1 1 2 2 4 4 4; 1 1 3 3 4 4 4];
                case false
                    axpan = [1 1 3 3 3; 2 2 3 3 3];
            end

            nRows = height(p.Configurator.FinalConfig.Modes);

            % Unlike the other plot methods, inspect() is a standalone
            % dashboard: it must never land on whatever figure happens to
            % be current, so only an explicit parent is passed through
            % plotParent.layout's reuse-current-figure fallback.
            if isempty(opts.parent)
                fig = stFig(axpan,[0.025 0.05 0.05 0.1],[0.05 0.10], ...
                            'Name','Configurator iterations');
            else
                fig = plotParent.layout(opts.parent,axpan,[0.025 0.05 0.05 0.1],[0.05 0.10], ...
                            'Name','Configurator iterations');
            end
            % grid of energy matrices: rows sized so that a matrix row is
            % always opts.rowHeight of the figure, columns as requested
            [layout,nGridRows] = p.energyLayout(fig,numel(fig.Axes),nRows);
            xMargin = opts.energyColGap*(opts.energyCols > 1);
            fig.subAxes(numel(fig.Axes),layout,intMargins=[xMargin opts.energyRowGap]);
            p.GridRows = nGridRows;

            c = max(axpan(:));

            ax.current    = fig.Axes(c-2);
            ax.next       = fig.Axes(c-1);
            ax.iterEnergy = fig.Axes(c);
            ax.altEnergy  = fig.Axes(c+1:end);
            ax.energy     = fig.Axes(c:end);

            if opts.showIterations
                ax.iterList = fig.Axes(1);
            else
                ax.iterList = gobjects(0);
            end

            % baseline styling captured before anything highlights an axis
            ax.baseColor     = get(ax.altEnergy(1),'YColor');
            ax.baseLineWidth = get(ax.altEnergy(1),'LineWidth');

            set(ax.energy,'XTick',[],'YTick',[]);
            shiftposy(ax.iterEnergy,0.015);

            % top axes of columns 2..n keep their x tick labels: nothing sits
            % above them, and they are the only reference for the right column
            ax.altLabelIx = [];
            if ~isempty(p.GridRows) && opts.energyCols > 1
                nPerCol = p.GridRows-1;             % alt rows per column
                ax.altLabelIx = ((2:opts.energyCols)-1)*nPerCol + 1;
            end

            p.Fig    = fig;
            p.Ax     = ax;
            p.MaxAlt = min(numel(ax.altEnergy),opts.maxAlt);

            if isempty(p.Opts.energiesFontSize)
                p.Opts.energiesFontSize = p.rowFontSize(fig);
            end
        end

        % --- the clickable list of iterations -----------------------------
        function drawIterList(p)
            if isempty(p.Ax.iterList)
                p.IterText = gobjects(0);
                return;
            end

            cfg  = p.Configurator;
            n    = numel(cfg.IterConfigs);
            ypos = linspace(1,0,n+1);
            th   = gobjects(n,1);

            for iter = 1:n
                th(iter) = text(0,ypos(iter), ...
                    string(iter) + ": " + cfg.IterConfigs(iter).ToLabels(), ...
                    Parent=p.Ax.iterList);
                th(iter).UserData = iter;
            end

            set(p.Ax.iterList,'Visible','off');
            maxIterFontSize = p.Opts.maxIterFontSize;
            if isempty(maxIterFontSize), maxIterFontSize = Inf; end
            fontsizeObjDim(th,[1 1/n],"xy",parent=p.Ax.iterList, ...
                maxFontSize=maxIterFontSize);
            set(th,'BackgroundColor',p.Fig.Handle.Color);

            p.IterText = th;
        end

        function highlightIter(p,iter)
            if isempty(p.IterText), return; end
            set(p.IterText,'EdgeColor','none');
            % Same selected-color/linewidth convention as the alt-energy
            % highlight in renderEnergies; plain white was invisible
            % against the near-white default figure background.
            set(p.IterText(iter),'EdgeColor',p.Opts.selectedColor, ...
                'LineWidth',p.Opts.selectedLineWidth);
        end

        % --- current + selected-next configuration -------------------------
        function drawConfigs(p,iter)
            cfg = p.Configurator;
            ax  = p.Ax;

            cla([ax.current; ax.next]);

            current = cfg.IterConfigs(iter).plot(Parent=ax.current,ShowPanelLabel=false);
            next    = cfg.IterConfigs(iter+1).plot(Parent=ax.next,ShowPanelLabel=false);
            current.setMargins([0.1 0.1]);
            next.setMargins([0.1 0.1]);
            current.finalizeLayout();
            next.finalizeLayout();

            p.Fig.AxesLabels(1).String = p.iterLabel(iter);
            p.Fig.AxesLabels(2).String = p.iterLabel(iter+1);

            ax.current.ButtonDownFcn = @(~,~)disp(cfg.IterConfigs(iter).Systems);
            ax.next.ButtonDownFcn    = @(~,~)disp(cfg.IterConfigs(iter+1).Systems);

            p.ConfigPlots.current = current;
            p.ConfigPlots.next    = next;
        end

        % --- energies of the current config and its alternatives -----------
        function renderEnergies(p,iter)
            cfg  = p.Configurator;
            ax   = p.Ax;
            opts = p.Opts;

            cla(ax.energy);

            altConfigs = gmConfigurator.getAltConfigs(cfg.IterConfigs(iter));
            for j = 1:numel(altConfigs)
                altConfigs(j) = altConfigs(j).calcEnergies();
            end

            altE       = arrayfun(@(c)c.Energies.totalE,altConfigs);
            [~,srtix]  = sort(altE);
            altConfigs = altConfigs(srtix);

            e.iter = cfg.IterConfigs(iter).plotEnergy( ...
                        Parent=ax.iterEnergy,FontSize=opts.energiesFontSize, ...
                        ColumnLabelFontSize=opts.ColumnLabelFontSize, ...
                        RowHeight=opts.rowHeight);

            nAlt     = min(numel(altConfigs),p.MaxAlt);
            altPlots = cell(1,nAlt);
            for j = 1:nAlt
                altPlots{j} = altConfigs(j).plotEnergy( ...
                                Parent=ax.altEnergy(j),FontSize=opts.energiesFontSize, ...
                        ColumnLabelFontSize=opts.ColumnLabelFontSize, ...
                                RowHeight=opts.rowHeight);
            end
            if nAlt > 0
                e.alt = [altPlots{:}];
            else
                e.alt = [];
            end

            set(ax.altEnergy(1:nAlt),'Visible','on');
            noLabels = setdiff(1:nAlt,ax.altLabelIx);
            set(ax.altEnergy(noLabels),'XTickLabel',[]);
            for j = noLabels
                set(e.alt(j).columnLabels,'Visible','off');
            end
            set(ax.altEnergy(nAlt+1:end),'Visible','off');

            % reset, then mark whichever alternative was actually taken
            set(ax.altEnergy,'LineWidth',ax.baseLineWidth, ...
                'YColor',ax.baseColor,'XColor',ax.baseColor);

            ixSelected = arrayfun(@(c)c.ToString,altConfigs(1:nAlt)) == ...
                         cfg.IterConfigs(iter+1).ToString;
            set(ax.altEnergy(ixSelected),'LineWidth',opts.selectedLineWidth, ...
                'YColor',opts.selectedColor,'XColor',opts.selectedColor);

            % say so when the figure can't hold every alternative
            if nAlt < numel(altConfigs)
                p.Fig.Handle.Name = sprintf( ...
                    'Configurator iterations - showing %d of %d alternatives', ...
                    nAlt,numel(altConfigs));
            else
                p.Fig.Handle.Name = 'Configurator iterations';
            end

            p.AltConfigs  = altConfigs;
            p.EnergyPlots = e;
        end

        % --- controls and interaction loop ---------------------------------
        function createControls(p)
            fig = p.Fig;
            uistack(fig.BackgroundAxes,"bottom");

            if ~isempty(p.IterText)
                set(p.IterText,'ButtonDownFcn','uiresume;', ...
                    'HitTest','on','PickableParts','all');
                set(p.Ax.iterList,'ButtonDownFcn','uiresume');
            end

            mk = @(x,str)uicontrol(Style="pushbutton",Units="normalized", ...
                Position=[x 0.98 0.0175 0.02],Parent=fig.Handle, ...
                String=str,Callback='uiresume;');

            p.Controls.selectConfig = mk(0.01,'...');
            p.Controls.nextIter     = mk(0.03,'>');
            p.Controls.prevIter     = mk(0.05,'<');
        end

        function nextStep = handleUI(p,iter)
            fig             = p.Fig;
            ctrl            = p.Controls;
            altConfigs      = p.AltConfigs;
            configsDropDown = gobjects(1);
            nextStep        = 0;

            while nextStep == 0
                uiwait;
                if ~ishandle(fig.Handle), nextStep = []; return; end

                switch gco
                    case ctrl.nextIter
                        nextStep = 1;

                    case ctrl.prevIter
                        nextStep = -1;

                    case ctrl.selectConfig
                        pos = ctrl.selectConfig.Position;
                        configsDropDown = uicontrol(Style="popupmenu", ...
                            String=["";arrayfun(@(c)c.ToString(),altConfigs)], ...
                            Units="normalized",Position=[pos(1) 0.01 0.5 0.975], ...
                            Callback=@(src,~)uiresume(ancestor(src,"figure")),FontSize=12);

                    case configsDropDown
                        val = configsDropDown.Value;
                        delete(configsDropDown);
                        if val > 1
                            altConfigs(val-1).calcEnergies(p.Configurator.Weights,halt=true);
                        end

                    otherwise
                        target = get(gco,'UserData');
                        if isnumeric(target) && isscalar(target)
                            nextStep = target - iter;
                        end
                end
            end
        end

        % --- grid of energy matrices ----------------------------------------
        %   Cell (1,1) is the current configuration; the rest of row 1 is left
        %   blank (NaN) so nothing sits beside it. Alternatives fill rows 2:m
        %   of every column, column 1 first, then column 2, and so on, so
        %   ax.altEnergy(1) is directly below the current matrix.
        function [layout,m] = energyLayout(p,fig,panelIx,nRows)
            nCols  = p.Opts.energyCols;
            avail  = fig.Axes(panelIx).Position(4);      % normalized fig units
            panelH = nRows*p.Opts.rowHeight;

            nFit    = floor(avail/panelH);                       % rows that fit
            nNeeded = ceil(p.Opts.maxAlt/nCols) + 1;             % rows the cap allows
            m = max(2,min(nNeeded,nFit));                        % >=1 alt row

            layout = nan(m,nCols);
            layout(1,1) = 1;
            idx = 2;
            for col = 1:nCols
                for row = 2:m
                    layout(row,col) = idx;
                    idx = idx+1;
                end
            end
        end

        % --- font size matched to the fixed row height ----------------------
        function fs = rowFontSize(p,fig)
            figPx = getpixelposition(fig.Handle);
            rowPx = p.Opts.rowHeight*figPx(4);
            fs    = max(6,round(0.5*rowPx*0.75));        % px -> points
        end

        % --- shared label formatting ---------------------------------------
        function s = iterLabel(p,ix)
            cfg = p.Configurator;
            s = arrayfun(@(c)"iter " + c + ": " + cfg.IterConfigs(c).ToLabels(),ix);
        end

    end

end
