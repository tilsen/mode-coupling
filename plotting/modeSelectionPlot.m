classdef modeSelectionPlot
% MODESELECTIONPLOT  Multi-panel plot of a simulated modeSelection.
%
%   modeSelectionPlot(ms).plot()
%   ms.plot()                     % the usual route
%
%   Extracted from modeSelection, which keeps only a thin plot()/plotter()
%   delegation so the model can be read and run without the graphics code.

    properties
        Model modeSelection     % the simulated model being drawn
    end

    methods
        function p = modeSelectionPlot(model)
            if nargin > 0, p.Model = model; end
        end

        function hp = shadeSelection(p,ax,opts)
            % Shade, with alpha, the area between the selection threshold and
            % each mode's activation wherever the activation is at or above
            % it, i.e. each mode's selection epoch, in the mode's color.
            %   hp = p.shadeSelection(ax,alpha=0.25,threshold=1,colors=[],state="M")
            arguments
                p
                ax
                opts.alpha = 0.25
                opts.threshold = 1
                opts.colors = []
                opts.state = "M"
            end
            obj = p.Model;
            X = obj.(opts.state);
            colors = opts.colors;
            if isempty(colors)
                if ismember('Color',obj.Modes.Properties.VariableNames)
                    colors = obj.Modes.Color;
                else
                    colors = cool(size(X,2));
                end
            end
            hp = gobjects(0);
            for k = 1:size(X,2)
                above = X(:,k)>=opts.threshold;
                d = diff([0; above; 0]);
                starts = find(d==1);
                stops = find(d==-1)-1;
                for r = 1:numel(starts)
                    ix = starts(r):stops(r);
                    hp(end+1,1) = patch(ax,[obj.t(ix) fliplr(obj.t(ix))], ...
                        [X(ix,k)' opts.threshold*ones(1,numel(ix))],colors(k,:), ...
                        'FaceAlpha',opts.alpha,'EdgeColor','none','HitTest','off'); %#ok<AGROW>
                end
            end
        end

        function h = plot(p,opts)
            arguments
                p
                opts.?plotopts.ModeSelection
            end
            opts = plotopts.Base.resolve(opts,plotopts.ModeSelection());

            obj = p.Model;

            if isempty(opts.theme), opts.theme = 'light'; end   % matches stFig's default theme

            if isempty(opts.panels), opts.panels = obj.stateVars; end
            opts.panels = setdiff(opts.panels,opts.excludePanels,'stable'); 

            nScalarPan = numel(setdiff(opts.panels,"F"));

            plotGestures = true(1,numel(obj.Gestures));
            if opts.activeGesturesOnly
                plotGestures = any(obj.E2G);                
            end
            plotTractSys = true(1,numel(obj.TractSystems));
            if opts.activeTractSysOnly
                plotTractSys = any(obj.G2T(plotGestures,:));
            end

            if isempty(opts.modeColors)
                % the configuration's mode colors, if it has them
                if ismember('Color',obj.Modes.Properties.VariableNames)
                    opts.modeColors = obj.Modes.Color;
                else
                    opts.modeColors = cool(height(obj.Modes));
                end
            end
            if isempty(opts.tractColors)
                opts.tractColors = parula(numel(plotTractSys));
            end
            if isempty(opts.gestureColors)
                [~,c] = find(obj.G2T);
                opts.gestureColors = opts.tractColors(c,:);
            end
            [~,c] = find(obj.E2G);
            excitationColors = opts.gestureColors(c,:);

            axpan = stFig.panelLayout(nScalarPan,ncols=(nScalarPan>4)+1,fillDir="vertical");
            if ismember("F",opts.panels)
                if isempty(axpan)           % F alone: a single panel
                    axpan = 1;
                else
                    axpan = [axpan max(axpan(:))+ones(size(axpan,1),1)];
                end
                opts.panels = [setdiff(opts.panels,"F",'stable') "F"];
                climsF = [opts.fieldClimLow max(obj.F(:))];
                % intensity = floor + (1-floor)*x^gamma, x the density above
                % fieldClimLow as a fraction of the maximum: raising ClimLow to
                % the neutral attractor's lowest density and lowering gamma
                % spread the neutral field over a visible range
                xc = linspace(0,1,1001)';
                inten = opts.fieldMinIntensity + (1-opts.fieldMinIntensity)*xc.^opts.fieldGamma;
                cmapF = (1-inten)*[1 1 1] + inten*[1 0 0];
            end

            fig = plotParent.layout(opts.Parent,axpan,[0.035 0.02 0.01 0.02],[0.01 0.01],theme=opts.theme,Aspect=opts.aspect);

            fieldCoords = linspace(obj.TractSystems(1).Dims(1), ...
                obj.TractSystems(1).Dims(2), ...
                obj.TractSystems(1).FieldPoints);

            axF = gobjects(0);      % the tract-system field axes, top to bottom
            for i=1:numel(opts.panels)
                panel = opts.panels(i);
                switch(panel)
                    case 'F'
                        X = obj.(panel);
                        X = X(:,plotTractSys,:);
                        T = obj.T(:,plotTractSys);
                        labels = [obj.TractSystems(plotTractSys).Name];
                        fig.subAxes(fig.CurrentAxesIx,(1:size(X,2))',"intMargins",[0 0.005]);
                        for j=1:size(X,2)
                            % keep the handle: labelAxes can make an overlay axes current
                            axj = gca;
                            axF(end+1,1) = axj; %#ok<AGROW>
                            h.(panel+"_"+j) = imagesc(axj,obj.t,fieldCoords,squeeze(X(:,j,:))'); hold(axj,'on');
                            % explicit limits: imagesc leaves them alone on a held axes
                            set(axj,'YTickLabel',[],'CLim',climsF,'YDir','normal','XGrid','on','YGrid','on', ...
                                'YLim',fieldCoords([1 end]),'XLim',obj.t([1 end]),'Layer','top');
                            colormap(axj,cmapF);
                            fig.labelAxes(fig.currentAxes,labels(j),"nw", ...
                                Offsets=[0.001 0],FontSize=opts.fieldLabelFontSize,VerticalAlignment='top', ...
                                HorizontalAlignment='left',usePlotBox=false);
                            uistack(axj,'bottom');
                            h.(panel+"_TractSys_"+j) = plot(axj,obj.t,T(:,j),'Color',opts.centroidColor,'LineWidth',opts.centroidLineWidth);
                            if opts.showNeutralTarget
                                % target of the tract system's neutral attractor
                                sysIx = find(plotTractSys);
                                h.(panel+"_Neutral_"+j) = yline(axj,obj.TractSystems(sysIx(j)).Neutr, ...
                                    'Color',opts.neutralColor,'LineStyle',opts.neutralLineStyle, ...
                                    'LineWidth',opts.neutralLineWidth);
                            end
                            fig.next();
                        end                        

                    case 'G'
                        X = obj.(panel);
                        X = X(:,plotGestures);
                        gNames = strrep([obj.Gestures.Name],'_',' ');
                        gNames = gNames(plotGestures);
                        colors = opts.gestureColors(plotGestures,:);
                        h.(panel) = imagesc(obj.t,(1:numel(gNames)),X'); hold(gca,'on');
                        set(gca,'YDir','reverse','YTick',(1:numel(gNames))-(1/2),'YTickLabel',[]);
                        axis(gca,'tight');  
                        cmap = hot(100);                         
                        switch(opts.theme)
                            case 'light'
                                cmap=flipud(cmap);
                                cmap=cmap(1:end/2,:);
                            case 'dark'
                                cmap=cmap(1:end/2,:);
                        end
                        colormap(gca,cmap);
                        h.("label_"+panel) = arrayfun(@(c)text(min(xlim),c,gNames(c)+" ", ...
                            'Hori','left','Color',colors(c,:),'FontWeight','bold'),(1:numel(gNames)));
                        stFig.drawGridLines(gca,'y');
                        fig.next();

                    case 'Xi'
                        X = obj.(panel); 
                        n = size(X,2);
                        h.(panel) = imagesc(obj.t,1:n,X'); hold(gca,'on');
                        set(gca,'YDir','reverse','YTick',(1:n)-(1/2),'YTickLabel',[]);
                        axis(gca,'tight');
                        cmap = hot(100);
                        switch(opts.theme)
                            case 'light'
                                cmap=cmap(1:end/2,:);
                                cmap=flipud(cmap);
                                
                            case 'dark'
                                cmap=cmap(1:end/2,:);
                        end
                        colormap(gca,cmap);
                        h.("label_"+panel) = arrayfun(@(c)text(min(xlim),c,"\Xi_{"+c+"} ", ...
                            'Hori','right','Color',colors(c,:),'FontWeight','bold'),(1:n));
                        stFig.drawGridLines(gca,'y','LineWidth',3,'Color','w');
                        fig.next();

                    case {'T','A'}
                        x = obj.(panel);
                        x = squeeze(x(:,plotTractSys,1));
                        set(fig.currentAxes,'ColorOrder',opts.tractColors(plotTractSys,:));
                        h.(panel) = plot(obj.t,x); hold(fig.currentAxes,'on');

                    case {'oscM'}
                        x = obj.(panel);
                        x = squeeze(x(:,:,1));
                        set(fig.currentAxes,'ColorOrder',opts.modeColors);
                        h.(panel) = plot(obj.t,x); hold(fig.currentAxes,'on');

                    otherwise
                        x = obj.(panel);
                        switch(panel)
                            case {'M','fbM'}
                                colors = opts.modeColors;                                 
                            case {'efbG','ifbG','fbG'}
                                colors = opts.gestureColors(plotGestures,:);
                                x = x(:,plotGestures);
                            case 'E'
                                colors = excitationColors;
                            otherwise
                                colors = jet(size(x,2));
                        end
                        set(fig.currentAxes,'ColorOrder',colors);
                        h.(panel) = plot(obj.t,x); hold(fig.currentAxes,'on');
                        
                end

                switch(panel)
                    case {"G" "F" "Xi"}
                        
                        %fig.Ax(fig.CurrentAxesIx);
                    otherwise
                        axis(fig.currentAxes,'tight');
                        fig.currentAxes.YLim(1) = min(fig.currentAxes.YLim(1),0);
                        fig.currentAxes.YLim(2) = max(fig.currentAxes.YLim(2),1);
                        fig.rescaleAxes(fig.currentAxes,'y',[0 0.05]);
                        if opts.showPanelLabels
                            panelLab = "$"+obj.stateVarLabels(obj.stateVars==panel)+"$";
                            fig.labelAxes(fig.currentAxes,panelLab,"nw", ...
                                Offsets=[0.001 0],FontSize=opts.panelLabelFontSize,VerticalAlignment='top',HorizontalAlignment='left',Interpreter='latex');
                        end
                        uistack(fig.currentAxes,'bottom');
                        set(fig.currentAxes,'XGrid','on','YGrid','on');
                        fig.next();
                end
                try
                    set(h.(panel),'LineWidth',opts.lineWidth);
                catch

                end
                % mode selection and suppression happen when x_mu / the
                % feedback reach 1 (modeSelection.simulate)
                if opts.showThreshold && ismember(panel,["M" "fbM"])
                    axp = ancestor(h.(panel)(1),'axes');
                    labelArgs = {};
                    if opts.thresholdLabel~=""
                        labelArgs = {'Label',char(opts.thresholdLabel),'LabelHorizontalAlignment',char(opts.thresholdLabelAlignment), ...
                            'LabelVerticalAlignment','top','FontSize',opts.thresholdLabelFontSize, ...
                            'FontName',axp.FontName};
                    end
                    h.("threshold_"+panel) = yline(axp,1,'Color',opts.thresholdColor, ...
                        'LineStyle',opts.thresholdLineStyle,'LineWidth',opts.thresholdLineWidth,labelArgs{:});
                end
                if opts.shadeSelection && panel=="M"
                    h.shading = p.shadeSelection(ancestor(h.(panel)(1),'axes'), ...
                        alpha=opts.shadeAlpha,colors=opts.modeColors);
                end
                % label each mode, in its color, at the left edge where its
                % activation starts
                if opts.showModeLabels && panel=="M"
                    axp = ancestor(h.(panel)(1),'axes');
                    signs = repmat("+",height(obj.Modes),1);
                    signs(obj.Modes.Sign<0) = "-";
                    modeLabels = "\mu_{"+string(obj.Modes.PairNum)+"}^{"+signs+"}";
                    for k = 1:height(obj.Modes)
                        text(axp,obj.t(1),obj.M(1,k),modeLabels(k)+" ",'Interpreter','tex', ...
                            'Color',opts.modeColors(k,:),'FontSize',opts.modeLabelFontSize, ...
                            'FontWeight','bold','HorizontalAlignment','right', ...
                            'VerticalAlignment','middle','Clipping','off');
                    end
                end
            end

            % Zoom the shared time axis to where the dynamics settle,
            % rather than showing the full simulated duration (much of
            % which can be a flat tail once production is complete).
            % "Settled" is judged from the core dynamic/observable state
            % variables (mode & gestural activation, tract & articulator
            % position) rather than the internal rank/phase/feedback
            % bookkeeping variables (Xi, oscM, fbM, ...), which can keep
            % ticking over in ways that aren't meaningful here.
            settleVars = ["M" "E" "G" "T" "A"];
            activity = zeros(numel(obj.t)-1,1);
            for v = settleVars
                x = obj.(v);
                if ndims(x)==3, x = x(:,:,1); end   % T,A: position only, not velocity
                x = reshape(x,size(x,1),[]);
                m = max(abs(x(:)));
                if m>0
                    activity = activity + sum(abs(diff(x,1,1)),2)/m;
                end
            end
            lastActive = find(activity > 0.001*max(activity),1,'last');
            if ~isempty(opts.timeLim)
                set(fig.Axes,'XLim',opts.timeLim);
            elseif ~isempty(lastActive) && lastActive < 0.98*numel(activity)
                padded = min(lastActive + max(round(0.05*lastActive),20), numel(obj.t));
                set(fig.Axes,'XLim',[obj.t(1) obj.t(padded)]);
            end

            fig.formatByLoc();

            % tract-system field axes (after formatByLoc, which sets tick labels)
            if ~isempty(axF)
                if ~isempty(opts.fieldBoxLineWidth)
                    set(axF,'Box','on','LineWidth',opts.fieldBoxLineWidth);
                end
                if ~isempty(opts.fieldTickLength)
                    set(axF,'TickLength',opts.fieldTickLength*[1 1]);
                end
                if opts.timeTickFontSizeDelta~=0
                    set(axF(end),'FontSize',axF(end).FontSize+opts.timeTickFontSizeDelta);
                end
                if opts.timeLabel~=""
                    xlabel(axF(end),char(opts.timeLabel),'FontSize',opts.timeLabelFontSize);
                end
            end
            if opts.tickFontSizeDelta~=0
                for ax = findall(fig.Handle,'Type','axes')'
                    ax.FontSize = ax.FontSize + opts.tickFontSizeDelta;
                end
            end
            h.fig = fig;
        end
    end

end
