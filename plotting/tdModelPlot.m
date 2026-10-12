classdef tdModelPlot
% TDMODELPLOT  Plots of a simulated tdModel: score, tract systems,
% tract fields, effectors and the articulatory Jacobian.
%
%   tdModelPlot(td).plotTractSystems()
%   td.plotTractSystems()             % the usual route
%
%   Extracted from tdModel, which keeps only thin delegations so the
%   model can be read and run without the graphics code.

    properties
        Model tdModel       % the simulated model being drawn
    end

    methods
        function p = tdModelPlot(model)
            if nargin > 0, p.Model = model; end
        end

        function sc = plotScore(p,opts)
            % Accept the gestScore.plot options plus activation LineWidth.
            arguments
                p
                opts.?plotopts.ActivationScore
            end
            opts = plotopts.Base.resolve(opts,plotopts.ActivationScore());

            obj = p.Model;
            opts.parent = plotParent.axes(opts.parent);
            g = obj.Score;
            g.name = strrep(g.Gesture,'_',' ');
            sc = gestScore(g);
            [ix,ia] = ismember(sc.Score.Gesture,obj.G.Name);
            sc.Score.activation(ix,:) = obj.G.X(ia(ix),:);
            sc.tspan = obj.tspan;

            scoreOpts = rmfield(opts,{'LineWidth','ShowActivation'});
            args = namedargs2cell(scoreOpts);
            sc = sc.plot(args{:});

            sc.Score.lineh = gobjects(height(sc.Score),1);
            if opts.ShowActivation
                for i = find(isgraphics(sc.Score.fillHandle))'
                    ix = find(obj.G.Name==sc.Score.Gesture(i));
                    y = obj.G.X(ix,:).*abs(diff(sc.Score.ypos(i,:))) + min(sc.Score.ypos(i,:));
                    sc.Score.lineh(i) = plot(opts.parent,obj.t,y, ...
                        'Color',sc.Score.color(i,:),'LineWidth',opts.LineWidth);
                end
            end
            labels = sc.Score.textHandle(isgraphics(sc.Score.textHandle));
            if ~isempty(labels), uistack(labels,'top'); end
        end

        function tract = plotTractSystems(p,tractNames,opts)
            arguments
                p
                tractNames = []
                opts.?plotopts.TractSystems
            end
            opts = plotopts.Base.resolve(opts,plotopts.TractSystems());

            obj = p.Model;

            if ~ismember('color',tabcols(obj.T))
                obj.T.color = viridis(height(obj.T));
            end

            if isempty(tractNames)                
                if ~opts.plotInactive
                    tractNames = obj.T.Name(any(obj.G2T .* ismember(obj.G.Name,obj.Score.Gesture),1));                                         
                else
                    tractNames = obj.T.Name;
                end
            end
            
            opts.parent = plotParent.axes(opts.parent);

            tract = obj.T(ismember(obj.T.Name,tractNames),:);
            tractSys = obj.TractSystems(ismember([obj.TractSystems.Name],tractNames));

            hold(opts.parent,'on');
            
            for i=1:height(tract)
                switch(opts.state)
                    case 'pos'
                        tract.lineh(i) = plot(opts.parent,obj.t,squeeze(tract.X(i,:,1)),'Color',tract.color(i,:)); hold(opts.parent,'on');
                    case 'vel'
                        tract.lineh(i) = plot(opts.parent,obj.t,squeeze(tract.X(i,:,2)),'Color',tract.color(i,:)); hold(opts.parent,'on');
                    case 'both'
                        tract.lineh(i,:) = plot(opts.parent,obj.t,squeeze(tract.X(i,:,:)),'Color',tract.color(i,:)); hold(opts.parent,'on');
                end
            end
            set(tract.lineh,'LineWidth',opts.LineWidth);
            set(opts.parent,'YLim',minmax([tractSys.Dims]));

        end     

        function tract = plotTractField(p,tractName,opts)
            arguments
                p
                tractName
                opts.?plotopts.TractField
            end
            opts = plotopts.Base.resolve(opts,plotopts.TractField());

            obj = p.Model;

            % the force field only exists after a field-mode simulation;
            % without this the failure is an opaque "Unrecognized table
            % variable name 'F'" from the indexing below
            if ~ismember('F',tabcols(obj.T))
                error('tdModelPlot:noTractField', ...
                    ['plotTractField needs a field-mode simulation: the tract table ' ...
                     'carries no force field F.\nConstruct the model with ' ...
                     'tdModel(...,tractMode="field") and re-run simulate() ' ...
                     '(current tract mode: "%s").'],obj.TractMode);
            end

            opts.parent = plotParent.axes(opts.parent);

            tract = obj.T(ismember(obj.T.Name,tractName),:);
            tractSys = obj.TractSystems(ismember([obj.TractSystems.Name],tractName));

            hold(opts.parent,'on'); 
            tract.imh = imagesc(opts.parent,obj.t,tractSys.Field,squeeze(tract.F)');

            switch(opts.colormap)
                otherwise
                    cmap = eval([opts.colormap '(256);']);
            end

            axis(opts.parent,'tight');
            colormap(opts.parent,cmap);
            clim(opts.parent,minmax([0 1 tract.F(:)']));
            
            tract.lh = plot(opts.parent,obj.t,tract.Target,':','color',opts.Color,'LineWidth',opts.LineWidth);
            if opts.showTractState
                tract.sh = plot(opts.parent,obj.t,squeeze(tract.X(1,:,1)),'-','color',opts.Color,'LineWidth',opts.LineWidth);
            end
            if opts.showLabel
                tract.ylabh = ylabel(opts.parent,tract.Name,'Rotation',0,'HorizontalAlignment','right');
            end
        end

        function eff = plotEffectors(p,name,opts)
            arguments
                p
                name = []
                opts.?plotopts.TractSystems
            end
            opts = plotopts.Base.resolve(opts,plotopts.TractSystems());

            obj = p.Model;

            % effectors carry no color of their own until something assigns
            % one, so give them the same default treatment plotTractSystems
            % gives tract systems. Set before the per-name recursion below so
            % every branch sees the same colors.
            if ~ismember('color',tabcols(obj.E))
                obj.E.color = viridis(height(obj.E));
            end

            if isempty(name)
                if ~opts.plotInactive
                    activeTractSys = obj.T.Name(any(obj.G2T .* ismember(obj.G.Name,obj.Score.Gesture),1));
                    name = obj.E.Name(any(obj.TractToEffector .* ismember(obj.T.Name,activeTractSys),1));
                else
                    name = obj.E.Name;
                end
            end
            
            if numel(name)>1
                eff=[];
                f = fieldnames(opts);
                inputs = {};
                for i=1:numel(f)
                    inputs{end+1} = f{i};
                    inputs{end+1} = opts.(f{i});
                end
                for i=1:length(name)
                    eff = [eff; obj.plotEffectors(name(i),inputs{:})];
                end
                return;
            end

            opts.parent = plotParent.axes(opts.parent);

            eff = obj.E(obj.E.Name==name,:);
            effector = obj.Effectors([obj.Effectors.Name]==name);
            
            switch(opts.state)
                case 'pos'
                    eff.lineh = plot(opts.parent,obj.t,squeeze(eff.X(1,:,1)),'Color',eff.color);
                case 'vel'
                    eff.lineh = plot(opts.parent,obj.t,squeeze(eff.X(1,:,2)),'Color',eff.color);
                case 'both'
                    eff.lineh = plot(opts.parent,obj.t,squeeze(eff.X(1,:,:)),'Color',eff.color);
            end
            set(eff.lineh,'LineWidth',opts.LineWidth);
            set(opts.parent,'YLim',effector.Dims);

        end 

        function [h] = plotJacobian(p,opts)
            arguments
                p
                opts.?plotopts.Jacobian
            end
            opts = plotopts.Base.resolve(opts,plotopts.Jacobian());

            obj = p.Model;
            opts.parent = plotParent.axes(opts.parent);
            Ji = obj.TractToEffector;
            Jf = Ji';
            switch(opts.inverse)
                case true
                    data = Ji;
                    ylabs = [obj.TractSystems.Name];
                    xlabs = [obj.Effectors.Name];
                case false
                    data = Jf;
                    xlabs = [obj.TractSystems.Name];
                    ylabs = [obj.Effectors.Name];
            end
            m = stMatrixPlot(data,XLabels=xlabs,YLabels=ylabs);
            m.Colormap = ST_colormap(101,[1 0 0],[1 1 1],[0 0 1]);
            h = m.plot(Parent=opts.parent,HideValues=0);
        end

    end

end
