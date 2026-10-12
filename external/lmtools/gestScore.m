classdef gestScore
    
    properties
        Score
        FontSize = 16
        tspan
    end

    methods
        function obj = gestScore(data)
            if nargin==0, obj.Score=[]; return; end
            if ismember('Gesture',tabcols(data)) && ~ismember('name',tabcols(data))
                data.name=data.Gesture;
            end
            obj.Score = data;
            if ismember('tspan',tabcols(data))
                obj.tspan = [min(data.tspan(:,1)) max(data.tspan(:,2))];
            end
            obj = obj.defTiers();
            obj = obj.defColors();
            obj.Score.label = obj.Score.name;
        end

        function [obj] = replaceLabels(obj,varargin)
            obj.Score.label = mregexprep(obj.Score.label,varargin{:});            
        end

        function [obj] = assignTiers(obj,varargin)
            for i=1:2:numel(varargin)
                obj.Score.tierOrder(obj.Score.name==varargin{i}) = varargin{i+1};
            end
        end

        function [obj] = plot(obj,opts)
            arguments
                obj
                opts.?plotopts.Score
            end
            opts = plotopts.Base.resolve(opts,plotopts.Score());

            if isempty(opts.fontSize), opts.fontSize = obj.FontSize; end
            if ~colExists(obj.Score,'activation')
                opts.fillByActivation = false;
            end

            if isempty(opts.plotTiers)
                opts.plotTiers = unique(obj.Score.tierOrder);
            end
            opts.parent = plotParent.axes(opts.parent);
            if isempty(opts.intHeight)
                intHeight = opts.tierHeight*opts.intHeightProp;
            else
                intHeight = opts.intHeight;
            end
            obj.Score.ypos = cell2mat(arrayfun(@(c){opts.tierHeight*mean((c-[1 0]))+[-intHeight/2 intHeight/2]},obj.Score.tierOrder));

            switch(opts.yDir)
                case 'up'
                    obj.Score.ypos = opts.tierHeight*max(obj.Score.tierOrder)-obj.Score.ypos;
                case 'reverse'
                    obj.Score.ypos = -obj.Score.ypos;
            end

            obj.Score.ypos = obj.Score.ypos + opts.yOffset;

            switch(opts.labelPos)
                case 'begin'
                    tx = obj.Score.tspan(:,1);
                    ta = 'left';
                    ts = " " + obj.Score.label;
                case 'center'
                    tx = mean(obj.Score.tspan,2);
                    ta = 'center';
                    ts = obj.Score.label;
            end

            selected = ismember(obj.Score.tierOrder,opts.plotTiers);
            obj.Score.fillHandle = gobjects(height(obj.Score),1);
            obj.Score.textHandle = gobjects(height(obj.Score),1);
            hold(opts.parent,'on');
            for i=find(selected)'
                switch(opts.fillByActivation)
                    case true
                        xx = linspace(obj.tspan(1),obj.tspan(2),size(obj.Score.activation,2));
                        yy = intHeight*[obj.Score.activation(i,:) zeros(size(xx))] + min(obj.Score.ypos(i,:));
                        xx = [xx fliplr(xx)];

                        obj.Score.fillHandle(i) = fill(xx,yy,...
                            obj.Score.color(i,:),'FaceAlpha',opts.faceAlpha,'EdgeColor',opts.edgeColor,'Parent',opts.parent);
                        obj.Score.textHandle(i) = text(tx(i),mean(obj.Score.ypos(i,:)),...
                            ts(i),'verticalAlignment','middle', 'HorizontalAlignment',ta,...
                            'fontSize',opts.fontSize,'Parent',opts.parent);                        
                    case false
                        obj.Score.fillHandle(i) = fill(obj.Score.tspan(i,[1 2 2 1]),obj.Score.ypos(i,[1 1 2 2]),...
                            obj.Score.color(i,:),'FaceAlpha',opts.faceAlpha,'EdgeColor',opts.edgeColor,'Parent',opts.parent);
                        obj.Score.textHandle(i) = text(tx(i),mean(obj.Score.ypos(i,:)),...
                            ts(i),'verticalAlignment','middle', 'Hori',ta,...
                            'fontSize',opts.fontSize,'Parent',opts.parent);
                end
            end
            set(opts.parent,'YDir','normal','YTick',[]);
            if opts.tierLabels
                [~,rows] = unique(obj.Score.tierOrder(selected),'stable');
                selectedRows = find(selected);
                rows = selectedRows(rows);
                [positions,order] = sort(mean(obj.Score.ypos(rows,:),2));
                set(opts.parent,'YTick',positions,'YTickLabel',obj.Score.tier(rows(order)), ...
                    'FontSize',opts.fontSize);
            end
            if any(selected), uistack(obj.Score.textHandle(selected),"top"); end
            obj.tspan = [0 max(obj.Score.tspan(:,2))];
        end

        function [obj] = defColors(obj,colorFcn)
            arguments
                obj                 
                colorFcn = @(n)lines(n)
            end
            if ismember('Color',tabcols(obj.Score))
                obj.Score.color=obj.Score.Color; obj.Score.Color=[];
            end
            if ismember('color',tabcols(obj.Score)), return; end
            [~,~,ic] = unique(obj.Score.tierOrder,'stable');
            colors = colorFcn(numel(unique(obj.Score.tierOrder)));
            obj.Score.color = colors(ic,:);
        end

        function [obj] = defTiers(obj)
            if ~ismember('tier',tabcols(obj.Score))
                obj.Score.tier = regexp(obj.Score.name,'^\w+(?<=\s?)','match','once');
            end
            if ~ismember('tierOrder',tabcols(obj.Score))
                [~,~,obj.Score.tierOrder] = unique(obj.Score.tier,'stable');
            end
        end        
    end
end