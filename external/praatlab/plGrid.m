classdef plGrid

    properties
        Tiers
        SourceFile = ""
        SourceFileName = ""
        Encoding = ''
        GridInfo = []
        Lines = ""
        AutoCorrectNewLines = true
        IsValid = true
    end

    methods
        function obj = plGrid(varargin)
            if nargin==1

                if iscell(varargin{1})
                    obj = plGrid.intervalsToGrid(varargin{1});
                elseif istable(varargin{1})
                    obj = plGrid.intervalsToGrid(varargin(1));
                else
                    obj.SourceFile = string(varargin{1});
                    [~,obj.SourceFileName] = fileparts(obj.SourceFile);
                    obj = obj.readGrid();
                end
            end
        end

        function obj = readGrid(obj,opts)
            arguments
                obj
                opts.Encoding = obj.Encoding
            end

            if ~exist(obj.SourceFile,'file')
                if ~contains(obj.SourceFile,'.TextGrid')
                    obj.SourceFile = obj.SourceFile + ".TextGrid"; %try appending .TextGrid
                    if ~exist(obj.SourceFile,'file')
                        fprintf('Textgrid: %s not found\n',obj.SourceFile); return;
                    end
                end
                fprintf('Textgrid: %s not found\n',obj.SourceFile); return;
            end

            obj.Lines = readlines(obj.SourceFile,"Encoding",opts.Encoding);
            obj.Lines = obj.Lines(obj.Lines~=""); %remove blank lines

            if obj.AutoCorrectNewLines
                ix = obj.Lines==""" ";
                while any(ix)
                    ixfix = find(ix,1,'first');
                    obj.Lines = obj.Lines(~ix);
                    obj.Lines(ixfix-1) = obj.Lines(ixfix-1) + """ ";
                    ix = obj.Lines==""" ";
                end
            end
            obj.GridInfo = obj.parseHeader(obj.Lines);
            obj.Tiers = obj.parseTiers();
            obj.IsValid = obj.validateGrid(obj);
            if ~obj.IsValid
                1;
            end
        end

        function [] = writeGrid(obj,dest,opts)
            arguments
                obj
                dest
                opts.overwrite = true;
                opts.overwriteMsg = [];
                opts.addExtension = true
            end

            if opts.addExtension && ~contains(dest,'.TextGrid')
                dest = dest + ".TextGrid"; % append .TextGrid if required
            end

            n2s = @(c)sprintf('%.9f',c);

            if ~opts.overwrite && exist(dest,'file')
                if ~isempty(opts.overwriteMsg)
                    fprintf('%s\n',opts.overwriteMsg);
                end
                return;
            end
            lines{1} = 'File type = "ooTextFile"';
            lines{end+1} = 'Object class = "TextGrid"';
            lines{end+1} = '';
            lines{end+1} = ['xmin = ' n2s(obj.GridInfo.xmin)];
            lines{end+1} = ['xmax = ' n2s(obj.GridInfo.xmax)];
            lines{end+1} = 'tiers? <exists>';
            lines{end+1} = ['size = ' num2str(numel(obj.Tiers))];
            lines{end+1} = 'item []:';

            %write tiers
            for i=1:length(obj.Tiers)
                tier = obj.Tiers{i};
                if iscell(tier.Properties.UserData)
                    tierInfo = tier.Properties.UserData{1};
                else
                    tierInfo = tier.Properties.UserData;
                end

                if isempty(tierInfo.name)
                    tierInfo.name = "";
                end

                lines{end+1} = sprintf('\t%s',['item [' num2str(i) ']:']);
                lines{end+1} = sprintf('\t\t%s',['class = "' char(tierInfo.class) '"']);
                lines{end+1} = sprintf('\t\t%s',['name = "' char(tierInfo.name) '"']);
                lines{end+1} = sprintf('\t\t%s',['xmin = ' n2s(tierInfo.xmin)]);
                lines{end+1} = sprintf('\t\t%s',['xmax = ' n2s(tierInfo.xmax)]);

                switch(tierInfo.class)
                    case 'IntervalTier'
                        lines{end+1} = sprintf('\t\t%s',['intervals: size = ' num2str(height(tier))]);
                        for j=1:height(tier)
                            lines{end+1} = sprintf('\t\t%s',['intervals [' num2str(j) ']:']);
                            lines{end+1} = sprintf('\t\t\t%s',['xmin = ' n2s(tier.t0(j))]);
                            lines{end+1} = sprintf('\t\t\t%s',['xmax = ' n2s(tier.t1(j))]);
                            lines{end+1} = sprintf('\t\t\t%s',['text = "' char(tier.text{j}) '"']);
                        end
                    case 'TextTier'
                        lines{end+1} = sprintf('\t\t%s',['points: size = ' num2str(height(tier))]);
                        for j=1:height(tier)
                            lines{end+1} = sprintf('\t\t%s',['points [' num2str(j) ']:']);
                            lines{end+1} = sprintf('\t\t\t%s',['number = ' n2s(tier.time(j))]);
                            lines{end+1} = sprintf('\t\t\t%s',['mark = "' char(tier.text{j}) '"']);
                        end
                end
            end
            lines = string(lines(:));
            writelines(lines,dest);
        end

        function [tiers] = parseTiers(obj)
            ixItems = find(~cellfun('isempty',regexp(obj.Lines,'item \[\d+\]:')));
            ixItems = [ixItems; length(obj.Lines)+1];
            tiers = {};
            for i=1:length(ixItems)-1
                tiers{i,1} = obj.parseTier(obj.Lines(ixItems(i):ixItems(i+1)-1));
            end

        end

        function [tier] = parseTier(obj,lines)
            tierInfo = obj.parseTierHeader(lines);
            switch(tierInfo.class)
                case 'IntervalTier'
                    tier = obj.parseIntervalTier(lines);
                case 'TextTier'
                    tier = obj.parseTextTier(lines);
                otherwise
                    fprintf('Unrecognized tier class:\n %s\n',lines);
                    tier = [];
                    return;
            end
            tier.Properties.UserData{1} = tierInfo;
        end

        function [obj] = clipOutOfRange(obj,maxDur,opts)
            arguments
                obj
                maxDur = inf
                opts.tiers = []
                opts.tol = 1e-3
            end
            if isempty(opts.tiers)
                opts.tiers = 1:numel(obj.Tiers);
            end
            for i=1:length(opts.tiers)
                Tier = obj.Tiers{i};
                obj.Tiers{i} = Tier((Tier.t1-maxDur)<opts.tol,:);
            end
            obj.updateGridHeader();
            obj.updateTierHeaders();
        end

        function [obj] = removeTiers(obj,remTiers)
            keepTiers = setdiff(1:numel(obj.Tiers),remTiers);
            obj.Tiers = obj.Tiers(keepTiers);
            obj = obj.updateGridHeader();
        end

        function [obj] = updateTierHeaders(obj)
            for i=1:length(obj.Tiers)
                obj.Tiers{i}.Properties.UserData.number = i;
                obj.Tiers{i}.Properties.UserData.xmax = obj.GridInfo.xmax;
                obj.Tiers{i}.Properties.UserData.size = height(obj.Tiers{i});
            end
        end
        function [obj] = updateGridHeader(obj)
            maxDur = max(cellfun(@(c)c.t1(end),obj.Tiers));
            obj.GridInfo.xmax = maxDur;
            obj.GridInfo.xmin = 0;
            obj.GridInfo.size = numel(obj.Tiers);
        end

        function [obj] = mergeAdjacent(obj,labels,opts)
            arguments
                obj
                labels = {}
                opts.tiers = []
            end
            if isempty(opts.tiers)
                opts.tiers = 1:numel(obj.Tiers);
            end
            for i=1:length(opts.tiers)
                Tier = obj.Tiers{i};
                c=height(Tier);
                while 1
                    Tier.repeated = strcmp(Tier.text,circshift(Tier.text,1));
                    if ~isempty(labels), Tier.repeated = Tier.repeated & ismember(Tier.text,labels); end
                    if c==1, break; end
                    if Tier.repeated(c)
                        Tier.t1(c-1)=Tier.t1(c);
                        Tier = Tier([1:c-1 c+1:end],:);
                        c=height(Tier);
                        continue;
                    end
                    c=c-1;
                end
                obj.Tiers{i} = Tier;
            end
            obj.updateGridHeader();
            obj.updateTierHeaders();
        end
        function [obj] = alignObjTiers(obj,tierAdj,tierRef,opts)
            arguments
                obj
                tierAdj
                tierRef
                opts.misAlignTol = 0.025
                opts.verbose = false
            end
            obj.Tiers{tierAdj} = ...
                obj.alignIntervals(obj.Tiers{tierAdj},obj.Tiers{tierRef},...
                misAlignTol=opts.misAlignTol);

        end
        function [obj] = numberRepeatedInt(obj,tierNum,opts)
            arguments
                obj
                tierNum = []
                opts.renumberEmpty = false;
            end
            if isempty(tierNum), tierNum = 1; end
            tier = obj.Tiers{tierNum};
            labs = unique(tier.text);
            if ~opts.renumberEmpty, labs = setdiff(labs,""); end
            for i=1:numel(labs)
                ixs = tier.text==labs(i);
                if numel(ixs)>1
                    tier.text(ixs) = labs(i) + (1:sum(ixs))';
                end
            end
            obj.Tiers{tierNum} = tier;
        end
        function [obj] = nameTier(obj,tierNum,name)
            arguments
                obj
                tierNum
                name
            end
            obj.Tiers{tierNum}.Properties.UserData.name = name;
        end
        function [tier] = getTier(obj,tierId)
            if isnumeric(tierId)
                tier = obj.Tiers{tierId};
            else
                tierNames = string(cellfun(@(c){c.Properties.UserData{1}.name},obj.Tiers));
                tierNum = find(ismember(tierNames,tierId));
                if isempty(tierNum)
                    fprintf('Tier %s not found\n',tierId);
                    tier = [];
                else
                    tier = obj.Tiers{tierNum};
                end
            end
        end
    end

    methods (Static)

        function obj = genGrid(times,labels)
            hdrLines = plGrid.genGridHeader(times);
            tierInfo = plGrid.parseHeader(hdrLines);
            tier = plGrid.genTier(times,labels);
            obj = plGrid();
            obj.Tiers{1} = tier;
            obj.GridInfo = tierInfo;
        end

        function obj = intervalsToGrid(tierTables)

            if ~iscell(tierTables), tierTables = {tierTables}; end
            obj = plGrid();
            intervalTiers = {};
            for i=1:length(tierTables)
                switch(ismember('time',tabcols(tierTables{i})))
                    case true %point tier
                        obj.Tiers{i} = tierTables{i};
                    case false
                        times = [tierTables{i}.t0; tierTables{i}.t1(end)];
                        obj.Tiers{i} = plGrid.genTier(times,tierTables{i}.text);
                        
                        intervalTiers{end+1} = obj.Tiers{i};
                end
                if ~isempty(tierTables{i}.Properties.UserData)
                    ud = tierTables{i}.Properties.UserData;
                    if iscell(ud), ud = ud{:}; end
                    obj.Tiers{i}.Properties.UserData.name = ud.name;
                end
            end
            times = cellfun(@(c){[c.t0 c.t1]},intervalTiers);
            times = vertcat(times{:});
            times = sort(times(:));
            hdrLines = plGrid.genGridHeader(times);
            hdrLines = regexprep(hdrLines,'size = \d+',"size = " + numel(tierTables));
            obj.GridInfo = plGrid.parseHeader(hdrLines);

        end

        function tier = genTier(times,labels,opts)
            arguments
                times
                labels = []
                opts.class = []
                opts.name = ''
                opts.xmin = 0
                opts.xmax = []
            end            
            tierInfo.number = 1;
            tierInfo.name = opts.name;
            tierInfo.xmin = opts.xmin;
            tierInfo.xmax = times(end);
            if size(times,2)==2
                times = [times(:,1); times(end,2)];
            end

            nTimes = numel(times);
            nLabels = numel(labels);
            diffTimesLabels = nTimes-nLabels;
            if isempty(opts.class) && ~isempty(labels)
                if (diffTimesLabels==0) && ~isempty(opts.xmax)
                    opts.class = 'TextTier';                             
                elseif diffTimesLabels==2 && isempty(opts.xmax)
                    opts.class = 'TextTier';
                    opts.xmin = times(1);
                    opts.xmax = times(end);
                    times = times(2:end-1);
                elseif diffTimesLabels==1
                    opts.class = 'IntervalTier';
                else
                    fprintf('ERROR: must have two or one more times than labels (for TextTier or IntervalTier)\n');
                    tier=[]; 
                    return
                end
            else
                opts.class = 'IntervalTier';
                if isempty(labels), labels = repmat("",numel(times)-1,1); end
            end

            switch(opts.class)
                case 'TextTier'
                    tierInfo.class = 'TextTier';
                    labels = labels(:);
                    tier.text = labels(1:numel(times));
                    tier.time = times(:);
                    tier = struct2table(tier);
                    tierInfo.size = length(times)-2;
                case 'IntervalTier'
                    tierInfo.class = 'IntervalTier';
                    tier.text = labels(:);
                    tier.t0 = times(1:end-1); tier.t0 = tier.t0(:);
                    tier.t1 = times(2:end); tier.t1 = tier.t1(:);
                    tier = struct2table(tier);
                    tierInfo.size = length(times)-1;
            end
            tier.Properties.UserData = tierInfo;
        end

        function [lines] = genGridHeader(times)
            lines = "File type = ""ooTextFile""";
            lines(end+1) = "Object class = ""TextGrid""";
            lines(end+1) = "xmin = " + times(1);
            lines(end+1) = "xmax = " + times(end);
            lines(end+1) = "tiers? <exists>";
            lines(end+1) = "size = 1";
            lines(end+1) = "item []:";
            lines = lines(:);
        end

        function [tier] = parseIntervalTier(lines)
            ixs = find(contains(lines,"intervals ["));
            tier = [];
            reMatch = @(line,pat)regexp(line,pat,'match','once');
            fpre = '[-+]?(\d*\.\d+|\d+\.?\d*)([eE][-+]?\d+)?';
            refpMatch = @(line,pat)str2double(regexp(line,[pat fpre],'match','once'));
            for i=1:length(ixs)
                tier(end+1,1).text = reMatch(lines(ixs(i)+3),'(?<=text = ").*(?=")');
                tier(end).t0 = refpMatch(lines(ixs(i)+1),'(?<=xmin = )');
                tier(end).t1 = refpMatch(lines(ixs(i)+2),'(?<=xmax = )');
            end
            tier = struct2table(tier);
            tier.text(ismissing(tier.text)) = "";
        end

        function [tier] = parseTextTier(lines)
            ixs = find(contains(lines,"points ["));
            tier = [];
            reMatch = @(line,pat)regexp(line,pat,'match','once');
            fpre = '[-+]?(\d*\.\d+|\d+\.?\d*)([eE][-+]?\d+)?';
            refpMatch = @(line,pat)str2double(regexp(line,[pat fpre],'match','once'));
            for i=1:length(ixs)
                tier(end+1,1).text = reMatch(lines(ixs(i)+2),'(?<=mark = ").*(?=")');
                tier(end).time = refpMatch(lines(ixs(i)+1),'(?<=number = )');
            end
            if isempty(tier)
                tier = table([],[],'VariableNames',{'text' 'time'});
            else
                tier = struct2table(tier);
                tier.text(ismissing(tier.text)) = "";
            end
        end

        function [gridInfo] = parseHeader(lines)
            ixItem = find(contains(lines,"item []:"));
            lines = lines(1:ixItem-1);
            notMissing = @(x)x(~ismissing(x));
            reMatch = @(pat)notMissing(regexp(lines,pat,'match','once'));
            fpre = '[-+]?(\d*\.\d+|\d+\.?\d*)([eE][-+]?\d+)?';
            refpMatch = @(pat)str2double(notMissing(regexp(lines,[pat fpre],'match','once')));
            gridInfo.FileType = reMatch('(?<=File type = ")\w+(?=")');
            gridInfo.ObjectClass = reMatch('(?<=Object class = ")\w+(?=")');
            gridInfo.xmin = refpMatch('(?<=xmin = )');
            gridInfo.xmax = refpMatch('(?<=xmax = )');
            gridInfo.size = refpMatch('(?<=size = )');
        end

        function [tierInfo] = parseTierHeader(lines)
            lines = regexprep(lines,'\t','');
            ixIntervals = find(contains(lines,"intervals:") | contains(lines,"points:"));
            lines = lines(1:ixIntervals);
            notMissing = @(x)x(~ismissing(x));
            reMatch = @(pat)notMissing(regexp(lines,pat,'match','once'));
            fpre = '[-+]?(\d*\.\d+|\d+\.?\d*)([eE][-+]?\d+)?';
            refpMatch = @(pat)str2double(notMissing(regexp(lines,[pat fpre],'match','once')));
            tierInfo.number = refpMatch('(?<=item \[)');
            tierInfo.name = reMatch('(?<=name = ")\w+');
            tierInfo.class = reMatch('(?<=class = ")\w+(?=")');
            tierInfo.xmin = refpMatch('(?<=xmin = )');
            tierInfo.xmax = refpMatch('(?<=xmax = )');
            tierInfo.size = refpMatch('(?<=(intervals:|points:) size = )');
        end

        function [tierAdj,results] = alignIntervals(tierAdj,tierRef,opts)
            arguments
                tierAdj
                tierRef
                opts.misAlignTol = 0.025
                opts.verbose = false
            end

            [tierAdj.delta,tierAdj.ixRef] = arrayfun(@(c)min(abs(tierRef.t1-c)),tierAdj.t1);
            tierAdj.diff = tierRef.t1(tierAdj.ixRef)-tierAdj.t1;

            tierAdj.warning = false(height(tierAdj),1);
            tierAdj.warning = tierAdj.delta>opts.misAlignTol;
            if opts.verbose
                w = tierAdj(tierAdj.warning,:);
                for j=1:height(w)
                    fprintf('misalignment beyond tolerance: %s: delta t1 = %1.3f\n',w.text(j),w.delta(j));
                end
            end

            tierAdj.t1 = tierAdj.t1+tierAdj.diff;
            tierAdj.t0(2:end) = tierAdj.t1(1:end-1);

            if nargout>1, results = tierAdj; end
            rmcols = {'delta' 'ixRef' 'diff' 'warning'};
            tierAdj = removevars(tierAdj,rmcols);
        end

        function [align] = compareTiers(tier1,tier2)
            [align,idx1,idx2] = plGrid.alignLabels(tier1.text,tier2.text);
            align = array2table(align,'VariableNames',{'label1','label2','align'});
            align.idx1 = idx1;
            align.idx2 = idx2;
            align.t0_1 = nan(height(align),1);
            align.t0_2 = nan(height(align),1);
            align.t1_1 = nan(height(align),1);
            align.t1_2 = nan(height(align),1);
            align.t0_1(align.idx1~=0) = tier1.t0(align.idx1(align.idx1~=0));
            align.t1_1(align.idx1~=0) = tier1.t1(align.idx1(align.idx1~=0));
            align.t0_2(align.idx2~=0) = tier2.t0(align.idx2(align.idx2~=0));
            align.t1_2(align.idx2~=0) = tier2.t1(align.idx2(align.idx2~=0));
        end

        function [alignment,idx1,idx2] = alignLabels(seq1,seq2)

            seq1 = cellstr(seq1);
            seq2 = cellstr(seq2);
            seq1 = cellfun(@(c){char(c)},seq1);
            seq2 = cellfun(@(c){char(c)},seq2);
            % Aligns two word sequences using dynamic programming (Levenshtein-like)
            % seq1 and seq2 are cell arrays of words
            % Aligns two word sequences using dynamic programming (Levenshtein-style)
            % seq1 and seq2 are cell arrays of words
            % Outputs:
            %   - alignment: Nx3 cell array {word1, word2, op}
            %   - idx1: index in seq1 (0 for insertion)
            %   - idx2: index in seq2 (0 for deletion)

            n = length(seq1);
            m = length(seq2);

            % Initialize cost and backtrace tables
            D = zeros(n+1, m+1);
            BT = strings(n+1, m+1);

            for i = 1:n+1
                D(i,1) = i-1;
                BT(i,1) = "del";
            end
            for j = 1:m+1
                D(1,j) = j-1;
                BT(1,j) = "ins";
            end
            BT(1,1) = "start";

            % Fill dynamic programming table
            for i = 2:n+1
                for j = 2:m+1
                    cost = ~strcmp(seq1{i-1}, seq2{j-1});
                    [~, idx] = min([
                        D(i-1,j) + 1;      % deletion
                        D(i,j-1) + 1;      % insertion
                        D(i-1,j-1) + cost  % substitution/match
                        ]);
                    ops = ["del", "ins", "sub"];
                    candidates = [D(i-1,j) + 1; D(i,j-1) + 1; D(i-1,j-1) + cost];
                    D(i,j) = candidates(idx);
                    BT(i,j) = ops(idx);
                end
            end

            % Trace back
            i = n+1; j = m+1;
            alignment = {};
            idx1 = [];  % indices into seq1
            idx2 = [];  % indices into seq2

            while ~(i == 1 && j == 1)
                op = BT(i,j);
                switch op
                    case "sub"
                        if strcmp(seq1{i-1}, seq2{j-1})
                            op_type = "match";
                        else
                            op_type = "sub";
                        end
                        alignment = [[seq1{i-1}, seq2{j-1}, op_type]; alignment];
                        idx1 = [i-1; idx1];
                        idx2 = [j-1; idx2];
                        i = i - 1; j = j - 1;
                    case "del"
                        alignment = [[seq1{i-1}, "", "del"]; alignment];
                        idx1 = [i-1; idx1];
                        idx2 = [0; idx2];
                        i = i - 1;
                    case "ins"
                        alignment = [["", seq2{j-1}, "ins"]; alignment];
                        idx1 = [0; idx1];
                        idx2 = [j-1; idx2];
                        j = j - 1;
                end
            end
        end

        function [gridObj,audio] = combineTokens(tierInfo,audiosources,opts)
            arguments
                tierInfo
                audiosources
                opts.spacing = 0.5
                opts.addToEdges = [1 1]
            end

            if ~iscell(tierInfo) || size(tierInfo,1)~=numel(audiosources)
                fprintf(['ERROR: tier information must be provided in an n x m cell array,\n' ...
                    'and n audio sources must be provided']);
                return
            end

            A = array2table(audiosources,'VariableNames',{'source'});
            for i=1:height(A)
                audinfo = audioinfo(audiosources(i));
                A.sampleRate(i) = audinfo.SampleRate;
                A.duration(i) = audinfo.Duration;
            end

            %check sample rates
            if numel(unique(A.sampleRate))>1
                fprintf('ERROR: all sample rates must be the same\n');
                return;
            end

            %check audio file duration consistent with tier interval times
            for i=1:size(tierInfo,1)
                A.maxGridTime(i) = max(cellfun(@(c)c.t1(end),tierInfo(i,:)));
            end
            if any(A.maxGridTime>A.duration)
                fprintf('ERROR: grid time exceeds audio duration\n');
            end

            %should check that all tiers have same duration for each token:
            %ToDo

            %add to edges
            varnames = ["text" "t0" "t1"];
            blankInt = @(t0,t1)table("",t0,t1,'VariableNames',varnames);
            for i=1:size(tierInfo,1)
                for j=1:size(tierInfo,2)
                    if opts.addToEdges(1)>0
                        preInt = blankInt(tierInfo{i,j}.t0(1)-opts.addToEdges(1),tierInfo{i,j}.t0(1));
                        tierInfo{i,j} = [preInt; tierInfo{i,j}];
                    end
                    if opts.addToEdges(2)>0
                        postInt = blankInt(tierInfo{i,j}.t1(end),tierInfo{i,j}.t1(end)+opts.addToEdges(2));
                        tierInfo{i,j} = [tierInfo{i,j}; postInt];
                    end
                end
            end

            %collect audio
            audio = {};
            for i=1:size(tierInfo,1)

                tt = [tierInfo{i,1}.t0(1) tierInfo{i,1}.t1(end)];
                ti = [max(tt(1),0) min(tt(2),A.duration(i))];
                tix = round(ti*A.sampleRate(i));
                audio{i} = audioread(A.source(i),tix);

                %handle extensions beyond signal
                if tt(1)<ti(1), audio{i} = [zeros(round(A.sampleRate(i)*(ti(1)-tt(1))),1); audio{i}]; end
                if tt(2)>ti(2), audio{i} = [audio{i}; zeros(round(A.sampleRate(i)*(tt(2)-ti(2))),1)]; end
            end

            %interpose spaces
            audiosp = cell(1,2*length(audio)+1);
            spaceAudio = zeros(opts.spacing*A.sampleRate(1),1);
            audiosp(1:2:end) = repmat({spaceAudio},1,length(audio)+1);
            audiosp(2:2:end) = audio;
            audio = vertcat(audiosp{:});

            %add spacing intervals
            for i=1:size(tierInfo,1)
                for j=1:size(tierInfo,2)
                    if i==1
                        spacingInt = blankInt(tierInfo{i,j}.t0(1)-opts.spacing,tierInfo{i,j}.t0(1));
                        tierInfo{i,j} = [spacingInt; tierInfo{i,j}];
                    end
                    spacingInt = blankInt(tierInfo{i,j}.t1(end),tierInfo{i,j}.t1(end)+opts.spacing);
                    tierInfo{i,j} = [tierInfo{i,j}; spacingInt];
                end
            end

            %add durations/original times
            for i=1:size(tierInfo,1)
                for j=1:size(tierInfo,2)
                    tierInfo{i,j}.dur = tierInfo{i,j}.t1-tierInfo{i,j}.t0;
                    tierInfo{i,j}.orig_t0 = tierInfo{i,j}.t0;
                    tierInfo{i,j}.orig_t1 = tierInfo{i,j}.t1;
                end
            end

            %recalculate times
            for j=1:size(tierInfo,2)
                lastTime = 0;
                for i=1:size(tierInfo,1)
                    tierInfo{i,j}.t0 = tierInfo{i,j}.t0-tierInfo{i,j}.t0(1)+lastTime;
                    tierInfo{i,j}.t1 = tierInfo{i,j}.t0+tierInfo{i,j}.dur;
                    lastTime = tierInfo{i,j}.t1(end);
                end
            end

            tiersOut = {};
            for i=1:size(tierInfo,2)
                tiersOut{i} = vertcat(tierInfo{:,i});
            end

            gridObj = plGrid.intervalsToGrid(tiersOut);

        end

        function [isValid] = validateGrid(obj,opts)
            arguments
                obj
                opts.verbose = false
                opts.audioFileDuration = []
            end

            if ~isempty(opts.audioFileDuration)
                if ~isnumeric(opts.audioFileDuration)
                    audInfo = audioinfo(opts.audioFileDuration);
                    opts.audioFileDuration = audInfo.Duration;
                end
            end

            isValid = true;
            %validate tier times
            for i=1:length(obj.Tiers)
                tierInfo = obj.Tiers{i}.Properties.UserData{1};
                switch(tierInfo.class)
                    case "IntervalTier"
                        if obj.Tiers{i}.t1(end)~=tierInfo.xmax
                            isValid = false;
                            if opts.verbose
                                fprintf('Warning (Tier %d): interval time d/n match tier info\n',i);
                            end
                        end
                        if obj.Tiers{i}.t0(1)~=0
                            isValid = false;
                            if opts.verbose
                                fprintf('Warning (Tier %d): first interval d/n start at time 0\n',i);
                            end
                        end
                        if ~isempty(opts.audioFileDuration) && ...
                                obj.Tiers{i}.t1(end)>opts.audioFileDuration
                            isValid = false;
                            if opts.verbose
                                fprintf('Warning (Tier %d): interval time exceeds audio duration\n',i);
                            end
                        end
                end
            end
        end

        function [obj] = correctTierHeaderTimes(obj)
            for i=1:length(obj.Tiers)
                tierInfo = obj.Tiers{i}.Properties.UserData{1};
                switch(tierInfo.class)
                    case "IntervalTier"
                        tierInfo.xmax = obj.Tiers{i}.t1(end);
                end
                obj.Tiers{i}.Properties.UserData{1} = tierInfo;
            end
            obj = obj.updateGridHeader();
        end

        function [tier] = plotTier(tier,opts)
            arguments
                tier
                opts.parent = []
                opts.FontSize = 24
                opts.TimeShift = 0
                opts.PlotEmpty = false
                opts.FaceAlpha = []
                opts.FaceColor = []
                opts.EdgeColor = []
                opts.LineWidth = 2
                opts.LabelPos = "top"
                opts.Style = "lines"
                opts.Labels = true;
                opts.yRange = [0 1] %proportion of ylims
            end
            if isempty(opts.parent), opts.parent = gca; end
            if opts.TimeShift~=0
                tier.t0 = tier.t0-opts.TimeShift;
                tier.t1 = tier.t1-opts.TimeShift;
            end

            switch(lower(opts.Style))
                case {'box','filled'}
                    if ~ismember('color',tabcols(tier))
                        colors = repmat([0 0 0; 1 1 1],height(tier),1);
                        if isempty(opts.FaceColor)
                            tier.color = colors(1:height(tier),:);
                        else
                            tier.color = repmat(opts.FaceColor,height(tier),1);
                        end
                    end                    
                    if isempty(opts.FaceAlpha), opts.FaceAlpha = 0.5; end
                    if isempty(opts.EdgeColor), opts.EdgeColor = "none"; end
                case 'lines'

                    if isempty(opts.FaceAlpha), opts.FaceAlpha = 0; end
                    if isempty(opts.EdgeColor), opts.EdgeColor = [0 0 0]; end

            end
            
            axes(opts.parent);
            ylims = get(opts.parent,'YLim'); ylim(ylims);
            yy = ylims(1)+opts.yRange.*diff(ylims);
            for i=1:height(tier)
                if opts.PlotEmpty || tier.text(i)~=""
                    switch(lower(opts.Style))
                        case 'lines'
                            props = {'-','Color',opts.EdgeColor,'LineWidth',opts.LineWidth};
                            tier.lineHandles(i,1) = plot(tier.t0(i)*[1 1],yy,props{:}); hold on;
                            tier.lineHandles(i,2) = plot(tier.t1(i)*[1 1],yy,props{:});
                        case 'filled'
                            tier.fillHandle(i) = fill( ...
                                [tier.t0(i)*[1 1] tier.t1(i)*[1 1]],yy([1 2 2 1]),...
                                tier.color(i,:),'FaceAlpha',opts.FaceAlpha,...
                                'EdgeColor','none'); hold on;                            
                            tier.lineHandles(i,1) = plot(tier.t0(i)*[1 1],yy,'-','Color',opts.EdgeColor); hold on;
                            tier.lineHandles(i,2) = plot(tier.t1(i)*[1 1],yy,'-','Color',opts.EdgeColor);                              
                        case 'box'
                            tier.fillHandle(i) = fill( ...
                                [tier.t0(i)*[1 1] tier.t1(i)*[1 1]],yy([1 2 2 1]),...
                                tier.color(i,:),'FaceAlpha',opts.FaceAlpha,...
                                'EdgeColor',opts.EdgeColor); hold on;
                    end

                    switch(opts.LabelPos)
                        case "top"
                            y = yy(2);
                            align.hori = 'center';
                            align.verti = 'bottom';
                        case "topInside"
                            y = yy(2);
                            align.hori = 'center';
                            align.verti = 'top';
                        case "topMiddle"
                            % text centered vertically on the top of the interval
                            y = yy(2);
                            align.hori = 'center';
                            align.verti = 'middle';
                        case "topBaseline"
                            % text baseline on the top of the interval (no descender gap)
                            y = yy(2);
                            align.hori = 'center';
                            align.verti = 'baseline';
                        case "center"
                            y = mean(yy);
                            align.hori = 'center';
                            align.verti = 'middle';
                    end

                    tier.labelHandle(i) = text((tier.t0(i)+tier.t1(i))/2,y,tier.text(i),...
                        'HorizontalAlignment',align.hori,'Verti',align.verti,'FontSize',opts.FontSize);
                end
            end
            if ~opts.Labels, set(tier.labelHandle(ishandle(tier.labelHandle)),'Visible','off'); end
            ylim(ylims);
        end

        function [tier] = addTierColumn(tier,colName,fcn)
            if nargin==2
                switch(colName)
                    case 'dur'
                        fcn = @(c)c.t1-c.t0;
                    otherwise
                        error('plGrid:addTierColumn:unknownFunction',...
                            ['function could not be inferred from column name.\n' ...
                            'Specify anonymous function as third input.']);
                end
            end

            switch(isa(fcn,'function_handle'))
                case true
                    for i=1:height(tier)
                        tier.(colName)(i) = fcn(tier(i,:));
                    end
                case false
                    switch(size(fcn,1)==1)
                        case true
                            tier.(colName) = repmat(fcn,height(tier),1);                    
                        case false
                            tier.(colName) = fcn;
                    end
            end
        end

        function [tier] = mergeAdjacentLabels(tier,mergeLabels,opts)
            arguments
                tier
                mergeLabels
                opts.newLabel = []
                opts.ordered = true;                
            end

            mergeLabels = string(mergeLabels);

            c=height(tier);
            while 1
                tier.merge = tier.text==mergeLabels(1) & circshift(tier.text,-1)==mergeLabels(2);
                if c==1, break; end
                if tier.merge(c-1)
                    tier.t1(c-1)=tier.t1(c);
                    if ~isempty(opts.newLabel)
                        tier.text(c-1) = opts.newLabel;
                    end
                    tier = tier([1:c-1 c+1:end],:);
                    c=height(tier);
                    continue;
                end
                c=c-1;
            end
            tier.merge=[];
        end

        function [newLabels,numbers] = numberRepeatedLabels(tier,opts)
            arguments
                tier
                opts.labelField = 'text'
                opts.ignoreEmpty = true
                opts.numberAll = false
                opts.sep = "";
            end
            labs = tier.(opts.labelField);
            [d.cnts,d.labs] = groupcounts(labs);
            d = struct2table(d);
            d = sortrows(d,'cnts','descend');
            
            if opts.ignoreEmpty
                d = d(d.labs~="",:);
            end
            
            if ~opts.numberAll
                d = d(d.cnts>1,:);
            end

            
            numbers = nan(size(labs));
            for i=1:height(d)
                ixs = labs==d.labs(i);                
                numbers(ixs) = 1:sum(ixs);
            end
            newLabels = labs;
            ixs = ~isnan(numbers);
            newLabels(ixs) = newLabels(ixs)+opts.sep+numbers(ixs);

        end

        function [tier] = shiftTier(tier,label,field)
            arguments
                tier
                label
                field = 't0';
            end

            if isnumeric(label)
                ix = label;
            else
                if ~(sum(tier.text==label)==1)
                    fprintf('ERROR: ambigous alignment point, no shift applied\n');
                    return;
                end
                ix = find(tier.text==label);
            end

            switch(field)
                case 't0'
                    tier.t1 = tier.t1-tier.t0(ix);
                    tier.t0 = tier.t0-tier.t0(ix);

                case 't1'
                    tier.t0 = tier.t0-tier.t1(ix);
                    tier.t1 = tier.t1-tier.t1(ix);                    
            end

        end

        function [tier] = averageTier(tiers)

            tier=[];
            nrows = cellfun(@(c)height(c),tiers);
            if numel(unique(nrows))>1
                fprintf('ERROR: unmatched tiers, cannot average');
                return
            end

            nrows = unique(nrows);
            for i=1:nrows
                r = cellfun(@(c){c(i,:)},tiers);
                tiersByRow{i,1} = vertcat(r{:});
                avg{i} = tiersByRow{i}(1,:);
                avg{i}.t0 = mean(tiersByRow{i}.t0);
                avg{i}.t1 = mean(tiersByRow{i}.t1);

                %ToDo standard deviations
            end
            
            tier = vertcat(avg{:});

        end

        function [tier] = splitInterval(tier,intervalIdentifier,splitProp,newLabs)
            arguments
                tier {table}
                intervalIdentifier
                splitProp = 0.5
                newLabs = []
            end
            if ischar(intervalIdentifier), intervalIdentifier = string(intervalIdentifier); end
            if isStringScalar(intervalIdentifier)
                ix = find(tier.text==intervalIdentifier,1,"first");
            elseif isnumeric && isscalar(intervalIdentifier)
                ix = intervalIdentifier;
            else
                ix = [];
            end
            if isempty(ix), return; end

            nsplits = numel(splitProp)+1;

            if isempty(newLabs)
                newLabs = repmat(tier.text(ix),nsplits,1);
            else
                newLabs = newLabs(:);
            end
            if numel(newLabs)~=nsplits, error('number of labels does not match number of intervals'); end

            
            dur = tier.t1(ix)-tier.t0(ix);
            p = [0; splitProp(:); 1];
            new_t = tier.t0(ix)+p*dur;
            tier = tier([1:ix-1 repmat(ix,1,nsplits) (ix+1):end],:);
            tier.t0(ix+(0:nsplits-1)) = new_t(1:end-1);
            tier.t1(ix+(0:nsplits-1)) = new_t(2:end);  
            tier.text(ix+(0:nsplits-1)) = newLabs;
        end

        function [tier] = addInterval(tier,label,dur,varargin)
            if nargin==3
                pos = height(tier)+1;
            elseif nargin==4
                pos = varargin{1};
            elseif nargin==5
                spec = varargin{1};
                switch(lower(spec))
                    case 'before'

                    case 'after'

                end
            end
            warning('off','MATLAB:table:RowsAddedExistingVars');
            newTier = tier([],:);
            newTier.text(1) = label;
            if pos==1
                newTier.t0 = 0;
                tier.t0 = tier.t0+dur;
                tier.t1 = tier.t1+dur;
            else
                newTier.t0 = tier.t1(pos-1);
            end
            newTier.t1 = newTier.t0+dur;

            tier = [tier(1:pos-1,:); newTier; tier(pos:end,:)];

            if ismember('dur',tabcols(tier))
                tier.dur = tier.t1-tier.t0;
            end
        end

        function [tier] = mergeTiers(A,B)
            B = plGrid.shiftTier(B,1);
            B.t0 = B.t0+A.t1(end);
            B.t1 = B.t1+A.t1(end);
            if ismember('dur',tabcols(A)) || ismember('dur',tabcols(B))
                if ~ismember('dur',tabcols(A)), A.dur = A.t1-A.t0; end
                if ~ismember('dur',tabcols(B)), B.dur = B.t1-B.t0; end
            end
            tier = merge_tables(A,B);
        end

        function [tier] = joinTiers(A,B)

            Ainfo = A.Properties.UserData{1};
            Binfo = B.Properties.UserData{1};  
            if Ainfo.class~=Binfo.class
                fprint('ERROR: tiers must be of the same class\n');
                tier=[];
                return;
            end

            tierClass = Ainfo.class;
            tOffset = Ainfo.xmax;
            newXmax = Ainfo.xmax+Binfo.xmax;
            
            switch(tierClass)
                case "TextTier"
                    B.time = B.time+tOffset;                    

                case "IntervalTier"
                    B.t0 = B.t0+tOffset;
                    B.t1 = B.t1+tOffset;

            end
            tier = [A;B];
            tierInfo = Ainfo;
            tierInfo.xmax = newXmax;
            tierInfo.size = height(tier);
            tier.Properties.UserData{1} = tierInfo;
        end

        function [tier] = genFlatStartTier(timeRange,labels)
            arguments
                timeRange
                labels
            end
            if isscalar(timeRange), timeRange = [0 timeRange]; end
            tt = linspace(timeRange(1),timeRange(2),numel(labels)+1);
            tier = plGrid.genTier(tt,labels);
        end
    end
end