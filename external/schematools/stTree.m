classdef stTree

    %Level Ids increase from bottom to top (vertical) or left to right
    %(horizontal)

    properties
        Tree
        Levels = []
        Orientation = 'horizontal'
        Graph = []
    end

    methods
        function obj = stTree(tree,opts)
            arguments
                tree
                opts.numberRepeated = true
            end
            obj.Tree = tabcell2str(tree);
            obj.Levels = unique(obj.Tree.Level,'stable');
            [~,ia] = ismember(obj.Tree.Level,obj.Levels);
            obj.Tree.LevelId = 1 + max(ia)-ia;
            if opts.numberRepeated
                obj = obj.numberRepeatedNames();
            end
            obj.Graph = obj.getGraph();
        end

        function obj = numberRepeatedNames(obj)
            for level=obj.Levels'
                uNames = unique(obj.Tree.Name(obj.Tree.Level==level));
                for name = uNames'
                    ixs = ismember(obj.Tree.Name,name) & obj.Tree.Level==level;
                    if sum(ixs)>1
                        obj.Tree.Name(ixs) = obj.Tree.Name(ixs) + (1:sum(ixs))';
                    end
                end
            end
        end

        function obj = genLayout(obj,opts)
            arguments
                obj
                opts.layoutMethod = 'balanced'
                opts.anchorLevel = 1
                opts.orientation = obj.Orientation 
                opts.dims = [0 1; 0 1];
            end

            switch(opts.layoutMethod)
                case 'balanced'
                    obj = obj.balancedLayout(opts.anchorLevel,opts.orientation);
                case 'specified'
                    obj = obj.specifiedLayout(opts.anchorLevel,opts.orientation);
                case 'anchored'
                    obj = obj.anchoredLayout(opts.anchorLevel,opts.orientation);
                    obj.Tree.Pos = opts.dims(:,1)' + ...
                        obj.Tree.Pos .* diff(opts.dims,1,2)';
                    return
            end
            
            obj.Tree.Pos(:,1) = (obj.Tree.Pos(:,1)-opts.dims(1,1))*diff(opts.dims(1,:));
            obj.Tree.Pos(:,2) = (obj.Tree.Pos(:,2)-opts.dims(2,1))*diff(opts.dims(2,:));
        end

        function graph = getGraph(obj)
            names = unique(obj.Tree.Name,'stable');
            C = false(numel(names)); %#ok<MNUML>
            for a=1:numel(names)
                for b=1:numel(names)
                    if any(obj.Tree.Parent==names(b) & obj.Tree.Name==names(a))                    
                        C(b,a) =true;
                    end
                end
            end
            graph = digraph(C,names);
        end

        function [obj] = specifiedLayout(obj,anchorLevel,orientation)

            T = obj.Tree;

            switch(orientation)
                case 'horizontal'
                    layoutDim = 1;
                case 'vertical'
                    layoutDim = 2;
            end
            levelDim = setdiff(1:2,layoutDim);
            maxLevel = max(T.LevelId);

            %nodes in table are ordered by level
            T.Pos(:,levelDim) = (T.LevelId-1)./(maxLevel-1);

            ixs = find(T.LevelId==anchorLevel);

            %traverse upwards
            anchorLevelId = T.LevelId(ixs(1));
            level = anchorLevelId+1;
            while level <= maxLevel
                ixs = find(T.LevelId==level);
                for i=1:length(ixs)
                    children = successors(obj.Graph,T.Name(ixs(i)));
                    %get children positions
                    posch = T.Pos(ismember(T.Name,children),layoutDim);
                    if ~isempty(posch)
                        T.Pos(ixs(i),layoutDim) = mean(posch);
                    end
                end
                level = level+1;
            end

            %traverse downwards
            level = anchorLevelId-1;
            while level >=1
                ixs = find(T.LevelId==level);
                parents = {};
                for i=1:length(ixs)
                    parents{i} = predecessors(obj.Graph,T.Name(ixs(i)));
                end
                uParents = unique([parents{:}]);
                sameParent = {};
                for i=1:numel(uParents)
                    sameParent{i} = cellfun(@(c)find(c==uParents(i)),T.Parent(ixs));
                end
                for i=1:length(sameParent)
                    if isscalar(sameParent{i})
                        posch = T.Pos(T.Name==uParents(i),layoutDim);
                    else
                        !!
                        %ToDo
                    end
                    for j=1:length(sameParent{i})
                        T.Pos(ixs(sameParent{i}(j)),layoutDim) = posch;
                    end
                end

                level = level-1;
            end

            obj.Tree = T;
        end
        function [obj] = balancedLayout(obj,anchorLevel,orientation)

            %T = obj.Tree;
            T = obj.Graph.Nodes;
            [~,ia] = ismember(T.Name,obj.Tree.Name);
            T.LevelId = obj.Tree.LevelId(ia);
            T.Pos = repmat([nan nan],height(T),1);

            switch(orientation)
                case 'horizontal'
                    layoutDim = 1;
                case 'vertical'
                    layoutDim = 2;
            end
            levelDim = setdiff(1:2,layoutDim);
            maxLevel = max(T.LevelId);

            %nodes in table are ordered by level
            T.Pos(:,levelDim) = (T.LevelId-1)./(maxLevel-1);

            %evenly distribute nodes on anchor level:
            nodesOnLevel = find(T.LevelId==anchorLevel);
            T.Pos(nodesOnLevel,layoutDim) = linspace(0,1,numel(nodesOnLevel));

            %traverse upwards
            anchorLevelId = T.LevelId(nodesOnLevel(1));
            level = anchorLevelId+1;
            while level <= maxLevel
                nodesOnLevel = find(T.LevelId==level);
                for i=1:length(nodesOnLevel)
                    children = successors(obj.Graph,T.Name(nodesOnLevel(i)));
                    %get children positions
                    posch = T.Pos(ismember(T.Name,children),layoutDim);
                    if ~isempty(posch)
                        T.Pos(nodesOnLevel(i),layoutDim) = mean(posch);
                    end
                end                
                level = level+1;
            end

            %traverse downwards
            level = anchorLevelId-1;
            while level >=1
                nodesOnLevel = find(T.LevelId==level);
                parents = {};
                for i=1:length(nodesOnLevel)
                    parents{i} = predecessors(obj.Graph,T.Name(nodesOnLevel(i)));
                    parentPos{i} = T.Pos(ismember(T.Name,parents{i}),layoutDim); 
                    if isscalar(nodesOnLevel)
                        T.Pos(nodesOnLevel(i),layoutDim) = mean(parentPos{i});
                    end
                    %T.Pos(nodesOnLevel(i),layoutDim) = mean(parentPos{i});
                end
                if ~isscalar(nodesOnLevel)
                    T.Pos(nodesOnLevel,layoutDim)=linspace(0,1,numel(nodesOnLevel));
                end
                level = level-1;
            end

            obj.Tree = T;
        end

        function obj = anchoredLayout(obj,anchorLevel,orientation)
            % Fixed, evenly spaced anchors; ancestors average their children.
            % Descendants occupy equal slots in a symmetric parent span.
            % Spans may extend beyond [0,1]; singleton children copy parents.
            % Branches without anchor descendants inherit their parent's
            % center above the anchor. Unanchored roots start at 0.5.
            % Like balancedLayout, anchorLevel refers to internal LevelId.
            T = obj.Graph.Nodes;
            [~,ia] = ismember(T.Name,obj.Tree.Name);
            T.LevelId = obj.Tree.LevelId(ia);
            [src,dst] = findedge(obj.Graph);
            if any(indegree(obj.Graph)>1) || ...
                    any(T.LevelId(src)<=T.LevelId(dst))
                error('stTree:InvalidHierarchy', ...
                    'Anchored layout requires at most one parent per node and decreasing LevelIds along edges.');
            end
            anchors = find(T.LevelId==anchorLevel);
            if isempty(anchors)
                error('stTree:InvalidAnchorLevel','Anchor LevelId does not exist.');
            end
            switch orientation
                case 'horizontal'
                    layoutDim = 1;
                case 'vertical'
                    layoutDim = 2;
                otherwise
                    error('stTree:InvalidOrientation','Unknown orientation.');
            end
            n = height(T);
            x = nan(n,1);
            radius = nan(n,1);
            if isscalar(anchors)
                x(anchors) = 0.5;
                radius(anchors) = 0.5;
            else
                x(anchors) = linspace(0,1,numel(anchors))';
                radius(anchors) = 0.5/(numel(anchors)-1);
            end
            [~,order] = sort(T.LevelId);

            % Locate the skeleton connected to anchors. Unknown child
            % branches will later inherit this parent's center, preserving
            % the mean over ALL children, not just the anchored branches.
            for node = order(:)'
                if T.LevelId(node)<=anchorLevel, continue; end
                children = successors(obj.Graph,node);
                known = children(~isnan(x(children)));
                if ~isempty(known)
                    x(node) = mean(x(known));
                    radius(node) = max(abs(x(known)-x(node))+radius(known));
                end
            end

            % Parents precede children, including edges that skip levels.
            for node = flipud(order(:))'
                if isnan(x(node))
                    x(node) = 0.5; % root of a component without anchors
                    radius(node) = 0.5;
                end
                children = successors(obj.Graph,node);
                free = children(isnan(x(children)));
                above = free(T.LevelId(free)>=anchorLevel);
                x(above) = x(node);
                radius(above) = radius(node);
                below = free(T.LevelId(free)<anchorLevel);
                count = numel(below);
                if count>0
                    % Equal-width slots have a mean at the parent's center.
                    offsets = ((1:count)'-(count+1)/2)*2*radius(node)/count;
                    x(below) = x(node)+offsets;
                    radius(below) = radius(node)/count;
                end
            end
            T.Pos = zeros(n,2);
            T.Pos(:,layoutDim) = x;
            maxLevel = max(T.LevelId);
            if maxLevel==1
                T.Pos(:,3-layoutDim) = 0.5;
            else
                T.Pos(:,3-layoutDim) = (T.LevelId-1)/(maxLevel-1);
            end
            obj.Tree = T;
        end

        function info = nodeSpec(obj)
            info = [cellstr(obj.Tree.Name) num2cell(obj.Tree.Pos,2)];
        end

        function info = edgeSpec(obj,opts)
            arguments
                obj
                opts.directed = false
            end
            switch(opts.directed)
                case false
                    info = string(obj.Graph.Edges.EndNodes(:,1)) + " - " + string(obj.Graph.Edges.EndNodes(:,2));
                case true
                    info = string(obj.Graph.Edges.EndNodes(:,1)) + " > " + string(obj.Graph.Edges.EndNodes(:,2));
            end
        end

        function names = getChildren(obj,parent)
            names = obj.Tree.Name(obj.Tree.Parent==parent);
        end        
    end

    methods (Static)
        function s = digraphToBracketed(G, root, opts)
            %DIGRAPHTOBRACKETED Convert a rooted MATLAB digraph tree to a bracketed string.
            %   s = digraphToBracketed(G)           % auto-detects the (single) root
            %   s = digraphToBracketed(G, root)     % you provide the root (name or index)
            %   s = digraphToBracketed(G, root, opts)
            %
            % Assumptions:
            %   - G is a rooted directed tree (a DAG with exactly one node of in-degree 0,
            %     and every other node has in-degree 1). If G has multiple roots, cycles,
            %     or disconnected components, this function errors.
            %
            % Options (struct 'opts', all optional):
            %   opts.Separator   : char used between children (default ',')
            %   opts.SortChildren: true|false sort child subtrees lexicographically (default true)
            %   opts.StripSpaces : true|false remove spaces around separators (default true)
            %
            % Examples:
            %   %  A -> B, A -> E, B -> C, B -> D  =>  A(B(C,D),E)
            %   G = digraph([1 1 2 2],[2 5 3 4],[], {'A','B','C','D','E'});
            %   s = digraphToBracketed(G)
            %
            %   % Explicit root by name:
            %   s = digraphToBracketed(G, 'A');
            %
            %   % With options:
            %   s = digraphToBracketed(G, [], struct('Separator',';', 'SortChildren',false));
            %
            % Sameness:
            %   Leaves appear as just their label. Non-leaves are "Label(child1,child2,...)"
            %
            % Author: (you)
            % -------------------------------------------------------------------------

            arguments
                G (1,1) digraph
                root = []
                opts.Separator (1,1) char = ' '
                opts.SortChildren (1,1) logical = false
                opts.StripSpaces (1,1) logical = true
            end

            % --- Validate tree-ness ---
            if ~isdag(G)
                error('digraphToBracketed:NotDAG', 'G must be a DAG (no cycles).');
            end

            indeg = indegree(G);
            n = numnodes(G);

            % A rooted tree must have exactly one node with indegree 0
            rootCandidates = find(indeg == 0);

            if isempty(root)
                if numel(rootCandidates) ~= 1
                    error('digraphToBracketed:RootAmbiguous', ...
                        'Expected exactly one root (indegree==0). Found %d.', numel(rootCandidates));
                end
                root = rootCandidates;
            else
                % Normalize provided root to a numeric node index
                root = normalizeNodeArg(G, root);
                if indeg(root) ~= 0
                    warning('digraphToBracketed:RootHasParents', ...
                        'Provided root has in-degree %d (not 0). Proceeding anyway.', indeg(root));
                end
            end

            % Also ensure each non-root node has indegree 1 (tree condition)
            if any(indeg(setdiff(1:n, root)) ~= 1)
                error('digraphToBracketed:NotTree', ...
                    'G must be a rooted tree: every non-root node must have in-degree 1.');
            end

            % Connectivity check (treat as undirected, should be one component)
            UG = graph(G.Edges.EndNodes(:,1), G.Edges.EndNodes(:,2));
            comps = conncomp(UG);
            if numel(unique(comps)) ~= 1
                error('digraphToBracketed:Disconnected', 'G must be a single connected component.');
            end

            % --- Node labels ---
            if any(strcmp('Name', G.Nodes.Properties.VariableNames))
                labels = string(G.Nodes.Name);
            else
                labels = string(1:n);
            end

            % --- Build string with recursion ---
            sep = opts.Separator;
            if opts.StripSpaces
                joiner = sep;
            else
                joiner = [' ' sep ' '];
            end

            visited = false(1,n); % for paranoia; tree => no repeats
            s = build(root);

            % --- nested helpers ---
            function out = build(u)
                if visited(u)
                    error('digraphToBracketed:UnexpectedRevisit', ...
                        'Node %s was visited twice. Input must be a tree.', labels(u));
                end
                visited(u) = true;

                kids = successors(G, u);

                if isempty(kids)
                    out = char(labels(u));
                    return;
                end

                % Recurse children
                childStrs = strings(1, numel(kids));
                for k = 1:numel(kids)
                    childStrs(k) = string(build(kids(k)));
                end

                if opts.SortChildren
                    childStrs = sort(childStrs);
                end

                out = sprintf('[_{%s} %s]', labels(u), strjoin(childStrs, joiner));
            end
        end

        % --- utility: accept index or name for 'root' ---
        function idx = normalizeNodeArg(G, nodeArg)
            if isnumeric(nodeArg) && isscalar(nodeArg)
                idx = nodeArg;
                if ~(1 <= idx && idx <= numnodes(G))
                    error('digraphToBracketed:BadIndex', 'Root index out of range.');
                end
                return
            end
            if isstring(nodeArg) || ischar(nodeArg)
                name = string(nodeArg);
                if any(strcmp('Name', G.Nodes.Properties.VariableNames))
                    idx = find(strcmp(G.Nodes.Name, name), 1, 'first');
                    if isempty(idx)
                        error('digraphToBracketed:NoSuchName', 'No node named "%s".', name);
                    end
                    return
                else
                    error('digraphToBracketed:NoNames', ...
                        'G.Nodes has no Name column; provide a numeric index for root.');
                end
            end
            error('digraphToBracketed:BadRootArg', ...
                'Root must be a scalar index or a node name (char/string).');
        end

    end
end
