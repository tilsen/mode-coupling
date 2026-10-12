classdef stGraph < handle & matlab.mixin.Copyable

    properties
        Nodes
        Edges
        Tree
        Adjacency
        Axes = [];
        AxesProps = {'equal' 'tight'}
        Visible = 'off'
        AutoCurve = true
        SepPaired = 0.015; %proportion of object radius/bounding box
        ArcCurves = pi/8;
        EdgeMargins = 0.01; %proportion of object radius/bounding box
        Annotations = gobjects(0);
        NameReps = []
        Loops
        graphViz = []
        GraphName = []
    end

    methods
        function obj = stGraph(tree,opts)
            arguments
                tree = []
                opts.anchorStyle = "closest"
                opts.nodes = []
                opts.edges = []
            end
            if isempty(tree)
                if ~isempty(opts.nodes)
                    obj.defNodes(opts.nodes);
                else
                    obj.Nodes = [];
                end
                if ~isempty(opts.edges)
                    obj.defEdges(opts.edges,anchorStyle=opts.anchorStyle);
                else
                    obj.Edges = [];
                end
            else
                obj.Tree = tree;
                obj.defNodes(tree.nodeSpec());
                obj.defEdges(tree.edgeSpec(),anchorStyle=opts.anchorStyle);
                %obj.addTreeInfo(varargin{1});
            end
        end

        function [objs] = copyGraph(obj,numCopies)
            if nargin<=1, numCopies=1; end
            if numCopies==1
                objs = copy(obj);
            else
                objs = cell(numCopies,1);
                for i=1:numCopies, objs{i} = copy(obj); end
            end
        end

        function [] = defNodes(obj,info,vars)
            if ~istable(info)
                if size(info,2)==1
                    obj.Nodes = tabfix(tabcell2str(array2table(info,'VariableNames',{'Name'})));
                elseif size(info,2)==2
                    obj.Nodes = tabfix(tabcell2str(array2table(info(:,[1 2]),'VariableNames',{'Name' 'Pos'})));
                end
            else
                obj.Nodes = info;
            end
            
            obj.sanitizeNames();
            
            for i=1:height(obj.Nodes)
                obj.Nodes.nodeObj{i} = stNode(obj.Nodes(i,:));
            end
            if size(info,2)>2 && nargin==3
                for i=1:length(vars)
                    obj.setNodeProps(obj.Nodes.Name,vars{i},vertcat(info{:,2+i}));
                end
            end
        end

        function [] = sanitizeNames(obj)
            obj.Nodes.Label = obj.Nodes.Name; %use Name for Label

            obj.Nodes.Name = regexprep(obj.Nodes.Name,'\s+','_');

            usedChars = unique(regexp(strjoin(obj.Nodes.Name,''),'[\w]','match'));
            disallowedChars = unique(regexp(strjoin(obj.Nodes.Name,''),'[^\w]','match'));

            if isempty(disallowedChars), return; end
            availableChars = setdiff(regexp(char([65:90 97:122]),'\w{1}','match'),usedChars)';
            obj.NameReps = table(disallowedChars(:),availableChars(1:numel(disallowedChars)),...
                'VariableNames',{'original','replacement'});
            %obj.Nodes.Label = obj.Nodes.Name;
            for i=1:height(obj.NameReps)
                obj.Nodes.Name = strrep(obj.Nodes.Name,obj.NameReps.original(i),obj.NameReps.replacement(i));
            end
        end

        function [] = removeLabelNumbers(obj,nodes)
            arguments
                obj
                nodes = []
            end
            if isempty(nodes)
                nodes = obj.Nodes.Name;
            end
            labels = obj.getNodeProps('Label');
            labels = labels(ismember(obj.Nodes.Name,nodes));
            labelsNoNumbers = regexprep(labels,'_\d+','');
            obj.setNodeProps(nodes,'Label',labelsNoNumbers);
        end

        function [] = layoutNodes(obj,opts)
            arguments
                obj
                opts.layout = 'hierarchy'
                opts.orientation = 'vertical'
                opts.method = 'balanced' %balanced or graphViz
                opts.anchorLevel = 1
            end
            switch(lower(opts.method))
                case 'graphviz'
                    fprintf('calculating node layout with graphViz...');
                    if ~isempty(obj.Edges)
                        gV = gvGraph(obj.Nodes,obj.Edges);
                    else
                        gV = gvGraph(obj.Nodes);
                    end
                    if ~ismember('Parent',gV.Nodes.Properties.VariableNames)
                        gV.type='auto';
                        gV.Layout = 'auto';
                    end
                    gV = gV.layoutNodes();
                    fprintf('done.\n');
                    obj.graphViz = gV;

                    obj.Nodes.x = gV.gViz.Nodes.x;
                    obj.Nodes.y = gV.gViz.Nodes.y;
                    obj.setNodeProps([],'x',obj.Nodes.x);
                    obj.setNodeProps([],'y',obj.Nodes.y);
                case 'balanced'
                    if ~ismember(obj.Nodes.Properties.VariableNames,'Level')
                        if all(isnumeric(obj.Nodes.Pos(:,2)))
                            levels = sort(unique(obj.Nodes.Pos(:,2)),'descend');
                            [~,ia] = ismember(obj.Nodes.Pos(:,2),levels);                            
                            obj.Nodes.Level = max(ia)-ia;
                        else
                            fprintf('ERROR: must specify node Level column for balanced method.\n');
                            return;
                        end
                    end
                    obj.balancedLayout(opts.anchorLevel,opts.orientation);
            end

        end

        function [] = balancedLayout(obj,anchorLevel,orientation)

            obj.Nodes.Pos = repmat([nan nan],height(obj.Nodes),1);

            switch(orientation)
                case 'horizontal'
                    layoutDim = 2;
                case 'vertical'
                    layoutDim = 1;
            end
            levelDim = setdiff(1:2,layoutDim);

            %nodes in table are ordered by level
            levels = unique(obj.Nodes.Level,'stable');
            [~,ia] = ismember(obj.Nodes.Level,levels);
            obj.Nodes.Pos(:,levelDim) = 1-(ia-1)/(max(ia-1));
            obj.Nodes.LevelId = ia;
            levelIds = unique(obj.Nodes.LevelId);


            %evenly distribute nodes on anchor level:
            ixs = find(obj.Nodes.Level==anchorLevel);
            obj.Nodes.Pos(ixs,layoutDim) = linspace(0,1,numel(ixs));

            %traverse upwards
            anchorLevelId = obj.Nodes.LevelId(ixs(1));
            level = anchorLevelId-1;
            while level >= 1
                ixs = find(obj.Nodes.LevelId==level);
                for i=1:length(ixs)
                    %get children positions
                    posch = obj.Nodes.Pos(obj.Nodes.Parent==obj.Nodes.Name(ixs(i)),layoutDim);
                    if isempty(posch)
                        obj.Nodes.Pos(ixs(i),layoutDim) = obj.Nodes.Pos(ixs(i-1),layoutDim)+0.1; %!!hack
                    else
                        obj.Nodes.Pos(ixs(i),layoutDim) = mean(posch);
                    end
                end

                level = level-1;
            end

            %traverse downwards (broken)
            level = anchorLevelId+1;
            while level <= max(levelIds)
                ixs = find(obj.Nodes.LevelId==level);
                for i=1:length(ixs)
                    %get children positions
                    posch = obj.Nodes.Pos(obj.Nodes.Parent==obj.Nodes.Name(ixs(i)),layoutDim);
                    if isempty(posch)
                        obj.Nodes.Pos(ixs(i),layoutDim) = obj.Nodes.Pos(ixs(i-1),layoutDim)+0.1; %!!hack
                    else
                        obj.Nodes.Pos(ixs(i),layoutDim) = mean(posch);
                    end
                end

                level = level+1;
            end
            obj.Nodes.x = obj.Nodes.Pos(:,1);
            obj.Nodes.y = obj.Nodes.Pos(:,2);
            obj.setNodeProps([],'x',obj.Nodes.x);
            obj.setNodeProps([],'y',obj.Nodes.y);

        end

        function [] = alignNodesByLevel(obj,alignLevel,parentLevel)
            alignNodes = string(obj.Tree.Tree.Name(obj.Tree.Tree.LevelId==alignLevel));
            for i=1:numel(alignNodes)
                targix = find(obj.Nodes.Name==alignNodes(i));
                parents = obj.Edges.Source(obj.Edges.Target==alignNodes(i));
                parents = intersect(parents,obj.Tree.Tree.Name(obj.Tree.Tree.LevelId==parentLevel));
                obj.Nodes.Pos(targix,1) = mean(obj.Nodes.Pos(ismember(obj.Nodes.Name,parents),1));
                obj.setNodeProps(alignNodes(i),'Pos',obj.Nodes.Pos(targix,:));
            end
        end

        function [] = defEdges(obj,info,vars,opts)
            arguments
                obj
                info
                vars = []
                opts.anchorStyle = "closest";
            end
            
            if ~istable(info)
                if ~isempty(obj.NameReps)
                    for i=1:height(obj.NameReps)
                        info = strrep(info,obj.NameReps.original(i),obj.NameReps.replacement(i));
                    end
                end

                obj.Edges = obj.parseInputs(info,vars);
            else
                obj.Edges = info;
            end

            if ~ismember('Anchors',tabcols(obj.Edges))
                switch(opts.anchorStyle)
                    case "closest"
                        obj.Edges.Anchors = repmat(["closest" "closest"],height(obj.Edges),1);
                    case "bottom_top"
                        obj.Edges.Anchors = repmat(["bottom" "top"],height(obj.Edges),1);
                end
            end
            for i=1:height(obj.Edges)
                obj.Edges.edgeObj{i} = stEdge(obj.Edges(i,:));
            end
        end

        function [] = defTreeProps(obj,opts)
            %efault properties for tree graphs
            arguments
                obj
                opts.Shape = 'rectangle'
                opts.Width = 0.05
                opts.Height = 0.125
                opts.EdgeColor = 'none'
                opts.FontSize = 24
                opts.Anchors = ["S" "N"];
            end
            obj.setNodeProps([],'Shape',opts.Shape,'Width',opts.Width,'Height',opts.Height, ...
                'Label',obj.Nodes.Label,'EdgeColor',opts.EdgeColor,'FontSize',opts.FontSize);
            obj.setEdgeProps([],'Anchors',opts.Anchors);            
        end

        function [] = assignAxes(obj,ax)
            obj.Axes = ax;
        end

        function [] = setNodeProps(obj,Idxs,varargin)
            if isempty(Idxs)
                Idxs = true(height(obj.Nodes),1);
            elseif isstring(Idxs)
                [~,Idxs] = ismember(Idxs,obj.Nodes.Name);
                
            end
            if islogical(Idxs)
                Idxs = find(Idxs);
            end
            for i=1:2:length(varargin)
                prop = varargin{i};
                values = varargin{i+1};
                if size(values,1)~=numel(Idxs), values = repmat(values,numel(Idxs),1); end
                for j=1:length(Idxs)
                    if Idxs(j)==0, continue; end
                    obj.setNodeProp(Idxs(j),prop,values(j,:));
                    %obj.Nodes.nodeObj{Idxs(j)} = obj.Nodes.nodeObj{Idxs(j)}.setProp(prop,values(j,:));
                end
            end
        end

        function [] = setEdgeProps(obj,Idxs,varargin)
            if isempty(Idxs)
                Idxs = true(height(obj.Edges),1);
                if ~isscalar(Idxs) | islogical(Idxs), Idxs = find(Idxs); end
            elseif isstring(Idxs)
                [Sources,Targets] = obj.parseEdgeSpecs(Idxs);
                %Idxs = ismember(obj.Edges.Source + " " + obj.Edges.Target,Sources + " " + Targets);
                Idxs = arrayfun(@(c,d)find(obj.Edges.Source + " " + obj.Edges.Target==c + " " + d),Sources,Targets);
            end            
            if isempty(Idxs), return; end
            for i=1:2:length(varargin)
                prop = varargin{i};
                values = varargin{i+1};
                if size(values,1)~=numel(Idxs), values = repmat(values,numel(Idxs),1); end
                for j=1:length(Idxs)
                    obj.setEdgeProp(Idxs(j),prop,values(j,:));
                end
            end
        end

        function [] = setEdgeProp(obj,Idx,prop,value)
            
            try
                obj.Edges.edgeObj{Idx} = obj.Edges.edgeObj{Idx}.setProp(prop,value);
                switch(prop)
                    case 'Anchors'
                        obj.Edges.Anchors(Idx,:) = value;
                end
            catch
                fprintf('failed to set edge property: %s\n',prop);
            end
        end

        function [] = setNodeProp(obj,Idx,prop,value)
            %obj.Nodes.nodeObj{Idx}.(prop) = value;
            obj.Nodes.nodeObj{Idx} = obj.Nodes.nodeObj{Idx}.setProp(prop,value);
            switch(prop)
                case 'Pos'
                    obj.Nodes.Pos(Idx,:) = value;
            end

        end

        function [] = update(obj)
            obj = obj.drawNodes();
            obj = obj.drawEdges();
        end

        function [] = plot(obj,opts)
            arguments
                obj
                opts.parent = []
                opts.axesLims = []
                opts.Clipping = "off";
            end
            if ~isempty(opts.parent)
                obj.Axes = opts.parent;
            elseif isempty(obj.Axes)
                obj.Axes = gca;
            end

            axes(obj.Axes);
            obj.drawNodes();
            for i=1:length(obj.AxesProps)
                axis(obj.AxesProps{i});
            end

            if ~isempty(opts.axesLims)
                set(obj.Axes,'XLim',opts.axesLims.Axes.XLim);
                set(obj.Axes,'YLim',opts.axesLims.Axes.YLim);
            end

            if ~isempty(obj.Edges)
                obj.getConnectionObjects();
                obj.getConnectionPoints();
                if obj.AutoCurve, obj.curveEdgePairs(); end
                obj.drawEdges();
            end
            set(obj.Axes,'Clipping',opts.Clipping);
            set(obj.Axes,'Visible',obj.Visible);
        end

        function [bh] = braceNodes(obj,names)
            for i=1:numel(names)
                ix = find(obj.Nodes.Name==names(i));
                bh = drawBracePair(obj.Nodes.nodeObj{ix}.FillHandle);
                obj.Nodes.nodeObj{ix}.FillHandle.Visible = "off";
            end        
        end

        function [] = drawNodes(obj)
            obj.Nodes = obj.Nodes;
            for i=1:height(obj.Nodes)
                n = obj.Nodes.nodeObj{i};
                obj.Nodes.nodeObj{i} = n.draw();                
            end
        end

        function [] = getConnectionObjects(obj)
            obj.Edges.sourceObj = gobjects(height(obj.Edges),1);
            obj.Edges.targetObj = gobjects(height(obj.Edges),1);
            for i=1:height(obj.Edges)
                if ismember(obj.Edges.Source(i),obj.Nodes.Name)
                    nodeObj = obj.Nodes.nodeObj{obj.Nodes.Name==obj.Edges.Source(i)};
                    switch(nodeObj.ConnectObj)
                        case 'label'
                            obj.Edges.sourceObj(i) = nodeObj.LabelHandle;
                        otherwise
                            obj.Edges.sourceObj(i) = nodeObj.FillHandle;
                    end
                else
                    fprintf('WARNING: edge source not in nodes: %s\',obj.Edges.Source(i));
                end
                if ismember(obj.Edges.Target(i),obj.Nodes.Name)
                    nodeObj = obj.Nodes.nodeObj{obj.Nodes.Name==obj.Edges.Target(i)};
                    switch(nodeObj.ConnectObj)
                        case 'label'
                            obj.Edges.targetObj(i) = nodeObj.LabelHandle;
                        otherwise
                            obj.Edges.targetObj(i) = nodeObj.FillHandle;
                    end
                else
                    fprintf('WARNING: edge target not in nodes: %s\',obj.Edges.Target(i));
                end
            end
        end

        function [] = getConnectionPoints(obj)
            for i=1:height(obj.Edges)
                Coords = obj.connectingLine(obj.Edges(i,:));
                obj.Edges.edgeObj{i}.SourceXY = Coords(1,:);
                obj.Edges.edgeObj{i}.TargetXY = Coords(2,:);
            end
        end

        function [] = drawEdges(obj)
            for i=1:height(obj.Edges)
                try
                    obj.Edges.edgeObj{i} = obj.Edges.edgeObj{i}.draw();
                catch
                    fprintf('ERROR drawing edge: %s\n',obj.Edges.edgeObj{i}.EdgeSpec);
                end
            end
        end

        function [] = identPairedEdges(obj)
            obj.Edges.Paired = false(height(obj.Edges),1);
            obj.Edges.PairId = arrayfun(@(c,d)strjoin(sort([c d]),"_"),obj.Edges.Source,obj.Edges.Target);
            for i=1:height(obj.Edges)
                if any(obj.Edges.Source==obj.Edges.Target(i) & obj.Edges.Target==obj.Edges.Source(i))
                    obj.Edges.Paired(i) = true;
                end
            end
        end

        function [] = curveEdgePairs(obj)
            obj.identPairedEdges();
            for i=1:height(obj.Edges)
                if obj.Edges.Paired(i)
                    obj.setEdgeProp(i,'CurveArc',obj.ArcCurves);
                end
            end
            pairIds = unique(obj.Edges.PairId);
            for i=1:numel(pairIds)
                ixs = find(obj.Edges.PairId==pairIds(i));
                if isscalar(ixs), continue; end
                centers = [mean([obj.Edges.sourceObj(ixs(1)).XData(:) obj.Edges.sourceObj(ixs(1)).YData(:)]);
                    mean([obj.Edges.targetObj(ixs(1)).XData(:) obj.Edges.targetObj(ixs(1)).YData(:)])];

                sourceXY = cell2mat(arrayfun(@(c){obj.getEdgeProp(obj.Edges.edgeObj{c},'SourceXY')},ixs));
                targetXY = cell2mat(arrayfun(@(c){obj.getEdgeProp(obj.Edges.edgeObj{c},'TargetXY')},ixs));

                newsourceXY = [
                    obj.rotatePoint(centers(1,:),sourceXY(1,:),obj.SepPaired*2*pi*1,-1);
                    obj.rotatePoint(centers(2,:),sourceXY(2,:),obj.SepPaired*2*pi*1,-1)];

                newtargetXY = [
                    obj.rotatePoint(centers(2,:),targetXY(1,:),obj.SepPaired*2*pi*1,1);
                    obj.rotatePoint(centers(1,:),targetXY(2,:),obj.SepPaired*2*pi*1,1)];

                for j=1:2
                    obj.Edges.edgeObj{ixs(j)} = obj.Edges.edgeObj{ixs(j)}.setProp('SourceXY',newsourceXY(j,:));
                    obj.Edges.edgeObj{ixs(j)} = obj.Edges.edgeObj{ixs(j)}.setProp('TargetXY',newtargetXY(j,:));
                end
            end
        end

        function [] = annotate(obj,objName,str,annotPos,opts)
            arguments
                obj
                objName
                str
                annotPos
                opts.FontSize = 16
                opts.Interpreter = 'tex'
            end
            gObj = obj.getObject(objName);

            switch(lower(gObj.Shape))
                case {"rectangle" "square" "box"}
                    alignment = stTextAlign.align(gObj.FillHandle,annotPos);
                    obj.Annotations(end+1) = text(nan,nan,str,'FontSize',opts.FontSize);
                    stTextAlign.setAlignProps(obj.Annotations(end),alignment);

                case "circle"
                    xy = gObj.getEdgePoint(annotPos);
                    alignment = textAlignment(annotPos);
                    obj.Annotations(end+1) = text(xy(1),xy(2),str, ...
                        'FontSize',opts.FontSize, ...
                        'HorizontalAlignment',alignment.horizontal, ...
                        'VerticalAlignment',alignment.vertical);
            end
            obj.Annotations(end).Interpreter = opts.Interpreter;
        end

        function [] = addLoop(obj,objName,angle,opts)
            arguments
                obj
                objName
                angle
                opts.LineWidth = 1
                opts.LineColor = [0 0 0]
                opts.Radius = 0.2 %proportion of object radius
                opts.ArrowLength = 16
                opts.FaceColor = [0 0 0]
                opts.EdgeColor = 'none';
                opts.Label
                opts.LabelPos = 0
                opts.FontSize = 16
            end
            gObj = obj.getObject(objName);
            objEdgePoint = gObj.getEdgePoint(angle);

            loopRadius = opts.Radius*gObj.Radius;

            th = linspace(angle,angle+2*pi,500)';
            loopXY = loopRadius*[cos(th) sin(th)];
            loopEdgePoint = loopRadius*[cos(pi+angle) sin(pi+angle)];
            shift = objEdgePoint - loopEdgePoint;
            PP = loopXY + shift;

            h = plot(PP(:,1),PP(:,2),'LineWidth',opts.LineWidth,'Color',opts.LineColor);
            basewidth = stEdge.pixelsToAxesUnits(opts.ArrowLength,gObj.FillHandle.Parent);
            headAngle = stEdge.angleFromPoints(PP(end-1,:),PP(end,:));
            [headx,heady] = stEdge.equilateralTriangleFromTip(basewidth,PP(end,:),headAngle-pi/2);
            headCenter = mean([headx' heady']);
            headShift = PP(end,:)-headCenter;
            headx = headx+headShift(1);
            heady = heady+headShift(2);

            h(end+1) = fill(headx,heady,opts.FaceColor,'EdgeColor',opts.EdgeColor);

            if ~isempty(opts.Label)
                alignment = textAlignment(rad2deg(opts.LabelPos));
                textEdgePoint = loopRadius*[cos(opts.LabelPos) sin(opts.LabelPos)] + shift;
                h(end+1) = text(textEdgePoint(1),textEdgePoint(2),opts.Label,...
                    'HorizontalAlignment',alignment.horizontal, ...
                    'VerticalAlignment',alignment.vertical, ...
                    'FontSize',opts.FontSize);
            end

            obj.Loops{end+1} = h;
        end

        function [] = toggleVisible(obj,objName)
            if numel(objName)>1
                for i=1:length(objName)
                    obj.toggleVisible(objName(i));
                end
                return;
            end
            gobj = obj.getObject(objName);
            switch(class(gobj))
                case 'stNode'
                    gobj.FillHandle.Visible = obj.toggleProp(gobj.FillHandle.Visible);
                case 'stEdge'
                    gobj.LineHandle.Visible = obj.toggleProp(gobj.LineHandle.Visible);
                    gobj.CapHandles.Visible = obj.toggleProp(gobj.CapHandles.Visible);
            end
            if ishandle(gobj.LabelHandle)
                gobj.LabelHandle.Visible = obj.toggleProp(gobj.LabelHandle.Visible);
            end
        end

        function [gobj] = getObject(obj,objName)
            %look for node
            ix = find(obj.Nodes.Name==objName);
            if ~isempty(ix)
                gobj = obj.Nodes.nodeObj{ix};
                return;
            end
            ix = find(obj.Edges.EdgeSpec==objName);
            if ~isempty(ix)
                gobj = obj.Edges.edgeObj{ix};
                return;
            end
            gobj = gobjects(0);
        end

        function [value] = getEdgeProp(~,edgeObj,prop), value = edgeObj.(prop); end
        function [values] = getEdgeProps(obj,prop)
            values = cellfun(@(c)obj.getEdgeProp(c,prop),obj.Edges.edgeObj);
        end

        function [value] = getNodeProp(~,nodeObj,prop), value = nodeObj.(prop); end
        function [values] = getNodeProps(obj,prop)
            values = cellfun(@(c)obj.getNodeProp(c,prop),obj.Nodes.nodeObj);
        end

        function Adjacency = getAdjacency(obj)
            names = unique(obj.Nodes.name,'stable');
            Adjacency = false(numel(names),numel(names));

            for a=1:length(names)
                for b=1:length(names)
                    for i=1:height(obj.Edges)
                        if obj.Edges.source(i)==names(a) && obj.Edges.target(i)==names(b)
                            Adjacency(a,b) = true;
                        end
                    end
                end
            end
        end

        function [] = removeNodes(obj,nodes,opts)
            arguments
                obj
                nodes
                opts.removeEdges = true
            end
            ixNodes = ismember(obj.Nodes.Name,nodes);
            if opts.removeEdges && ~isempty(obj.Edges)
                ixEdges = ismember(obj.Edges.Source,nodes) | ismember(obj.Edges.Target,nodes);
                obj.removeEdges(obj.Edges.EdgeSpec(ixEdges));
            end
            obj.Nodes = obj.Nodes(~ixNodes,:);
        end
        function [] = removeEdges(obj,edgeSpecs,opts)
            arguments
                obj
                edgeSpecs
                opts.removeNodes = false
            end
            ixEdges = ismember(obj.Edges.EdgeSpec,edgeSpecs);
            if opts.removeNodes
                ixNodes = ismember(obj.Nodes.Name,obj.Edges.Source(ixEdges)) | ismember(obj.Nodes.Name,obj.Edges.Target(ixEdges));
                obj.removeNodes(obj.Nodes.Name(ixNodes),removeEdges=false);
            end
            obj.Edges = obj.Edges(~ixEdges,:);
        end
        function [] = make3d(obj,opts)
            arguments
                obj
                opts.camorbit = [1 1]
                opts.camscale = 10
            end
            parent = obj.Axes;
            view(parent,0,90);
            camproj(parent,'orthographic');
            camorbit(parent,0,opts.camorbit(2),'camera');
            camorbit(parent,opts.camorbit(1),0,'camera');
            delete(findall(parent,'Type','light'));
            lobj = camlight('headlight');
            cp = campos(parent);
            ct = camtarget(parent);
            dir = cp-ct;
            dir = dir/norm(dir);
            lobj.Position = lobj.Position + opts.camscale*dir;
            camlight(parent,'right');
            lighting(parent,'gouraud');            
            for i=1:height(obj.Nodes)
                nobj = obj.Nodes.nodeObj{i};
                if nobj.NodeVisible=="off", continue; end
                switch(nobj.Shape)
                    case 'rectangle'
                        fcol = nobj.FillHandle(1).FaceColor;
                        X = nobj.FillHandle.XData;
                        Y = nobj.FillHandle.YData;
                        xx = minmax(X(:)');
                        yy = minmax(Y(:)');                        
                        Z = [-1 1]*abs(diff(xx));
                        nobj.FillHandle(1).ZData = Z(1)*ones(size(X));                        
                        nobj.FillHandle(end+1) = fill3(xx([1 2 2 1]),yy([1 1 2 2]),Z([2 2 2 2]),fcol);
                        nobj.FillHandle(end+1) = fill3(xx([1 1 1 1]),yy([1 1 2 2]),Z([1 2 2 1]),fcol);
                        nobj.FillHandle(end+1) = fill3(xx([2 2 2 2]),yy([1 1 2 2]),Z([1 2 2 1]),fcol);
                        nobj.FillHandle(end+1) = fill3(xx([1 2 2 1]),yy([2 2 2 2]),Z([1 1 2 2]),fcol);
                        nobj.FillHandle(end+1) = fill3(xx([1 2 2 1]),yy([1 1 1 1]),Z([1 1 2 2]),fcol);
                        set(nobj.FillHandle,'FaceLighting','gouraud', ...
                            'BackFaceLighting','reverselit','AmbientStrength', 0.6, ...
                            'DiffuseStrength', 0.9, ...
                            'SpecularStrength', 0.1);
                        delete(nobj.FillHandle(2));
                        
                end
                obj.Nodes.nodeObj{i} = nobj;
                
            end
    
        end
        function [hax] = nodeToAxes(obj,node,opts)
            arguments
                obj
                node
                opts.removeNode = false
                opts.visible = 'Off'
            end
            nodeObj = obj.Nodes.nodeObj{obj.Nodes.Name==node};
            points = [min(nodeObj.EdgePoints{1}); max(nodeObj.EdgePoints{1})];
            pointsnfu = [
                stFig.data2nfu(nodeObj.FillHandle.Parent,points(1,:));
                stFig.data2nfu(nodeObj.FillHandle.Parent,points(2,:))];
            pos = [pointsnfu(1,:) diff(pointsnfu)];
            hax = axes(ancestor(nodeObj.FillHandle,'figure'),'Position',pos);
            set(hax,'Visible',opts.visible);
            uistack(hax,"top"); hold(hax,"on");
            
            switch(opts.removeNode)
                case true
                    %ToDo
            end
        end
    end

    methods (Static)

        function [E] = parseInputs(info,vars)

            if any(contains(info(:,1),["-" "~" ">" "<"]))
                [E.Source,E.Target,E.Direction,ixParse] = stGraph.parseEdgeSpecs(info(:,1));
                E = tabfix(struct2table(E));
                E.EdgeSpec = E.Source + " " + E.Target;
                info = [info(:,2:end); info(ixParse(:,1),2:end)];
            else
                E.Source = info(:,1);
                E.Target = info(:,2);
                E.EdgeSpec = E.Source + " > " + E.Target;
                E = tabfix(struct2table(E));
                info = info(:,3:end);
            end
            if ~isempty(vars)
                E = [E tabfix(tabcell2str(array2table(info,'VariableNames',vars)))];
            end
        end

        function [Sources,Targets,Directions,ixParse] = parseEdgeSpecs(info)
            Sources = regexp(info,'\w+(?=\s)','match','once');
            Targets = regexp(info,'(?<=\s)\w+','match','once');
            Directions = regexp(info(:,1),'~|-|>|<','match','once');
            ixParse = Directions=="~";
            Sources = [Sources; Targets(ixParse)];
            Targets = [Targets; Sources(ixParse)];
            Directions = [Directions; Directions(ixParse)];
            ixParse = [ixParse false(numel(ixParse),1)];
            ixParse = [ixParse; [false(sum(ixParse(:,1),1),1) true(sum(ixParse(:,1)),1)]];
            Directions(Directions=="~") = "forward";
            Directions(Directions==">") = "forward";
            Directions(Directions=="<") = "backward";
            Directions(Directions=="-") = "none";
        end

        function [T] = validateProperty(T,propName,value)
            if ~ismember(propName,tabcols(T))
                switch(class(value))
                    case 'string'
                        T.(propName) = repmat("",height(T),1);
                    case {'double','single'}
                        T.(propName) = nan(height(T),1);
                end
            end
        end

        function [Coords] = connectingLine(E)

            obj1 = E.sourceObj;
            obj2 = E.targetObj;

            %get object boundaries
            objs = [obj1 obj2];
            BB = {[],[]};
            for i=1:length(objs)
                BB{i} = stGraph.getBoundaries(objs(i));
            end

            %get anchor points
            Coords = nan(2);
            for i=1:length(objs)
                switch(E.Anchors(i))
                    case 'closest'
                        j = mod(i,2)+1;
                        d = pdist2(BB{i},BB{j});
                        [r,~] = find(d==min(d(:)));

                        %multiple closest anchors fallback, include
                        %distance from object centers
                        if numel(r)>1
                            o1center = mean(BB{i});
                            o2center = mean(BB{j});
                            d = d + pdist2(BB{i},o1center) + pdist2(BB{j},o2center)';
                            [r,~] = find(d==min(d(:)));
                        end

                        Coords(i,:) = BB{i}(r(1),:);
                    otherwise
                        Coords(i,:) = stGraph.getAnchor(objs(i),E.Anchors(i));
                end
            end
        end

        % Helper function to check if angle b is between a and c (counterclockwise)
        function result = isAngleBetween(b, a, c)
            b = mod(b, 2*pi);
            a = mod(a, 2*pi);
            c = mod(c, 2*pi);
            if a < c
                result = (a < b) && (b < c);
            else
                result = (a < b) || (b < c);
            end
        end

        function p_rot = rotatePoint(center, p, angle, direction)
            % Rotate point p around center by angle (in radians) and direction
            %
            % Inputs:
            %   center    : [xc, yc] - center of the circle
            %   p         : [x, y]   - point to rotate
            %   angle     : angle in radians (positive scalar)
            %   direction : -1 for counterclockwise, +1 for clockwise
            %
            % Output:
            %   p_rot     : [x', y'] - rotated point

            % Validate direction
            if ~ismember(direction, [-1, 1])
                error('Direction must be either -1 (CCW) or 1 (CW)');
            end

            % Convert to column vectors
            center = center(:);
            p = p(:);

            % Vector from center to point
            v = p - center;

            % Apply direction to angle
            a = direction * angle;

            % Rotation matrix
            R = [cos(a), -sin(a);
                sin(a),  cos(a)];

            % Rotate and return
            p_rot = center + R * v;
            p_rot = p_rot.';  % row vector
        end

        function [newVal] = toggleProp(oldVal)
            switch(oldVal)
                case 'on'
                    newVal = 'off';
                case 'off'
                    newVal = 'on';
                case true
                    newVal = false;
                case fase
                    newVal = true;
            end
        end

        function [xo,yo] = getObjOverlap(obj1,obj2)
            [x1_cw, y1_cw] = poly2cw(obj1.XData, obj1.YData);
            [x2_cw, y2_cw] = poly2cw(obj2.XData, obj2.YData);

            [xo, yo] = polybool('intersection', x1_cw, y1_cw, x2_cw, y2_cw);
        end

        function [bounds] = getBoundaries(obj)
            np = 100;
            box2pnts = @(xx,yy)[linspace(xx(1),xx(2),np) xx(2)*ones(1,np) linspace(xx(2),xx(1),np) xx(1)*ones(1,np);...
                yy(1)*ones(1,np) linspace(yy(1),yy(2),np) yy(2)*ones(1,np) linspace(yy(2),yy(1),np)];
            switch(obj.Type)
                case 'patch'
                    bounds = [obj.XData(:) obj.YData(:)];
                case 'text'
                    xx = [obj.Extent(1) sum(obj.Extent([1 3]))];
                    yy = [obj.Extent(2) sum(obj.Extent([2 4]))];
                    bounds = box2pnts(xx,yy)';
                case 'axes'
                    xx = [obj.Position(1) sum(obj.Position([1 3]))];
                    yy = [obj.Position(2) sum(obj.Position([2 4]))];
                    bounds = box2pnts(xx,yy)';
            end
        end

        function [anchorPoint] = getAnchor(obj,anchor)
            bounds = stGraph.getBoundaries(obj);            
            switch(lower(anchor))
                case 'center'
                    anchorPoint = mean(bounds); %#ok<*UDIM>
                case {'n','top'}
                    anchorPoint = [mean(bounds(:,1)) max(bounds(:,2))];
                case {'ne','topr'}
                    anchorPoint = [max(bounds(:,1)) max(bounds(:,2))];
                case {'nw','topl'}
                    anchorPoint = [min(bounds(:,1)) max(bounds(:,2))];
                case {'s','bot','bottom'}
                    anchorPoint = [mean(bounds(:,1)) min(bounds(:,2))];
                case {'se','botr'}
                    anchorPoint = [max(bounds(:,1)) min(bounds(:,2))];
                case {'sw','botl'}
                    anchorPoint = [min(bounds(:,1)) min(bounds(:,2))];
                case {'e','r','right'}
                    anchorPoint = [max(bounds(:,1)) mean(bounds(:,2))];
                case {'w','l','left'}
                    anchorPoint = [min(bounds(:,1)) mean(bounds(:,2))];
            end
        end
        
    end
end