classdef mcExperimentPlot
% MCTESTPLOT  Plots over a completed mcExperiment run: final configurations,
% configuration frequencies, and state-transition graphs.
%
%   mcExperimentPlot(t).plotConfigs()
%   t.plotConfigs()                   % the usual route
%
%   Extracted from mcExperiment, which keeps only thin delegations so the test
%   harness can be read and run without the graphics code.

    properties
        Model mcExperiment        % the completed test being drawn
    end

    methods
        function p = mcExperimentPlot(model)
            if nargin > 0, p.Model = model; end
        end

        function [configPlots] = plotConfigs(p,opts)
            arguments
                p
                opts.?plotopts.ExperimentConfigs
            end
            opts = plotopts.Base.resolve(opts,plotopts.ExperimentConfigs());

            obj = p.Model;
            if obj.NumReps>1
                fprintf('WARNING: more than one rep per run, plotting first rep only\n');
            end

            fig = plotParent.layout(opts.Parent,stFig.panelLayout(height(obj.Runs),ncols=opts.ncols),...
                [0.015 0.025 0.025 0.05],[0.015 0.035],'Theme','light');

            cg = obj.Runs.configs(:,1);
            for i=1:numel(cg)
                configPlots(i) = cg(i).plotFinal(parent=fig.Axes(i));
            end

            axis(fig.Axes,'tight');
            fig.rescaleAxes([],'y',0.20);
            fig.equateAxesSizes(fig.Axes);

            arrayfun(@(c)c.optimizeSystemLabelFontSize(),configPlots);
            configPlots.finalizeLayout();

            stateLabs = arrayfun(@(c)c.FinalConfig.ToString(style='short'),cg);
            panLabs = obj.Runs.label + " " + stateLabs;
            scaledFontSize = 24-max(height(obj.Runs)-6,0);
            fig.labelAxes([],panLabs,"nwo",FontSize=scaledFontSize,Offsets=[-0.01 0]);
            modeConfig.applyStateFormat(fig.AxesLabels);
        end

        function [fig] = plotConfigFreq(p,opts)
            arguments
                p
                opts.?plotopts.ConfigFrequency
            end
            opts = plotopts.Base.resolve(opts,plotopts.ConfigFrequency());

            obj = p.Model;
            if obj.NumReps==1
                fprintf('ERROR: only one rep per run\n');
                return
            end

            if isempty(opts.ncols)
                opts.ncols = ceil(sqrt(height(obj.Runs)));
            end

            fig = plotParent.layout(opts.Parent,stFig.panelLayout(height(obj.Runs),ncols=opts.ncols),...
                [0.025 0.035 0.025 0.05],[0.015 0.035],'Theme','light','AxesHandleForm','grid');

            %consistent order if all configs are the same form
            if isscalar(unique(obj.Runs.form))

            end
            
            runs = obj.Runs;
            if ~isempty(opts.plotConfigs)
                runs = runs(opts.plotConfigs,:);
            end

            for i=1:height(runs)  
                
                finalStats = runs.runData(i).Analysis.finalStats;
                finalStats = finalStats(finalStats.prop>opts.cutoff,:);

                for j=1:height(finalStats)
                    ix = find(runs.runData(i).Traj.finalConfig==finalStats.state(j),1,'first');
                    finalStats.inspectConfig(j) = runs.configs(i,ix);
                end

                switch(opts.orientation)
                    case 'vertical'
                        bh = bar(finalStats.prop,'EdgeColor','none'); hold on;  
                        for j=1:height(finalStats)
                            th(i,j) = text(bh.XData(j),bh.YData(j),finalStats.stateLab(j),'Rotation',90);
                            if finalStats.prop(j)>0.65
                                th(i,j).HorizontalAlignment = 'right';
                            end
                        end
                    case 'horizontal'
                        bh = barh(finalStats.prop,'EdgeColor','none'); hold on;
                        for j=1:height(finalStats)
                            th(i,j) = text(bh.YData(j),bh.XData(j),finalStats.stateLab(j));
                            if finalStats.prop(j)>0.65
                                th(i,j).HorizontalAlignment = 'right';
                            end
                        end
                end
                if ismember('isTarget',tabcols(finalStats))
                    bh.FaceColor = "flat";
                    bh.CData = opts.barColors(finalStats.isTarget+1,:);
                else
                    set(bh,'FaceColor',0.75*[1 1 1]);
                end
                if opts.allowInspection
                    bh.ButtonDownFcn = @(src,event)p.inspectAction(src,event,finalStats.inspectConfig,i);
                    bh.PickableParts = 'all';
                    bh.HitTest = 'on';
                end
                fig.next();
            end
            
            set(th(ishandle(th)),'Fontsize',opts.fontSize,'FontWeight',opts.fontWeight);
            axis(fig.validAxes(),'tight');
            
            switch(opts.orientation)
                case 'vertical'
                    fig.rescaleAxes(fig.validAxes(),'xy',0.025,[0 0.25]);
                    set(fig.validAxes(),'XLim',[0 max([opts.minStates reshape([fig.validAxes().XLim],1,[])])]);
                    set(fig.validAxes(),'YTick',0:0.25:1,'XTick',[]);
                    set(fig.validAxes(),'ygrid','on');
                case 'horizontal'
                    fig.rescaleAxes(fig.validAxes(),'xy',[0 0.25],0.025);
                    set(fig.validAxes(),'YLim',[0 max([opts.minStates reshape([fig.validAxes().YLim],1,[])])]);
                    set(fig.validAxes(),'XTick',0:0.25:1,'YTick',[]);
                    set(fig.validAxes(),'xgrid','on','YDir','reverse');
            end
            if ~isempty(opts.tickFontSize)
                set(fig.validAxes(),'FontSize',opts.tickFontSize);
            end
            set(fig.validAxes(),'XLim',[0 1.01]);
            fig.equateAxesSizes(fig.Axes);
            fig.formatAxesArray();

            modeConfig.applyStateFormat(fig.Handle);
            escapeCurly = @(c)regexprep(c,'[{}]','\\$0');
            panLabs = obj.Runs.label + " " + escapeCurly(obj.Runs.target);
            if isempty(opts.panelFontSize)
                fsAdj = fontsizeForScreenWidth(max(strlength(panLabs)),1/opts.ncols);
            else
                fsAdj = opts.panelFontSize;
            end
            fig.labelAxes([],panLabs,"nwo",FontSize=fsAdj,Offsets=[0 0]);
            if isempty(opts.panelFontSize)
                fsAdj = min(fontsizeForScreenWidth(max(strlength(runs.paramLabel)),1/opts.ncols),fsAdj);
            end
            % parameter labels in LaTeX (the TeX \beta renders in the UI
            % font); converted here, so saved experiments are covered too
            paramLabs = regexprep(runs.paramLabel,'_','\\_');
            paramLabs = regexprep(paramLabs,'^\\beta=([^,]+)','$\\beta=$1$');
            fig.labelAxes([],paramLabs,"nw",FontSize=fsAdj,Offsets=[0.005 0], ...
                FontWeight='normal',Interpreter='latex');
        end

        function [] = plotGraphs(p,runInfo,opts)
            arguments
                p
                runInfo = []
                opts.?plotopts.Graphs
            end
            opts = plotopts.Base.resolve(opts,plotopts.Graphs());

            obj = p.Model;
            runs = obj.selectRuns(runInfo);

            % An explicit parent takes priority over separate-window defaults.
            switch(opts.separateFigures && isempty(opts.Parent))
                case true
                    for i=1:height(runs)
                        fresh = stFig(1);
                        h = p.plotGraph(i,fresh.Axes);
                        fig(i) = h.fig; %#ok<AGROW>
                        fig(i).setFontSize('text',opts.FontSize);
                    end
                case false
                    fig = plotParent.layout(opts.Parent,height(runs),[0 0 0 0],[0.05 0.01],Theme='light');
                    for i=1:height(runs)
                        % plotGraph indexes obj.Runs with this, so it wants
                        % the row number, not the row
                        p.plotGraph(i,fig.Axes(i),stateLabels="onNodes");
                    end
                    fig.setFontSize('text',opts.FontSize);
            end
            
        end

        function [h] = plotGraph(p,run,parent,opts)
            arguments
                p
                run
                parent = []
                opts.?plotopts.Graph
            end
            opts = plotopts.Base.resolve(opts,plotopts.Graph());

            obj = p.Model;

            Run = obj.Runs(run,:);
            A = Run.runData.Analysis;
            switch(opts.edgeWeights)
                case 'prop' %proportion of runs
                    edgeWeights = A.trans/height(Run.runData.Traj);                    
                    edgeWeights(isnan(edgeWeights)) = 0;
                case 'cumulative'
                    edgeWeights = A.trans./nansum(A.trans,2);  
                    edgeWeights = edgeWeights.*(A.stats.count/height(Run.runData.Traj));
                    edgeWeights(isnan(edgeWeights)) = 0;
                case 'forward'
                    edgeWeights = A.trans./nansum(A.trans,2);                    
                    edgeWeights(isnan(edgeWeights)) = 0;
                otherwise
                    edgeWeights = A.tr_p;
            end

            switch(opts.stateLabels)
                case 'numbered'
                    G = digraph(edgeWeights,string((1:height(A.stats)))');
                otherwise
                    G = digraph(edgeWeights,A.stats.label);
            end

            switch opts.stateLabels
                case 'numbered'
                    reps = round(100*opts.numLabelCols*opts.labelColProp);
                    fig = plotParent.layout(parent,repelem([1 2],1,[100-reps reps]), ...
                        [0 0 0 0],[0.035 0],Theme='light');
                otherwise
                    fig = plotParent.layout(parent,1,[0 0 0 0],[0 0],Theme='light');
            end
            parent = fig.Axes(1);
            axes(parent);
            
            gh = G.plot('Layout','layered','NodeLabel',[]);
            % the graph is drawn on a bare canvas: no axes lines (they show as
            % a thin gray line along the left and bottom edges)
            set(parent,'XColor','none','YColor','none','Box','off','Color','none');
            gh.EdgeColor = [0 0 0];
            switch(opts.propLineWidth)
                case true
                    gh.LineWidth = rescale(log(G.Edges.Weight),0.5,5);
                case false
                    gh.LineWidth = 1.5;
            end
            
            gh.NodeColor = [0 0 0];
            if opts.showEdgeLabels
                edgeLabels = strrep(arrayfun(@(c)string(sprintf('%.2f',c)),G.Edges.Weight),'0.','.');
                labeledge(gh,1:numedges(G),edgeLabels);
                gh.EdgeFontAngle = 'normal';
                gh.EdgeFontSize = opts.edgeFontSize;
            end

            for i=1:numel(gh.XData)
                G.Nodes.th(i) = text(gh.XData(i),gh.YData(i)," " + G.Nodes.Name{i},'FontSize',opts.nodeFontSize);
            end

            if ~isempty(opts.highlightConfigs)
                % A.stats.label is the true configuration string for node
                % i regardless of stateLabels mode ('numbered' only
                % changes what G.Nodes.th displays, not node order), so
                % match against it rather than G.Nodes.Name.
                ix = find(ismember(string(A.stats.label),opts.highlightConfigs));
                for i = ix(:)'
                    G.Nodes.th(i).FontWeight = 'bold';
                    rectangle(parent,'Position',G.Nodes.th(i).Extent, ...
                        'EdgeColor',opts.highlightColor,'LineWidth',opts.highlightLineWidth);
                end
            end

            % GraphPlot bakes its own generous, asymmetric margin into the
            % axis limits it sets (even axis('tight') doesn't remove it --
            % its reported extent includes room for arrowheads/markers).
            % Fit exactly to the node layout instead, then pad top/bottom
            % only so the topmost/bottommost nodes aren't flush against
            % the axes edge.
            xl = [min(gh.XData) max(gh.XData)];
            yl = [min(gh.YData) max(gh.YData)];
            if diff(xl)==0, xl = xl + [-0.5 0.5]; end
            if diff(yl)==0, yl = yl + [-0.5 0.5]; end
            set(parent,'XLim',xl,'YLim',yl);
            fig.rescaleAxes(parent,'y',0.05);
            fig.rescaleAxes(parent,'x',0.01);

            switch(opts.stateLabels)
                case 'numbered'
                    axes(fig.Axes(2));
                    n = height(A.stats);
                    npercol = ceil(n/opts.numLabelCols);
                    xpos = repelem(linspace(0,1,opts.numLabelCols+1),1,npercol);
                    ypos = repmat(linspace(1,(1/npercol),npercol),1,opts.numLabelCols);
                    G.Nodes.lh = arrayfun(@(c)text(xpos(c),ypos(c),c+": " + A.stats.label(c),'Verti','top'),(1:n)');
                    set(G.Nodes.lh,'FontSize',opts.statesFontSize);
                    modeConfig.applyStateFormat(G.Nodes.lh);
                    set(gca,'Visible','off');
                    axrescaley(0.01);

                otherwise
                    modeConfig.applyStateFormat(G.Nodes.th);
            end
            h.fig = fig;
            h.G = G;
            h.gh = gh;
        end        

        function [] = inspectAction(p,src,event,configs,runNum)
            switch(event.Button)
                case 1
                    switch(src.Parent.XGrid)
                        case 'on'
                            orientation = "horizontal";   % barh
                        case 'off'                    
                            orientation = "vertical";     % bar
                    end
                    switch(orientation)
                        case "horizontal"
                            clickY = event.IntersectionPoint(2);
                            [~,idx] = min(abs(src.XEndPoints - clickY)); %XEndPoints for horizontal bar graph is
                        case "vertical"
                            clickX = event.IntersectionPoint(1);
                            [~,idx] = min(abs(src.XEndPoints - clickX));
                    end
                    configs(idx).inspect();
                otherwise
                    p.plotGraph(runNum);
            end
        end        

    end

end
