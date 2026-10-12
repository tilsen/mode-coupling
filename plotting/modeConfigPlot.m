
classdef modeConfigPlot

    properties
        Config                      % the modeConfig being plotted
        Excitations
        Modes
        modeLabelType = 'default'
        Articulae       
        configAxes = []
        uncoupledAxes = []
        PanelLabel = []
        SystemSymbolFontSize = [] % points; takes precedence over ratios
        ModeLabelFontSize = []
        PanelLabelFontSize = []
        SystemSymbolHeightRatio = []
        SystemSymbolWidthRatio = []
        PanelLabelWidthRatio = []
        UncoupledSymbolHeightRatio = []
        UncoupledSymbolFontSize = []   % points; fixes the size of the symbols in the uncoupled row (overrides the ratio)
        ModeLabelHeightRatio = [] % mode label height / coordination-circle diameter
        uncoupledHeight = 0
        showUncoupled = true
        uncoupledLocation = "top"  
        radius = 0.25   
        verticalSpacing = 2
        horizontalSpacing = 1
        excitationRadiusRatio = 0.1
        stackCoincident = false
        modeFillAlpha = 0
        Interactive
    end

    methods
        function obj = modeConfigPlot(config,opts)
            arguments
                config                
                opts.?plotopts.ConfigurationGeometry
            end
            opts = plotopts.Base.resolve(opts,plotopts.ConfigurationGeometry());
            obj.Excitations = config.Excitations;
            
            if isempty(opts.ModeIds)
                obj.Modes = config.Modes;
            else
                obj.Modes = config.Modes(ismember(config.Modes.Id,opts.ModeIds),:);
                obj.Excitations = obj.Excitations(ismember(obj.Excitations.ModeId,opts.ModeIds),:);
            end
            obj.Articulae = config.Articulae;
            obj.Config = config;

            if ~isempty(opts.Radius), obj.radius = opts.Radius; end
            if ~isempty(opts.VerticalSpacing), obj.verticalSpacing = opts.VerticalSpacing; end
            if ~isempty(opts.HorizontalSpacing), obj.horizontalSpacing = opts.HorizontalSpacing; end
            if ~isempty(opts.ExcitationRadiusRatio), obj.excitationRadiusRatio = opts.ExcitationRadiusRatio; end
            obj.stackCoincident = opts.StackCoincident;
            
            obj = obj.layout();
            obj = obj.applyColors();
        end

        function obj = applyColors(obj,opts)
            arguments
                obj
                opts.Scheme = 'default'
                opts.UncoupledColor = [0.5 0.5 0.5];
            end            
            switch(opts.Scheme)
                case 'default'
                    % keep mode colors the configuration already carries
                    % (shared with the mode-selection plot)
                    if ~ismember("Color",obj.Modes.Properties.VariableNames)
                        obj.Modes.Color = repmat(opts.UncoupledColor,height(obj.Modes),1);
                    end
            end
            if ismember("Color",obj.Excitations.Properties.VariableNames), return; end
            for i=1:height(obj.Excitations)
                if isnan(obj.Excitations.ModeId(i)), obj.Excitations.Color(i,:) = opts.UncoupledColor; continue; end
                obj.Excitations.Color(i,:) = obj.Modes.Color(obj.Excitations.ModeId(i)==obj.Modes.Id,:);
            end
        end

        function obj = layout(obj)
            nE = height(obj.Excitations);
            nM = height(obj.Modes);

            obj.Modes.Pos = [-obj.Modes.Sign*obj.horizontalSpacing, ...
                -obj.verticalSpacing*(obj.Modes.PairNum-1)];
            obj.Modes.Radius       = obj.radius*ones(nM,1);
            obj.Excitations.Radius = (obj.radius*obj.excitationRadiusRatio)*ones(nE,1);
            obj.Excitations.Pos    = nan(nE,2);

            [coupled,modeIx] = ismember(obj.Excitations.ModeId, obj.Modes.Id);
            m = modeIx(coupled);

            obj.Excitations.theta = nan(nE,1);
            obj.Excitations.theta(coupled) = pi .* obj.Excitations.Phase(coupled);

            obj.Excitations.Pos(coupled,:) = obj.Modes.Radius(m).*obj.unitCirclePos(obj.Excitations.theta(coupled)) ...
                + obj.Modes.Pos(m,:);

            if obj.stackCoincident && any(coupled)
                % excitations at the same position (in phase within a mode)
                % are stacked vertically, first on top, centered on the
                % shared position
                rowsC = find(coupled);
                [~,~,grp] = unique(round(obj.Excitations.Pos(rowsC,:),6),'rows','stable');
                for g = 1:max(grp)
                    ix = rowsC(grp==g);
                    n = numel(ix);
                    if n>1
                        obj.Excitations.Pos(ix,2) = obj.Excitations.Pos(ix,2) ...
                            - ((1:n)'-(n+1)/2).*2.*obj.Excitations.Radius(ix);
                    end
                end
            end
        end

        function obj = plot(obj,opts)
            arguments
                obj
                opts.?plotopts.ConfigurationDrawing
            end
            if ~isfield(opts,'ModeLabelType'), opts.ModeLabelType = obj.modeLabelType; end
            opts = plotopts.Base.resolve(opts,plotopts.ConfigurationDrawing());

            obj.modeFillAlpha = opts.ModeFillAlpha;
            obj.SystemSymbolFontSize = opts.SystemSymbolFontSize;
            obj.ModeLabelFontSize = opts.ModeLabelFontSize;
            obj.PanelLabelFontSize = opts.PanelLabelFontSize;
            obj.SystemSymbolHeightRatio = opts.SystemSymbolHeightRatio;
            obj.SystemSymbolWidthRatio = opts.SystemSymbolWidthRatio;
            obj.PanelLabelWidthRatio = opts.PanelLabelWidthRatio;
            obj.UncoupledSymbolHeightRatio = opts.UncoupledSymbolHeightRatio;
            obj.UncoupledSymbolFontSize = opts.UncoupledSymbolFontSize;
            obj.ModeLabelHeightRatio = opts.ModeLabelHeightRatio;
            obj.modeLabelType = opts.ModeLabelType;
            autoYLim = isempty(opts.Height) || isnan(opts.Height);
            xlims = [-1.5 2];
            switch(autoYLim)
                case true
                    ylims = [-max(abs(obj.Modes.Id)) 1];
                otherwise
                    ylims = [-opts.Height 1];
            end

            opts.Parent = plotParent.axes(opts.Parent,@()stFig(1, ...
                [0.01 0.01 0.01 0.05],Aspect=max(diff(xlims)/diff(ylims),2.0)));

            if stFig.isLiveScript()
                obj.Interactive = false;
            else
                obj.Interactive = opts.Interactive;
            end

            axes(opts.Parent);
            obj.configAxes = opts.Parent;

            obj.Excitations.Handle = gobjects(height(obj.Excitations),1);
            obj.Excitations.LabelHandle = gobjects(height(obj.Excitations),1);

            set(opts.Parent,"XLim",xlims,"YLim",ylims); hold(opts.Parent,"on");

            obj = obj.drawModes();
            obj = obj.drawSystems();

            if autoYLim
                axis equal;
                axis tight;                
                stFig.rescaleaxes(gca,'xy',opts.Margins(1),opts.Margins(2));
            else
                obj.setMargins(opts.Margins);  
            end
                      
            if opts.SimplifyLabels, obj = obj.simplifyLabels(); end

            if obj.Interactive
                hh = [obj.Excitations.Handle; obj.Excitations.LabelHandle; obj.Modes.Handle; obj.Modes.LabelHandle];
                set(hh(ishandle(hh)),'HitTest','on');
            end

            set(obj.configAxes,'Color','none','Box','off', ...
                'XColor','none','YColor','none','Clipping','off','XTick',[],'YTick',[]);
            if opts.ShowBox
                set(obj.configAxes,'Box','on','Visible','on','XColor','k','YColor','k');
            end
                                  
            if opts.ShowUncoupled
                obj = obj.drawUncoupled(Loc=opts.UncoupledLoc);
            end
            if opts.ShowPanelLabel
                obj = obj.drawPanelLabel(Prefix=opts.LabelPrefix,FontSize=opts.PanelLabelFontSize);
            end
            if opts.ExcitationSubscripts
                obj = obj.subscriptExcitations(Prefix=opts.LabelPrefix);
            end
            obj.finalizeLayout();
        end

        function obj = subscriptExcitations(obj,opts)
            % Subscript each excitation's symbol with its index among the
            % excitations of the same gestural (rank by activation, i.e.
            % table order), in the system labels and in the panel label,
            % which is rebuilt from the same symbols, {mode}{mode}...
            arguments
                obj
                opts.Prefix = ""
            end
            E = obj.Excitations;
            rk = zeros(height(E),1);                              % rank within gestural by activation
            for n = unique(E.Name,'stable')'
                idx = find(E.Name==n);
                [~,o] = sort(E.Activation(idx),'descend');
                rk(idx(o)) = 1:numel(idx);
            end
            tol = 1e-3;
            modeStr = strings(height(obj.Modes),1);
            for j = 1:height(obj.Modes)
                members = find(E.ModeId==obj.Modes.Id(j));
                [~,srt] = sort(round(E.Phase(members)/tol)*tol);  % by phase, table order within a phase
                members = members(srt);
                phases = unique(round(E.Phase(members)/tol)*tol,'stable');
                for p = 1:numel(phases)
                    grp = members(abs(E.Phase(members)-phases(p))<tol);
                    lh = obj.Excitations.LabelHandle(grp(1));
                    if ~isgraphics(lh,'text'), continue; end
                    toks = strsplit(string(lh.String),',');
                    if numel(toks)==numel(grp)
                        toks = toks + "_{" + string(rk(grp))' + "}";
                        lh.Interpreter = 'tex';
                        lh.String = char(strjoin(toks,','));
                    end
                    modeStr(j) = modeStr(j) + strjoin(toks,"");
                end
            end
            if isgraphics(obj.PanelLabel,'text')
                obj.PanelLabel.Interpreter = 'tex';
                obj.PanelLabel.String = char(string(opts.Prefix) + strjoin("\{"+modeStr+"\}",""));   % escaped: tex would swallow plain braces
            end
        end

        function obj = drawPanelLabel(obj,opts)
            arguments
                obj
                opts.Prefix = ""
                opts.FontSize = []
            end
            labelAxes = obj.configAxes;
            if isgraphics(obj.uncoupledAxes,'axes')
                labelAxes = obj.uncoupledAxes;
            end
            if isgraphics(obj.PanelLabel), delete(obj.PanelLabel); end
            obj.PanelLabel = text(labelAxes,0,1.02, ...
                string(opts.Prefix) + strrep(obj.Config.ToString(),' ',''), ...
                'Units','normalized','Interpreter','none', ...
                'HorizontalAlignment','left','VerticalAlignment','bottom', ...
                'Clipping','off','HitTest','off','PickableParts','none');
            if isempty(opts.FontSize)
                % Width only: labelAxes is often the short uncoupled-row
                % strip, and the label is drawn just above it (not inside
                % it), so constraining by that axes' height doesn't match
                % what's actually on screen.
                fontsizeObjDim(obj.PanelLabel,0.4,'x',parent=labelAxes,maxFontSize=11);
            else
                obj.PanelLabel.FontSize = opts.FontSize;
            end
        end

        function obj = setMargins(obj,margins)
            %axis(obj.configAxes,'tight');
            axis(obj.configAxes,'equal');            
            axrescaley(obj.configAxes,margins(2));
            axrescalex(obj.configAxes,margins(1));            
        end

        function finalizeLayout(obj,opts)
            % Call after changing panel geometry, limits, or label strings.
            % No resize/limit listeners: layout is an explicit operation.
            arguments
                obj
                opts.FitLimits (1,1) logical = true
            end
            % Process pending resize events once; all iterative work below
            % is performed on a separate, invisible figure.
            drawnow;
            for k = 1:numel(obj)
                obj(k).realignUncoupled();
                [trial,scratch,sourceLabels,trialLabels] = obj(k).layoutCopy();
                cleanup = onCleanup(@()delete(scratch));
                if opts.FitLimits
                    trial.fitLayoutCopy();
                else
                    labels = trial.Excitations.LabelHandle;
                    labels = labels(isgraphics(labels,'text'));
                    labels = labels(arrayfun(@(t)t.Parent==trial.configAxes && strcmp(t.Visible,'on'),labels));
                    trial.sizeSystemLabelsToModes(labels);
                end
                % Mode and auxiliary labels do not determine the limits.
                % Size them only after the system-label fitting is complete.
                trial.sizeModeLabelsToModes();
                trial.sizeAuxiliaryLabels();
                if opts.FitLimits && (isempty(obj(k).SystemSymbolWidthRatio) || ~isempty(obj(k).SystemSymbolFontSize))
                    set(obj(k).configAxes,'XLim',trial.configAxes.XLim, ...
                        'YLim',trial.configAxes.YLim);
                end
                if ~isempty(sourceLabels)
                    set(sourceLabels,{'FontUnits'},get(trialLabels,{'FontUnits'}));
                    set(sourceLabels,{'FontSize'},get(trialLabels,{'FontSize'}));
                end
                clear cleanup;
            end
        end

        function [trial,scratch,sourceLabels,trialLabels] = layoutCopy(obj)
            % Copy complete axes so fonts, interpreters, aspect ratios, and
            % graphics all have the same physical geometry as the live plot.
            sourceFig = ancestor(obj.configAxes,'figure');
            pos = getpixelposition(sourceFig);
            scratch = figure('Visible','off','HandleVisibility','off', ...
                'IntegerHandle','off','Units','pixels','Position',pos, ...
                'MenuBar','none','ToolBar','none','Scrollable','off', ...
                'Color',sourceFig.Color,'Tag','modeConfigLayoutScratch');
            try
                sourceLabels = [obj.Excitations.LabelHandle; obj.Modes.LabelHandle];
                if isscalar(obj.PanelLabel) && isgraphics(obj.PanelLabel,'text')
                    sourceLabels(end+1,1) = obj.PanelLabel;
                end
                sourceLabels = unique(sourceLabels(isgraphics(sourceLabels,'text')),'stable');
                trialLabels = gobjects(size(sourceLabels));
                tags = get(sourceLabels,{'Tag'});
                % Temporary unique tags map handles without relying on the
                % order in which copyobj copies axes children. Restore them
                % before any rendering, including on a failed copy.
                restoreTags = onCleanup(@()set(sourceLabels,{'Tag'},tags));
                prefix = tempname;
                for j = 1:numel(sourceLabels)
                    sourceLabels(j).Tag = sprintf('%s_%d',prefix,j);
                end
                trial = obj;
                sourceAxes = obj.configAxes;
                if isscalar(obj.uncoupledAxes) && isgraphics(obj.uncoupledAxes,'axes')
                    sourceAxes(end+1) = obj.uncoupledAxes;
                end
                copies = gobjects(size(sourceAxes));
                for j = 1:numel(sourceAxes)
                    copies(j) = copyobj(sourceAxes(j),scratch);
                    set(copies(j),'Units','pixels','PositionConstraint','innerposition', ...
                        'Position',getpixelposition(sourceAxes(j),true));
                end
                for j = 1:numel(sourceLabels)
                    trialLabels(j) = findall(scratch,'Type','text','Tag',sourceLabels(j).Tag);
                    trialLabels(j).Tag = tags{j};
                end
                clear restoreTags;
                trial.configAxes = copies(1);
                if numel(copies)>1, trial.uncoupledAxes = copies(2); end
                for j = 1:numel(sourceLabels)
                    trial.Excitations.LabelHandle(obj.Excitations.LabelHandle==sourceLabels(j)) = trialLabels(j);
                    trial.Modes.LabelHandle(obj.Modes.LabelHandle==sourceLabels(j)) = trialLabels(j);
                    if isequal(obj.PanelLabel,sourceLabels(j)), trial.PanelLabel = trialLabels(j); end
                end
            catch err
                delete(scratch);
                rethrow(err);
            end
        end

        function fitSystemLabels(obj)
            obj.finalizeLayout();
        end

        function fitLayoutCopy(obj)
            % axis tight includes the plotted geometry, but not text extents.
            % Fit after simplifying labels and reserving the uncoupled row.
            ax = obj.configAxes;
            if ~isgraphics(ax) || isappdata(ax,'FittingSystemLabels'), return; end
            setappdata(ax,'FittingSystemLabels',true);
            fittingCleanup = onCleanup(@()rmappdata(ax,'FittingSystemLabels')); %#ok<NASGU>
            labels = obj.Excitations.LabelHandle;
            labels = labels(isgraphics(labels,'text'));
            labels = labels(arrayfun(@(h)h.Parent==ax && strcmp(h.Visible,'on'),labels));
            if isempty(labels), return; end
            if ~isempty(obj.SystemSymbolWidthRatio) && isempty(obj.SystemSymbolFontSize)
                % Explicit width sizing may intentionally extend beyond the
                % axes. Size the labels, but do not expand the axes to fit.
                obj.sizeSystemLabelsToModes(labels);
                return;
            end
            units = get(labels,{'Units'});
            restoreUnits = onCleanup(@()set(labels,{'Units'},units)); %#ok<NASGU>
            % Keep text anchored in data coordinates while the renderer
            % settles equal-aspect axes. Switching to normalized units during
            % rendering would move anchors when the plot box changes size.
            set(labels,'Units','data');
            margin = 0.06;
            for iter = 1:20
                obj.sizeSystemLabelsToModes(labels);
                drawnow nocallbacks;
                ext = cell2mat(get(labels,{'Extent'}));
                xl = ax.XLim;
                yl = ax.YLim;
                boundsX = [min(ext(:,1)) max(ext(:,1)+ext(:,3))];
                boundsY = [min(ext(:,2)) max(ext(:,2)+ext(:,4))];
                pad = margin*[diff(xl) diff(yl)];
                if boundsX(1)>=xl(1)+pad(1) && boundsX(2)<=xl(2)-pad(1) && ...
                        boundsY(1)>=yl(1)+pad(2) && boundsY(2)<=yl(2)-pad(2)
                    return;
                end
                ax.XLim = [min(xl(1),boundsX(1)-pad(1)) max(xl(2),boundsX(2)+pad(1))];
                ax.YLim = [min(yl(1),boundsY(1)-pad(2)) max(yl(2),boundsY(2)+pad(2))];
            end
        end

        function sizeSystemLabelsToModes(obj,labels)
            if isempty(labels), return; end
            if ~isempty(obj.SystemSymbolFontSize)
                set(labels,'FontUnits','points','FontSize',obj.SystemSymbolFontSize);
                return;
            end
            widths = inf(numel(labels),1);
            heights = widths;
            if ~isempty(obj.SystemSymbolWidthRatio)
                widths(:) = obj.SystemSymbolWidthRatio*diff(obj.configAxes.XLim);
            end
            if ~isempty(obj.SystemSymbolHeightRatio)
                for k = 1:numel(labels)
                    excitation = find(obj.Excitations.LabelHandle==labels(k),1);
                    mode = find(obj.Modes.Id==obj.Excitations.ModeId(excitation),1);
                    if ~isempty(mode)
                        heights(k) = obj.SystemSymbolHeightRatio*2*obj.Modes.Radius(mode);
                    end
                end
            end
            obj.sizeLabelGroup(labels,widths,heights);
        end

        function sizeLabelGroup(~,labels,widths,heights)
            % Render once per group/pass, never once per individual label.
            if isempty(labels) || all(isinf(widths) & isinf(heights)), return; end
            oldUnits = get(labels,{'Units'});
            restore = onCleanup(@()set(labels,{'Units'},oldUnits)); %#ok<NASGU>
            set(labels,'Units','data');
            for trial = 1:3
                drawnow nocallbacks;
                extents = cell2mat(get(labels,{'Extent'}));
                sizes = cell2mat(get(labels,{'FontSize'}));
                candidates = sizes .* min(widths./max(extents(:,3),eps), ...
                    heights./max(extents(:,4),eps));
                target = max(1,min(candidates));
                if ~isfinite(target), return; end
                if all(abs(sizes-target)<0.05), return; end
                set(labels,'FontSize',target);
            end
        end

        function sizeAuxiliaryLabels(obj)
            if ~isempty(obj.PanelLabelFontSize) && isscalar(obj.PanelLabel) && isgraphics(obj.PanelLabel,'text')
                set(obj.PanelLabel,'FontUnits','points','FontSize',obj.PanelLabelFontSize);
            elseif ~isempty(obj.PanelLabelWidthRatio) && isscalar(obj.PanelLabel) && isgraphics(obj.PanelLabel,'text')
                % Same 11pt cap as drawPanelLabel: the ratio is what small
                % iteration panels need, but a short config string in a wide
                % axes fits to tens of points and overruns the figure.
                fontsizeObjDim(obj.PanelLabel,obj.PanelLabelWidthRatio,'x', ...
                    parent=obj.PanelLabel.Parent,maxFontSize=11);
            end
            if ~isempty(obj.UncoupledSymbolHeightRatio) && isempty(obj.UncoupledSymbolFontSize) && isscalar(obj.uncoupledAxes) && isgraphics(obj.uncoupledAxes,'axes')
                labels = obj.Excitations.LabelHandle;
                labels = labels(isgraphics(labels,'text'));
                labels = labels(arrayfun(@(t)t.Parent==obj.uncoupledAxes && strcmp(t.Visible,'on'),labels));
                if ~isempty(labels)
                    fontsizeObjDim(labels,obj.UncoupledSymbolHeightRatio,'y', ...
                        parent=obj.uncoupledAxes);
                end
            end
        end

        function sizeModeLabelsToModes(obj)
            if isempty(obj.ModeLabelHeightRatio) && isempty(obj.ModeLabelFontSize), return; end
            labels = obj.Modes.LabelHandle;
            valid = isgraphics(labels,'text');
            valid(valid) = arrayfun(@(t)strcmp(t.Visible,'on'),labels(valid));
            if ~isempty(obj.ModeLabelFontSize)
                set(labels(valid),'FontUnits','points','FontSize',obj.ModeLabelFontSize);
                return;
            end
            obj.sizeLabelGroup(labels(valid),inf(sum(valid),1), ...
                obj.ModeLabelHeightRatio*2*obj.Modes.Radius(valid));
        end

        function obj = drawUncoupled(obj,opts)
            arguments
                obj
                opts.Loc (1,1) string {mustBeMember(opts.Loc,"top")} = "top"
                opts.ColorMap = []
                opts.Margins = [0.01 0.005]
                opts.FontSize = 18;
                opts.HeightProp (1,1) double {mustBeGreaterThan(opts.HeightProp,0),mustBeLessThan(opts.HeightProp,1)} = 0.2
                opts.WidthProp = 1
            end          
            uncoupled = isnan(obj.Excitations.ModeId);
            % Reserve a separate slot; data limits (including axis tight)
            % cannot move the mode drawings into the uncoupled row.
            slot = obj.configAxes.Position;
            slot(4) = slot(4)/(1-obj.uncoupledHeight);
            if isgraphics(obj.PanelLabel)
                obj.PanelLabel.Parent = obj.configAxes;
            end
            if isgraphics(obj.uncoupledAxes,'axes'), delete(obj.uncoupledAxes); end
            obj.uncoupledHeight = opts.HeightProp;
            obj.configAxes.Position = slot.*[1 1 1 (1-opts.HeightProp)];
            obj.uncoupledAxes = axes('Parent',obj.configAxes.Parent, ...
                'Units',obj.configAxes.Units,'Position',obj.getUncoupledAxesPos( ...
                slot,opts.Loc,opts.WidthProp,opts.HeightProp,opts.Margins));
            switch(opts.Loc)
                case "top"
                    data = obj.Excitations.Activation';
                    data(~uncoupled) = 0;
                    textData = obj.Excitations.Label';
            end
            mp = stMatrixPlot(data,Text=textData,Parent=obj.uncoupledAxes);
            mp.Colormap = ST_colormap(100,[1 1 1],[1 0 0]);
            mp.CLims = [0 1];
            mp.gridColor = [1 1 1];
            mp.SymmetrizeCLims = false;
            mp.fontSize = opts.FontSize;
            if ~isempty(obj.UncoupledSymbolFontSize), mp.fontSize = obj.UncoupledSymbolFontSize; end
            mp = mp.plot();
            set(mp.textHandles(~uncoupled),'Visible','off');  
            obj.Excitations.LabelHandle(uncoupled) = mp.textHandles(uncoupled);
            set(obj.uncoupledAxes,'Xcolor','none','YColor','none');
            obj.uncoupledAxes.UserData = {opts.Loc,opts.WidthProp, opts.HeightProp,opts.Margins};
            if isgraphics(obj.PanelLabel)
                obj.PanelLabel.Parent = obj.uncoupledAxes;
                obj.PanelLabel.Units = 'normalized';
                obj.PanelLabel.Position = [0 1.02 0];
            end
        end
        function [pos] = getUncoupledAxesPos(~,parentPos,location,widthProp,heightProp,margins)
            switch(location)
                case "top"
                    pos = [parentPos(1)+margins(1)*parentPos(3) ...
                           parentPos(2)+(1-heightProp)*parentPos(4) + margins(2)*parentPos(4)...
                           parentPos(3)*widthProp - 2*margins(1)*parentPos(3) ...
                           parentPos(4)*heightProp - 2*margins(2)*parentPos(4)];
            end
        end
        function obj = drawModes(obj)
            % Default preserves labels supplied by the configuration. Other
            % styles are plot-local and read level/sign from the modes table.
            signs = repmat("+",height(obj.Modes),1);
            signs(obj.Modes.Sign<0) = "-";
            signs(obj.Modes.Sign==0) = "0";
            switch obj.modeLabelType
                case 'default'
                    obj.Modes.Label = obj.Config.Modes.Label( ...
                        arrayfun(@(id)find(obj.Config.Modes.Id==id,1),obj.Modes.Id));
                case 'sign'
                    obj.Modes.Label = signs;
                case 'num'
                    obj.Modes.Label = string(obj.Modes.PairNum)+"^{"+signs+"}";
                case 'mu'
                    obj.Modes.Label = "\mu_{"+string(obj.Modes.PairNum)+"}^{"+signs+"}";
            end
            for i=1:height(obj.Modes)
                [obj.Modes.Handle(i),obj.Modes.LabelHandle(i)] = obj.drawMode(obj.Modes(i,:),obj.modeFillAlpha);
            end
        end
        function obj = deleteMode(obj,modeId)
            % Delete the mode circle/label and every excitation circle/label
            % coupled to it (obj.Excitations.ModeId==modeId).
            arguments
                obj
                modeId (1,1) double
            end
            ixMode = find(obj.Modes.Id==modeId,1);
            if ~isempty(ixMode)
                h = [obj.Modes.Handle(ixMode); obj.Modes.LabelHandle(ixMode)];
                delete(h(isgraphics(h)));
            end
            ixExc = find(obj.Excitations.ModeId==modeId);
            if ~isempty(ixExc)
                h = [obj.Excitations.Handle(ixExc); obj.Excitations.LabelHandle(ixExc)];
                delete(h(isgraphics(h)));
            end
        end
        function obj = drawSystems(obj)           
            obj.Excitations.Handle = gobjects(height(obj.Excitations),1);
            obj.Excitations.LabelHandle = gobjects(height(obj.Excitations),1);
            ixs = find(~isnan(obj.Excitations.ModeId));
            if isempty(ixs), return; end
            for i=ixs(:)'
                [obj.Excitations.Handle(i),obj.Excitations.LabelHandle(i)] = ...
                    obj.drawSystem(obj.Excitations(i,:));
            end
            obj = obj.combineSystemLabels();
        end
        function obj = combineSystemLabels(obj)
            tol = 1e-3;
            obj.Excitations.Phase = round(obj.Excitations.Phase*(1/tol))*tol;
            for j=1:height(obj.Modes)
                phases = unique(obj.Excitations.Phase(obj.Excitations.ModeId==obj.Modes.Id(j)));
                for i=1:numel(phases)
                    ixs = find(obj.Excitations.Phase==phases(i) & obj.Excitations.ModeId==obj.Modes.Id(j));
                    if numel(ixs)>1
                        obj.Excitations.LabelHandle(ixs(1)).String = ...
                            strjoin(get(obj.Excitations.LabelHandle(ixs),'String'),',');
                        % center the merged label on the group (matters when
                        % the group's circles are stacked)
                        lh = obj.Excitations.LabelHandle(ixs(1));
                        lh.Position(2) = lh.Position(2) + mean(obj.Excitations.Pos(ixs,2)) - obj.Excitations.Pos(ixs(1),2);
                        set(obj.Excitations.LabelHandle(ixs(2:end)),'Visible','off');
                    end
                end
            end

        end
        function obj = simplifyLabels(obj,opts)   
            arguments
                obj
                opts.combinePhones = true
            end

            sysIxs = find(~isnan(obj.Excitations.ModeId));
            if isempty(sysIxs), return; end

            %replacements:
            repSets = arrayfun(@(c){obj.Articulae.Gestures.Symb(obj.Articulae.Map(c,:))},...
                (1:height(obj.Articulae.Phones))');
            reps = obj.Articulae.Phones.Symb;

            % A phone that owns no gestures of its own (e.g. a compound
            % phone whose gestures are all delegated to sub-phones) has an
            % empty repSet. all(ismember([],strs)) is vacuously true, so
            % an empty repSet would match every iteration below without
            % ever removing anything from strs, looping forever.
            hasGestures = ~cellfun(@isempty,repSets);
            repSets = repSets(hasGestures);
            reps = reps(hasGestures);

            %sort by number of excitations to simplify
            nExcs = cellfun(@(c)numel(c),repSets);
            [~,srtix] = sort(nExcs,'descend');
            repSets = repSets(srtix);
            reps = reps(srtix);

            %
            for i=sysIxs(:)'
                str = obj.Excitations.LabelHandle(i).String;                 
                strs = strsplit(string(str),',');
                picks = modeConfigPlot.coverGestures(strs,repSets);
                for repIx = picks
                     remIxs = arrayfun(@(c)find(strs==c,1,'first'),repSets{repIx});
                     strs = strs(setdiff(1:numel(strs),remIxs));
                     str = strjoin([strs,"[" + reps(repIx) + "]"],',');
                     strs = strsplit(string(str),',');
                end
                str = regexprep(str,',$','');
                if iscell(str)
                    str = str(~cellfun('isempty',str));
                    str{end} = regexprep(str{end},',$','');
                end

                if opts.combinePhones
                    str = regexprep(str,'\],\[','');
                end
                obj.Excitations.LabelHandle(i).String = str;
            end
            
        end       
        function [] = setFontSize(obj,fontSize)
            ixs = ishandle(obj.Excitations.LabelHandle);
            set(obj.Excitations.LabelHandle(ixs),'FontSize',fontSize);
            obj.fitSystemLabels();
        end
        function [obj] = optimizeSystemLabelFontSize(obj,opts)
            arguments
                obj
                opts.minSize = 12
                opts.maxSize = 24
            end
            ixs = find(ishandle(obj.Excitations.Handle));
            if isempty(ixs), return; end
            ylims = get(obj.Excitations.Handle(ixs(1)).Parent,'ylim');
            xlims = get(obj.Excitations.Handle(ixs(1)).Parent,'xlim');
            trgyprop = 0.15;
            trgxprop = 0.05;
            for i=ixs(:)'
                ext = obj.Excitations.LabelHandle(i).Extent;
                yprop = ext(4)/diff(ylims);
                xprop = ext(3)/diff(xlims);
                currentFontSize = obj.Excitations.LabelHandle(i).FontSize;
                newFontSize_y = min(max(round(currentFontSize*trgyprop/yprop),opts.minSize),opts.maxSize);
                newFontSize_x = min(max(round(currentFontSize*trgxprop/xprop),opts.minSize),opts.maxSize);
                obj.Excitations.LabelHandle(i).FontSize = min([newFontSize_x newFontSize_y]);
            end
        end
        function [] = realignUncoupled(obj)
            if ~isscalar(obj.uncoupledAxes) || ~isgraphics(obj.uncoupledAxes,'axes'), return; end
            slot = obj.configAxes.Position;
            slot(4) = slot(4)/(1-obj.uncoupledHeight);
            obj.uncoupledAxes.Units = obj.configAxes.Units;
            newPos = obj.getUncoupledAxesPos(slot,obj.uncoupledAxes.UserData{:});
            set(obj.uncoupledAxes,"position",newPos);
        end

        % ================= plots driven by the config ====================

        function h = plotEnergy(obj,opts)
            arguments
                obj
                opts.?plotopts.Energy
            end
            opts = plotopts.Base.resolve(opts,plotopts.Energy());
            opts.Parent = plotParent.axes(opts.Parent);
            config = obj.Config;

            % fixed vertical size per matrix row, as a fraction of the figure
            if ~isempty(opts.RowHeight)
                modeConfigPlot.setRowHeight(opts.Parent,height(config.Modes),opts.RowHeight);
            end

            axes(opts.Parent);
            costf = gmConfigurator.EnergyTerms;
            data = config.Energies.X;

            %sort
            weights = config.Weights;
            v = cellfun(@(c)weights.(c),costf);
            [ww,idx] = sort(v,'descend');
            costf = costf(idx);
            data = data(:,idx);
            data = data.*ww;
            costf = costf + " (" + arrayfun(@(c)string(num2str(c)),ww) + ")";

            data(2:end,1) = nan;
            m = stMatrixPlot(data);
            m.fontSize = opts.FontSize;
            m.XLabels = string(costf(:));
            m.Colormap = ST_colormap(1001,[0 0 1],[1 1 1],[1 0 0]);
            m.CLims = [-10 10];

            % Each column's values are always an integer multiple of that
            % column's own weight, so the minimal decimals needed to show
            % them exactly is however many decimal places the weight
            % itself has -- e.g. weight 90 needs none, 1.6 needs one,
            % 0.06 needs two. A single fixed FormatStr can't serve
            % weights spanning ~0.06 to 90 (defaultWeights.csv): it
            % either rounds small-weight columns to zero or pads
            % large-weight ones with meaningless decimals.
            maxDecimals = 3;
            decimals = maxDecimals*ones(size(ww));
            unresolved = true(size(ww));
            for d = 0:maxDecimals
                isExact = unresolved & abs(ww*10^d-round(ww*10^d))<1e-6;
                decimals(isExact) = d;
                unresolved(isExact) = false;
            end
            fmts = "%1." + string(decimals) + "f";
            m = m.plot(Parent=opts.Parent,FormatStr=fmts,HideValues=0);
            % imagesc only auto-reverses YDir on a fresh (non-held) axes;
            % this Parent may be a reused axes already in hold-on mode
            % (see stFig.subAxes), so force it explicitly -- otherwise
            % row 1 lands at the bottom instead of the top, inconsistent
            % with plotActivationLevels and other panels sharing the axes.
            set(opts.Parent,'YDir','reverse');
            opts.Parent.XTickLabelRotation = 45;
            if ~isempty(opts.ColumnLabelFontSize)
                opts.Parent.XAxis.FontSize = opts.ColumnLabelFontSize;
            end

            % Explicit text avoids export-time reflow of rotated tick labels.
            columnFontSize = opts.Parent.XAxis.FontSize;
            opts.Parent.XTickLabel = [];
            h.columnLabels = gobjects(numel(costf),1);
            for column = 1:numel(costf)
                x = (column-opts.Parent.XLim(1))/diff(opts.Parent.XLim);
                h.columnLabels(column) = text(opts.Parent,x,1.02,costf(column), ...
                    'Units','normalized','Rotation',45, ...
                    'HorizontalAlignment','left','VerticalAlignment','bottom', ...
                    'FontSize',columnFontSize,'FontName',opts.Parent.FontName, ...
                    'Interpreter','none','Clipping','off','Tag','energyColumnLabel');
            end

            configStrs = config.ToStrings('style','short',escapeGroups=true);

            for i=1:height(config.Modes)
                h.configStrs(i) = text(0.5,i,configStrs(i) + " ", ...
                    'HorizontalAlignment','right','FontSize',opts.FontSize);
            end
            h.totalEnergyStr(i) = text(max(xlim),i," " + num2str(config.Energies.totalE,'%1.2f'), ...
                'FontWeight','bold','FontSize',opts.FontSize);

            inspectEnergy = @()config.calcEnergies(halt=true);
            set(opts.Parent,'HitTest','on','PickableParts','visible',...
                'ButtonDownFcn',@(~,~)inspectEnergy());
            set(findall(opts.Parent,'-not','Type','axes'),'HitTest','off','PickableParts','none');

            h.matrixPlot = m;
            h.axes = opts.Parent;
        end

        function m = plotActivationLevels(obj,opts)
            arguments
                obj
                opts.?plotopts.ActivationLevels
            end
            opts = plotopts.Base.resolve(opts,plotopts.ActivationLevels());
            opts.Parent = plotParent.axes(opts.Parent);
            E = obj.Config.Excitations;

            levels = sort(unique(E.Activation),'descend');
            gestures = strings(numel(levels),1);
            for i=1:numel(levels)
                g = E.Name(E.Activation==levels(i));
                g = "[" + g + "]";
                gestures(i) = strjoin(g,", ");
            end

            m = stMatrixPlot(levels,Text=gestures(:),Parent=opts.Parent);
            m = m.plot();
            delete(m.gridHandles{2}{:});
            set(opts.Parent,'YDir','reverse');
        end

        function h = plotMetricalization(obj,opts)
            arguments
                obj
                opts.?plotopts.Metricalization
            end
            opts = plotopts.Base.resolve(opts,plotopts.Metricalization());
            opts.Parent = plotParent.axes(opts.Parent);
            axes(opts.Parent);
            S = obj.Config.Metricalization.Syllables;

            metricalAct = S.metricalAct;
            if opts.normalize
                metricalAct = metricalAct/max(abs(metricalAct));
            end

            switch(opts.style)
                case 'bars'
                    h.bars = bar(metricalAct,FaceColor='flat',ShowBaseLine=opts.showBaseLine);
                case 'bars_points'
                    h.bars = bar(metricalAct,FaceColor='flat',ShowBaseLine=opts.showBaseLine);
                    h.points = plot(metricalAct,'ko','MarkerFaceColor','w');
            end

            actValues = unique(metricalAct);
            colors = repmat(opts.unstressedColor,numel(actValues),1);
            ixs = actValues>opts.stressThresh;
            colors(ixs,:) = repmat(opts.stressColors(1,:),sum(ixs),1);
            colors(actValues==max(actValues),:) = opts.stressColors(2,:);

            [~,ia] = ismember(metricalAct,actValues);
            h.bars.CData = colors(ia,:);

            set(opts.Parent,'Visible','off','XTick',[],'YTick',[]);

            if opts.showLabels
                for i=1:height(S)
                    switch(sign(metricalAct(i)))
                        case -1
                            h.text(i) = text(i,metricalAct(i),"\sigma_{"+i+"}",'Verti','top');
                        otherwise
                            h.text(i) = text(i,metricalAct(i),"\sigma_{"+i+"}",'verti','bot');
                    end
                end
                set(h.text,'FontSize',opts.fontSize,'hori','center');
            end
        end

        function h = plotMetricalGraph(obj,opts)
            arguments
                obj
                opts.?plotopts.MetricalGraph
            end
            opts = plotopts.Base.resolve(opts,plotopts.MetricalGraph());
            opts.Parent = plotParent.axes(opts.Parent);
            axes(opts.Parent);

            S = obj.Config.Metricalization.Syllables;
            nS = height(S);
            nodeInfo.Name = ["sigma_"+S.Id; "mu_"+S.Id];
            nodeInfo.Pos = [repmat((1:nS)',2,1) [zeros(nS,1);-1.5*ones(nS,1)]];

            edgeInfo = nodeInfo.Name(1:nS-1) + " ~ " + nodeInfo.Name(2:nS);
            edgeInfo = [edgeInfo; nodeInfo.Name(nS+1:2*nS) + " > " + nodeInfo.Name(1:nS)];

            for i=1:height(S)
                if S.accentualAct(i)
                    nodeInfo.Name(end+1) = "accent";
                    nodeInfo.Pos(end+1,:) = nodeInfo.Pos(i,:)+[0 1.5];
                    edgeInfo(end+1) = "accent > " + "sigma_"+i;
                end
            end

            if (S.beginInput(1)~=0)
                nodeInfo.Name(end+1) = "begin"; nodeInfo.Pos(end+1,:) = [0 0.75];
                edgeInfo(end+1) = "begin > sigma_1";
            end
            if (S.endInput(end)~=0)
                nodeInfo.Name(end+1) = "end"; nodeInfo.Pos(end+1,:) = [nS+1 0.75];
                edgeInfo(end+1) = "end > sigma_"+nS;
            end

            g = stGraph();
            g.defNodes(struct2table(nodeInfo));
            g.defEdges(edgeInfo);

            ixs = contains(g.Nodes.Name,'sigma') | contains(g.Nodes.Name,'mu');
            g.setNodeProps(ixs,'Radius',0.33);
            g.setNodeProps(~ixs,'Radius',0.27);

            reps = {'mu','\\mu','sigma','\\sigma','primary','1','secondary','2','accent','ℒ'};

            g.setNodeProps([],'Label',mregexprep(g.Nodes.Name,reps{:}));

            if any(S.internalAct)
                g.setNodeProps("mu_"+find(S.internalAct),'Color',0.5*[1 1 1]);
            end

            if (S.beginInput(1)~=0)
                g.setNodeProps("begin",'Label',string(S.beginInput(1)));
            end
            if (S.endInput(end)~=0)
                g.setNodeProps("end",'Label',string(S.endInput(end)));
            end

            for k=1:nS-1
                g.setEdgeProps(k,'Label',"\alpha",'LabelPos',"s");
            end
            g.setEdgeProps("mu_1 sigma_1",'Label',"w_{\mu}");

            if any(S.accentualAct~=0)
                g.setEdgeProps(find(contains(g.Edges.EdgeSpec,'accent'),1,'first'),'Label',"w_{ℒ}");
            end

            g.setNodeProps([],'FontSize',opts.FontSize);
            for k=1:height(g.Edges)
                g.setEdgeProps(k,'LabelFontSize',opts.FontSize);
            end

            g.plot();

            h.graph = g;
        end

    end

    methods (Static)
        function [] = setRowHeight(ax,nRows,rowHeight)
            % Shrink AX vertically so each of NROWS matrix rows occupies
            % ROWHEIGHT of the figure height. Anchored at the top edge of the
            % axes' current slot; never grows the axes beyond that slot.
            target = nRows*rowHeight;
            pos = get(ax,'Position');
            if target >= pos(4), return; end
            set(ax,'Position',[pos(1) pos(2)+pos(4)-target pos(3) target]);
        end

        function picks = coverGestures(strs,repSets)
            % Indices into REPSETS (phones, sorted by gesture count,
            % largest first) whose gesture symbols together account for
            % the most of STRS. A greedy largest-first pass can strand
            % gestures: with [kʷ] in the inventory, k + u's rounding is
            % taken as kʷ and u's other gestures are left over. The
            % search tries the greedy choice first and only replaces it
            % with a cover that leaves strictly fewer symbols unmatched,
            % so labels the greedy pass already resolves are unchanged.
            % Picks are nondecreasing indices, as in the greedy pass.
            best.left = inf;
            best.picks = [];
            best = search(strs,[],best);
            picks = best.picks;

            function best = search(strs,picks,best)
                if best.left==0, return; end
                last = 0;
                if ~isempty(picks), last = picks(end); end
                cands = find(cellfun(@(c)all(ismember(c,strs)),repSets));
                cands = cands(cands>=last);   % a phone may recur
                if isempty(cands)
                    if numel(strs) < best.left
                        best.left = numel(strs);
                        best.picks = picks;
                    end
                    return
                end
                for r = cands(:)'
                    rest = strs;
                    for c = reshape(repSets{r},1,[])
                        rest(find(rest==c,1,'first')) = [];
                    end
                    best = search(rest,[picks r],best);
                end
            end
        end

        function [sh,labh] = drawSystem(s)
            x = linspace(0,2*pi,100);            
            xx = s.Pos(1) + s.Radius*cos(x);
            yy = s.Pos(2) + s.Radius*sin(x);
            sh = fill(xx(:),yy(:),s.Color);
            if isnan(s.ModeId)
                align.horizontal = 'center';
                align.vertical = 'bot';
                align.offsets = [0 -0.1];
            else
                align = textAlignment(rad2deg(s.theta));
            end
            labh = text( ...
                s.Pos(1)+align.offsets(1)*2*s.Radius, ...
                s.Pos(2)+align.offsets(2)*2*s.Radius,s.Label, ...
                'HorizontalAlignment',align.horizontal, ...
                'VerticalAlignment',align.vertical,...
                'FontSize',fontsizeObjDim(1,0.06,"xy",parent=gca));
        end
        function [mh,labh] = drawMode(m,fillAlpha)
            if nargin<2, fillAlpha = 0; end
            x = linspace(0,2*pi,100);
            xx = m.Radius*cos(x) + m.Pos(1);
            yy = m.Radius*sin(x) + m.Pos(2);
            if fillAlpha>0
                % background shading in the mode's color
                fill(xx,yy,m.Color,'FaceAlpha',fillAlpha,'EdgeColor','none'); hold on;
            end
            mh = plot(xx,yy,'-','color',m.Color,'LineWidth',3); hold on;
            labh = text(m.Pos(1),m.Pos(2),m.Label, ...
                'Interpreter','tex', ...
                'HorizontalAlignment','center','VerticalAlignment','middle',...
                'FontSize',fontsizeObjDim(1,0.05,"xy",parent=gca));
        end
        function [xy] = unitCirclePos(theta)
            xy = [cos(theta) sin(theta)];
        end
    end
end

