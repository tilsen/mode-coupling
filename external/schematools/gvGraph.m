classdef gvGraph

    properties
        Nodes
        Edges = []
        Adjacency        
        gViz
        dotStr
        dotFile = 'tmp.dot';
        graphFile = 'tmp.txt';
        engine = 'dot';
        minXY
        dpi = 72;        
        type = 'tree'
        ordering = 'hierarchy'
        orientation = 'vertical'
        Layout = 'TB';
        refLevel = 1
        extend = true
        branchAngle = nan        
    end

    methods
        function obj = gvGraph(Nodes,Edges)
            obj.Nodes = Nodes;
            if nargin==1
                obj = obj.inferEdges(); 
            else
                obj.Edges = Edges;
            end
        end

        function [obj] = inferEdges(obj)
            edges = [];
            for i=1:height(obj.Nodes)
                if obj.Nodes.Parent(i)=="", continue; end
                edges(end+1,1).Source = obj.Nodes.Parent(i);
                edges(end).Target = obj.Nodes.Name(i);
            end
            obj.Edges = struct2table(edges);
        end

        % function obj = getGraphViz(obj)
        %     obj = obj.genDot();
        %     obj = obj.genGraphViz();
        %     obj.Nodes.x = obj.gViz.Nodes.x;
        %     obj.Nodes.y = obj.gViz.Nodes.y;
        %     obj.Edges.xcoords = obj.gViz.Edges.xcoords;
        %     obj.Edges.ycoords = obj.gViz.Edges.ycoords;
        % end

        function [obj] = genGraphViz(obj)

            if ~contains(obj.dotFile,filesep)
                obj.dotFile = [pwd filesep obj.dotFile];
            end

            if ~contains(obj.graphFile,filesep)
                obj.graphFile = [pwd filesep obj.graphFile];
            end

            obj.dotStr = regexprep(obj.dotStr,'\','\\\');

            writelines(obj.dotStr,obj.dotFile);
            
            [status,result] = system([obj.engine ' -n -Tplain ' obj.dotFile ' -o ' obj.graphFile]);

            if contains(result,'Error') || status~=0
                fprintf('%s',result);
                gV = [];
            else
                gV = obj.readGraphViz(obj.graphFile);
            end

            gV.result = result;
            gV.Nodes.x = gV.Nodes.x/max(gV.Nodes.x);
            gV.Nodes.y = gV.Nodes.y/max(gV.Nodes.y);
            obj.gViz = gV;
        end

        function [obj] = layoutNodes(obj)
            switch(obj.type)
                case 'tree'
                    obj = obj.genTreeGraph();
                case 'fixed'
                    obj = obj.getFixedGraph();
                otherwise
                    obj = obj.genDot();
                    obj = obj.genGraphViz();
                    obj.Nodes.x = obj.gViz.Nodes.x;
                    obj.Nodes.y = obj.gViz.Nodes.y;
                    obj.Edges.xcoords = obj.gViz.Edges.xcoords;
                    obj.Edges.ycoords = obj.gViz.Edges.ycoords;                    
            end

            if ~all(isnumeric(obj.Nodes.x))
                fprintf('ERROR in graph construction\n');
            end
        end

        function [obj] = genTreeGraph(obj)

            ix = ismember(obj.Nodes.Parent,obj.Nodes.Name);
            ix(obj.Nodes.Parent=="") = true;
            if any(~ix)
                fprintf('ERROR: unknown parents: %s\n',strjoin(obj.Nodes.Parent(~ix)));
                return;
            end

            switch(obj.orientation)
                case {'vert','vertical'}
                    lvar = 'y'; fvar = 'x';
                case {'horz','horizontal'}
                    lvar = 'x'; fvar = 'y';
                otherwise
                    lvar = 'y'; fvar = 'x';
            end

            %%
            %determine ids and y positions from level names
            [~,ia] = ismember(obj.Nodes.Level,unique(obj.Nodes.Level,'stable'));
            obj.Nodes.levelId = max(ia)-ia+1;

            %order each level according to parent order with stable order for ties:            
            obj = obj.orderTree();
            obj.Nodes.(lvar) = (obj.Nodes.levelId-1)/(max(obj.Nodes.levelId)-1);
            obj.Nodes.(fvar) = nan(height(obj.Nodes),1);

            obj = obj.genDot();
            obj = obj.genGraphViz();
           
            obj.gViz.Nodes = obj.gViz.Nodes(~contains(obj.gViz.Nodes.Name,'_ext'),:);

            if ~all(isnumeric([obj.gViz.Nodes.x obj.gViz.Nodes.y]),'all')
                fprintf('ERROR in graph construction\n');
            end

        end

        function [obj] = redistributeNodes(obj)

            N = obj.Nodes;
            E = obj.Edges;

            switch(obj.orientation)
                case 'horizontal'
                    lvar = 'x';
                    dvar = 'y';
                otherwise
                    lvar = 'y';
                    dvar = 'x';
            end

            [~,N.level] = ismember(N.(lvar),unique(N.(lvar)));

            %distribute nodes on the reference level equally:
            N.(dvar)(N.Level==obj.refLevel) = linspace(0,1,sum(N.Level==obj.refLevel));

            %distribute upwards
            for i=(opts.refLevel+1):max(N.level)
                nodeIxs = find(N.level==i);
                for j=1:length(nodeIxs)
                    ch = find(ismember(N.Name,E.end(E.start==N.Name(nodeIxs(j)))));
                    N.x(nodeIxs(j)) = mean(N.x(ch));
                end
            end

            %distribute downwards
            for i=(opts.refLevel-1):-1:1
                parents = find(N.level==i+1);

                parentsx = N.x(parents);
                spacing = mean(diff(parentsx))/3;

                for j=1:length(parents)
                    ch = E.end(E.start==N.Name(parents(j)));
                    ch = find(ismember(N.Name,ch));

                    parentx = N.x(parents(j));
                    if isscalar(parents)
                        if isscalar(ch)
                            N.x(ch) = parentx;
                        else
                            N.x(ch) = linspace(parentx-spacing,parentx+spacing,numel(ch));
                        end
                    else
                        if isscalar(ch)
                            N.x(ch) = parentx;
                        else
                            N.x(ch) = linspace(parentx-spacing,parentx+spacing,numel(ch));
                        end
                    end
                end
            end


            G.Nodes = N;
            G.Edges = E;



        end

        function [obj] = orderTree(obj,opts)

            arguments
                obj
                opts.ordering = 'hierarchical'
                opts.extend = true
            end

            T = obj.Nodes(:,{'Name' 'Parent' 'Level' 'levelId'});
            chIxs = @(c,tree)tree.Parent==c;
            parIxs = @(c,tree)ismember(tree.Name,tree.Parent(tree.Name==c));

            %add null nodes for terminals not at base
            if opts.extend
                for i=1:height(T)
                    if T.levelId(i)==1, continue; end
                    chix = chIxs(T.Name(i),T);
                    if ~any(chix)
                        tx = cell2table({T.Name(i) + "_ext", T.Name(i), "", T.levelId(i)-1},...
                            'VariableNames',tabcols(T));
                        T = [T(1:i,:); tx; T(i+1:end,:)];
                    end
                end
            end

            T = sortrows(T,{'levelId'},{'descend'});

            %reorder tree
            T.levelOrder = zeros(height(T),1);
            switch(opts.ordering)
                case 'reference'
                    !! not finished
                    T.levelOrder(T.levelId==opts.refLevel) = 1:sum(T.levelId==opts.refLevel);
                    for i=opts.refLevel:max(T.levelId)-1
                        nodes = unique(T.name(T.levelId==i),'stable');
                        parents = cellfun(@(c){T.name(parIxs(c,T))},nodes);

                        if isempty(parents), continue; end
                        c=1;
                        for j=1:length(parents)
                            ixs = find(T.name==parents{j});
                            for k=1:numel(ixs)
                                if T.levelOrder(ixs(k))==0
                                    T.levelOrder(ixs(k))=c;
                                    c=c+1;
                                end
                            end
                        end

                        T = sortrows(T,{'levelId','levelOrder'},{'descend' 'ascend'});
                    end

                case 'input'

                case 'hierarchy'
                    c = max(T.levelId)-1;
                    ixs = T.levelId==c;
                    T.levelOrder(ixs) = 1:sum(ixs);
                    T = sortrows(T,{'levelId','levelOrder'},{'descend' 'ascend'});
                    while c>0
                        parents = T.Name(T.levelId==c);
                        children = arrayfun(@(c){find(T.parent==c)},parents);
                        children = vertcat(children{:});
                        T.levelOrder(children) = 1:sum(numel(children));
                        T = sortrows(T,{'levelId','levelOrder'},{'descend' 'ascend'});
                        c=c-1;
                    end

            end
            obj.Nodes = T;
        end

        function [obj] = genDot(obj,opts)

            arguments
                obj
                opts.Layout = 'Fixed';
                opts.Size = [1 1];
                opts.Ratio = 'auto';
                opts.Dpi = obj.dpi;
                opts.nodeWidth = 0;
                opts.nodeHeight = 0;
                opts.fixedsize = false;
                opts.margin = 0;
                opts.boundingBoxMargins = [1 1];
                opts.headport = 'c';
                opts.tailport = 'c';
            end

            headerStr = obj.genHeaderStr(opts);

            %shift to avoid negative values
            if all(ismember({'x' 'y'},obj.Nodes.Properties.VariableNames))
                obj.minXY = min([obj.Nodes.x obj.Nodes.y]);
                obj.Nodes.x = obj.Nodes.x - obj.minXY(1);
                obj.Nodes.y = obj.Nodes.y - obj.minXY(2);
            end
            nodesStr = obj.genNodesStr();

            if ~isempty(obj.Edges)
                edgesStr = obj.genEdgesStr();
            else
                edgesStr = "";
            end

            str = [headerStr; nodesStr(:); edgesStr(:); "}"];
            obj.dotStr = dotInchesToPoints(str,obj.dpi);
        end

        function [obj] = identPairedEdges(obj)
            for i=1:height(obj.Edges)
                if any(obj.Edges.Source==obj.Edges.Target(i) & obj.Edges.Target==obj.Edges.Source(i))
                    obj.Edges.paired(i) = true;
                end
            end
        end

        function [obj] = getEdgeAngles(obj)
            for i=1:height(obj.Edges)
                source_xy = [obj.Nodes.x(obj.Nodes.name==obj.Edges.Source(i)) obj.Nodes.y(obj.Nodes.name==obj.Edges.Source(i))];
                target_xy = [obj.Nodes.x(obj.Nodes.name==obj.Edges.Target(i)) obj.Nodes.y(obj.Nodes.name==obj.Edges.Target(i))];
                obj.Edges.angle(i) = atan2(target_xy(2)-source_xy(2),target_xy(1)-source_xy(1));
            end
        end

        function [obj] = setPorts(obj)
            %find pairs in both directions
            for i=1:height(obj.Edges)
                a = rad2deg(obj.Edges.angle(i));
                switch(octant(a))
                    case 0
                        obj.Edges.headport(i) = "e";
                        obj.Edges.tailport(i) = "w";
                    case 1
                        obj.Edges.headport(i) = "se";
                        obj.Edges.tailport(i) = "nw";
                    case 2
                        obj.Edges.headport(i) = "s"; %
                        obj.Edges.tailport(i) = "n";
                    case 3
                        obj.Edges.headport(i) = "sw";
                        obj.Edges.tailport(i) = "ne";
                    case 4
                        obj.Edges.headport(i) = "w";
                        obj.Edges.tailport(i) = "e";
                    case 5
                        obj.Edges.headport(i) = "nw";
                        obj.Edges.tailport(i) = "se";
                    case 6
                        obj.Edges.headport(i) = "n";
                        obj.Edges.tailport(i) = "s"; %
                    case 7
                        obj.Edges.headport(i) = "ne";
                        obj.Edges.tailport(i) = "se";
                end
            end
        end

        function [str] = genHeaderStr(~,opts)
            str = "digraph G {";

            switch(opts.Layout)
                case 'TB'
                    layoutStr = '';
                    ratioStr = ['ratio=' opts.Ratio];
                    sizeStr = sprintf('size="%1.2f,%1.2f"',opts.Size(1),opts.Size(2));
                case 'Fixed'
                    layoutStr = 'splines=true, start=regular';
                    %bb = [min(G.Nodes.pos)-opts.boundingBoxMargins(1) max(G.Nodes.pos)+opts.boundingBoxMargins(2)];
                    %layoutStr = [layoutStr ', bb="' char(strjoin(string(bb),',')) '"'];
                    ratioStr = '';
                    sizeStr = '';
            end

            dpiStr = sprintf('dpi=%d',opts.Dpi);
            graphStrs = {layoutStr,sizeStr,ratioStr,dpiStr};
            graphStrs = nempt(graphStrs);
            str(end+1,1) = string(['graph [' strjoin(graphStrs,', ') '];']);

            %nodeSizeStr = sprintf('width=%1.5f, height=%1.5f',opts.nodeWidth,opts.nodeHeight);
            marginStr = sprintf('margin=%1.2f',opts.margin);
            nodeStrs = {marginStr,'shape=point','style=invis'};
            str(end+1) = string(['node [' strjoin(nodeStrs,',') '];']);

            str(end+1) = "edge [overlap=false arrowhead=none penwidth=0 style=invisible headclip=false tailclip=false];";

        end

        function [str] = genNodesStr(obj)
            str="";
            for i=1:height(obj.Nodes)
                str(end+1,1) = obj.genNode(obj.Nodes(i,:));
            end
            switch(obj.Layout)
                case "TB"
                    levels = unique(obj.Nodes.levelId);
                    for i=1:length(levels)
                        str(end+1) = "{ rank = same; " + strjoin(obj.Nodes.Name(obj.Nodes.levelId==levels(i)),"; ") + "}";
                    end
                otherwise
            end
        end

        function [str] = genNode(obj,N)
            switch(obj.Layout)
                case "TB"
                    str = sprintf('%s;',N.Name{1});
                case 'auto'
                    str = sprintf('%s;',N.Name{1});
                otherwise                    
                    str = sprintf('%s [pos="%f,%f!",width=%f,height=%f,fixedsize=true];',...
                        N.Name{1},N.x,N.y,N.radius,N.radius);
            end
        end

        function [str] = genEdgesStr(obj)
            str = "";
            for i=1:height(obj.Edges)
                str(end+1,1) = obj.genEdge(obj.Edges(i,:));
            end
        end

        function [str] = genEdge(~,E)
            str = E.Source + " -> " + E.Target;
            % %{ + ...
            %     " [minlen=2, constraint=false, overlap=false, headport=" + E.headport + ...
            %     ", tailport=" + E.tailport + ", headclip=false, tailclip=false];"; 
            %     % }
        end

        function Adjacency = getAdjacency(obj)
            names = unique(obj.Nodes.name,'stable');
            Adjacency = false(numel(names),numel(names));

            for a=1:length(names)
                for b=1:length(names)
                    for i=1:height(obj.Edges)
                        if obj.Edges.Source(i)==names(a) && obj.Edges.Target(i)==names(b)
                            Adjacency(a,b) = true;
                        end
                    end
                end
            end
        end

        function [G] = readGraphViz(~,filename)

            X = readlines(filename);

            nodeFields = {'Name','x','y','width','height','label','style','shape','stroke_color','fill_color'};
            edgeFields = {'start' 'end' 'n' 'style' 'color' 'xcoords' 'ycoords'};
            G.Nodes = [];
            G.Edges = [];
            for i=1:height(X)
                strs = regexp(X(i),'\s','split');
                switch(strs{1})
                    case 'node'
                        G.Nodes = [G.Nodes; array2table(strs(2:end),'VariableNames',nodeFields)];
                    case 'edge'
                        strsPars = cellstr(strs([2:4 end-1:end]));
                        strsCoords = strs(5:end-2);
                        Coords = {str2double(strsCoords(1:2:end)),str2double(strsCoords(2:2:end))};
                        G.Edges = [G.Edges; array2table([strsPars Coords],'VariableNames',edgeFields)];
                    case 'graph'
                        G.leftMargin = str2double(strs{2});
                        G.width = str2double(strs{3});
                        G.height = str2double(strs{4});
                end
            end

            G.Nodes = tabConvertNumericStrings(G.Nodes);
            
            if ~isempty(G.Edges)
                G.Edges = tabConvertNumericStrings(G.Edges);
                G.Edges = tabcell2str(G.Edges);                
            end                      
        end
    end
end