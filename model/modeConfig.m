classdef modeConfig

    properties
        Excitations
        Modes
        Metricalization
        Energies
        modeLabelType = 'default'        
        Weights        
        Iters = {}    
        PhoneSeq        
    end

    properties (Constant)
        ExcitationCols = ["Name" "ModeId" "Activation" "Accentuation" "Phase" "qState" "Sign" "Type" "Class" "Symb" "Label" "Id"];
        ExcitationDefaultValues = {"",NaN,NaN,NaN,NaN,NaN,0,NaN,NaN,"","",uint8(nan)};
    end

    properties (Dependent)
        Articulae
    end

    methods
        function obj = modeConfig(configInfo,opts)
            arguments
                configInfo = []
                opts.Weights = []
            end
            if isempty(configInfo), return; end
            obj.Articulae = articulae();
            
            if isempty(configInfo)
                obj.Excitations = [];
                obj.Modes = [];
                return
            end
            if ischar(configInfo) || isStringScalar(configInfo)
                obj = obj.initFromPhoneSeq(configInfo);
                obj = obj.initModePairs();
            elseif iscell(configInfo) %excitation and mode tables in cell array
                obj.Excitations = configInfo{1};                
                obj.Modes = configInfo{2};
            elseif istable(configInfo) %excitations table with specified modes
                obj = obj.initExcitations(configInfo);
                obj = obj.initModes(unique(obj.Excitations.ModeId));
            else
                error('%s: unknown input format\n',mfilename);                                        
            end        
            if isempty(opts.Weights)
                obj.Weights = gmConfigurator.defWeights();
            else
                obj.Weights = opts.Weights;
            end
            obj = obj.calcEnergies();
            obj = obj.updateStates();            
        end

        function [obj] = tokenize(obj)
            [~,ia] = ismember(strrep(obj.Excitations.Name,'~',''),obj.Articulae.Gestures.Name);
            obj.Excitations.Id = obj.Articulae.Gestures.Id(ia);
        end

        function a = get.Articulae(~)
            a = articulae();            % hits the persistent cache
        end

        function obj = set.Articulae(obj,~)
            % ignored: fetched from the cache, never stored
        end

        function [obj] = calcEnergies(obj,weights,opts)
            arguments
                obj
                weights=[]
                opts.halt = false                
            end
            if isempty(weights)
                weights = obj.Weights; 
            end
            if isstruct(weights)
                weights = arrayfun(@(t)weights.(t), gmConfigurator.EnergyTerms);             
            end
            obj.Energies = configEnergies(obj,weights,halt=opts.halt);
        end

        function obj = initFromPhoneSeq(obj,phoneStr)
            obj.PhoneSeq = phoneStr;

            % Markers, per token: each ^ adds one unit of accentuation; a +
            % (length) adds a non-nucleic copy of the phone after it
            % ("a+" -> "a ~a"). Accentuation stays with the first half.
            % Counting after the expansion keeps it aligned with the phones.
            toks = string(strsplit(strtrim(char(phoneStr))));
            phones = strings(1,0);
            accentuations = zeros(1,0);
            for i = 1:numel(toks)
                base = erase(erase(toks(i),"^"),"+");
                phones(end+1) = base; %#ok<AGROW>
                accentuations(end+1) = count(toks(i),"^"); %#ok<AGROW>
                if contains(toks(i),"+")
                    phones(end+1) = "~" + base; %#ok<AGROW>
                    accentuations(end+1) = 0; %#ok<AGROW>
                end
            end
            phoneStr = strjoin(phones," ");

            gests = obj.Articulae.PhonesToGests(phoneStr);
            activations = linspace(1,0,numel(gests)+1);

            % Affricates map to two Class-C gesturals -- a closure and the
            % narrowing that releases it (e.g. ch -> TT clo, Tb nar) -- which
            % must not activate simultaneously; split such phones across the
            % lower half of their slot instead of the usual flat activation.
            G = obj.Articulae.Gestures;
            act = cell(size(gests));
            acc = cell(size(gests));
            for i = 1:numel(gests)
                names = strrep(gests{i},'~','');
                [~,ia] = ismember(names,G.Name);
                isC = reshape(G.Class(ia)=="C",size(names));
                isClo = isC & endsWith(names,' clo');
                isNar = isC & endsWith(names,'nar'); % ' nar' and 'latnar'
                a = repmat(activations(i),1,numel(names));
                if any(isClo) && any(isNar)
                    a(isNar) = activations(i) - 0.5*(activations(i)-activations(i+1));
                end
                act{i} = a;
                % accentuation is a property of the phone's vocalic
                % gestural only, not of its consonantal or d-type ones
                acc{i} = accentuations(i) * reshape(G.Class(ia)=="V",size(names));
            end

            Exc.Name = horzcat(gests{:})';
            Exc.Activation = horzcat(act{:})';
            Exc.Accentuation = horzcat(acc{:})';

            obj = obj.initExcitations(struct2table(Exc));         
        end

        function obj = initExcitations(obj,excitations)
            addCols = repmat(obj.excitation(),height(excitations),1);
            obj.Excitations = [excitations addCols(:,setdiff(tabcols(addCols),tabcols(excitations)))];
            obj.Excitations = obj.Excitations(:,obj.ExcitationCols);  
            obj = obj.updateExcitationProps();  
        end

        function obj = initModePairs(obj,numModePairs)
            if nargin==1, numModePairs = obj.numModePairsFromSystems(obj.Excitations); end
            obj = obj.initModes(repelem((1:numModePairs)',2,1) .* repmat([1;-1],numModePairs,1));
        end

        function obj = initModes(obj,modeIds)
            obj.Modes = array2table(modeIds(:),'VariableNames',{'Id'});
            obj.Modes.PairNum = abs(obj.Modes.Id);
            obj.Modes.Sign = sign(obj.Modes.Id);            
            modeSign = repmat("＋",height(obj.Modes),1);
            modeSign(obj.Modes.Sign==-1) = "–";
            switch(obj.modeLabelType)
                case 'default'
                    obj.Modes.Label = string(modeSign);
                case 'num'
                    obj.Modes.Label = string(obj.Modes.PairNum) + "^{" + modeSign + "}";
                case 'mu'
                    obj.Modes.Label = "μ_{" + obj.Modes.PairNum + "}^" + modeSign;
            end            
            obj.Modes.sIds = repmat({uint8(zeros(1,0))},height(obj.Modes),1);
            obj.Modes.metricalAct = zeros(height(obj.Modes),1);
        end

        function obj = addExcitation(obj,name,activation)
            exc = obj.excitation();
            exc.Name = string(name); 
            exc.Activation = activation;
            obj.Excitations = [obj.Excitations; exc];
            obj = obj.updateExcitationProps();
        end

        function obj = updateExcitationProps(obj)
            obj.Excitations = sortrows(obj.Excitations,'Activation','descend');
            obj = obj.defExcitationProps();
            obj.Excitations.Label(obj.Excitations.Label=="") = obj.Excitations.Symb(obj.Excitations.Label=="");
            obj = obj.tokenize();            
        end

        function [obj] = defExcitationProps(obj)
            [ix,ia] = ismember(strrep(obj.Excitations.Name,'~',''),obj.Articulae.Gestures.Name);
            obj.Excitations.Class = obj.Articulae.Gestures.ClassCode(ia(ix));
            obj.Excitations.Type = double(ismember( ...
                articulae.ClassLevels(obj.Excitations.Class), articulae.iType));
            obj.Excitations.Symb = obj.Articulae.Gestures.Symb(ia(ix));
            obj.Excitations.Sign = ones(height(obj.Excitations),1);
            obj.Excitations.Sign(contains(obj.Excitations.Name,'~'))=-1;
        end

        function [act] = getActivation(obj,name,relLevel,selectIndex)
            arguments
                obj
                name
                relLevel = []               
                selectIndex = 1
            end
            ix = find(obj.Excitations.Name==name);
            if isempty(ix)
                error('modeConfig:noExcitation','no %s excitations',name);
            end
            ix = ix(selectIndex);
            act = obj.Excitations.Activation(ix);
            if ~isempty(relLevel) && relLevel~=0
                if relLevel>0
                    ix = find(obj.Excitations.Activation>act,1,'last');
                else
                    ix = find(obj.Excitations.Activation<act,1,'first');
                end
                if isempty(ix)
                    error('modeConfig:noActivationLevel', ...
                        'no excitation level %d relative to %s',relLevel,name);
                end
                act = obj.Excitations.Activation(ix);
            end
        end

        function [obj] = updateStates(obj)
            modeIds = obj.Excitations.ModeId;
            ids     = obj.Excitations.Id;

            [~,~,pc] = unique(obj.Excitations.Phase);
            obj.Excitations.qState = (modeIds*8 + obj.Excitations.Class)*1000 + pc;

            [tf,g] = ismember(modeIds, obj.Modes.Id);
            nM = height(obj.Modes);
            if any(tf)
                obj.Modes.sIds = accumarray(g(tf), find(tf), [nM 1], ...
                    @(ix){ids(ix)'}, {uint8(zeros(1,0))});
            else
                obj.Modes.sIds = repmat({uint8(zeros(1,0))},nM,1);
            end
        end

        function phases = genPhases(obj)
                        
            phases = nan(height(obj.Excitations),1);
            eMode  = obj.Excitations.ModeId;
            eClass = obj.Excitations.Class;
            eType  = obj.Excitations.Type;
            eAct   = obj.Excitations.Activation;
            mId    = obj.Modes.Id;
            mSign  = obj.Modes.Sign;
            nM     = numel(mId);

            modeIxs = eMode==mId.';
            vIx = modeIxs & eClass==articulae.V;
            cIx = modeIxs & eClass==articulae.C;
            iIx = modeIxs & eType==1;

            % every d-type class gets its own copy of the C-phase pattern,
            % so loop over them instead of repeating the block per class
            % (was hardcoded to G and N)
            dClasses = find(ismember(articulae.ClassLevels, articulae.dType));
            dIx = arrayfun(@(g){modeIxs & eClass==g}, dClasses);

            for i=1:nM
                nC = sum(cIx(:,i));
                nI = sum(iIx(:,i));

                switch(mSign(i))
                    case 1 %{+} modes
                        phases(vIx(:,i)) = 0; %all vowels zero-phase
                        phases(cIx(:,i)) = (nC-1 : -2 : 1-nC)/(2*(nC-1)+(nC==1));

                    case -1 %{-} modes
                        phases(iIx(:,i)) = (nI-1 : -2 : 1-nI)/(2*(nI-1)+(nI==1)); %all i-types repulsively coupled
                end

                %d-flavor excitations: each takes the phase of an i-type
                %with the same activation (C preferred over V), as in
                %relativePhaseDynamics; any without one falls back to the
                %positional match against the C phases
                for k = 1:numel(dIx)
                    dk = dIx{k}(:,i);
                    if any(dk)
                        p = zeros(sum(dk),1);
                        p(1:nC,1) = phases(cIx(:,i));
                        p = p(1:sum(dk));
                        dRows = find(dk);
                        for r = 1:numel(dRows)
                            sameAct = eAct==eAct(dRows(r));
                            m = find(cIx(:,i) & sameAct,1);
                            if isempty(m), m = find(iIx(:,i) & sameAct,1); end
                            if ~isempty(m), p(r) = phases(m); end
                        end
                        phases(dk) = p;
                    end
                end

            end

            obj.Excitations.Phase = phases;
        end

        function cP = plotter(obj,opts)
            arguments
                obj
                opts.?plotopts.ConfigurationGeometry
            end
            args = namedargs2cell(opts);
            cP = modeConfigPlot(obj,args{:});
        end

        function cP = plot(obj,opts)
            arguments
                obj
                opts.?plotopts.Configuration
            end
            geometry = plotopts.Base.select(opts,plotopts.ConfigurationGeometry());
            drawing = plotopts.Base.select(opts,plotopts.ConfigurationDrawing());
            args = namedargs2cell(geometry);
            cP = obj.plotter(args{:});
            args = namedargs2cell(drawing);
            cP = cP.plot(args{:});
        end

        function m = plotActivationLevels(obj,opts)
            arguments
                obj
                opts.?plotopts.ActivationLevels
            end
            args = namedargs2cell(opts);
            m = obj.plotter().plotActivationLevels(args{:});
        end

        function h = plotMetricalization(obj,opts)
            arguments
                obj
                opts.?plotopts.Metricalization
            end
            args = namedargs2cell(opts);
            h = obj.plotter().plotMetricalization(args{:});
        end

        function h = plotMetricalGraph(obj,opts)
            arguments
                obj
                opts.?plotopts.MetricalGraph
            end
            args = namedargs2cell(opts);
            h = obj.plotter().plotMetricalGraph(args{:});
        end

        function h = plotEnergy(obj,opts)
            arguments
                obj
                opts.?plotopts.Energy
            end
            args = namedargs2cell(opts);
            h = obj.plotter().plotEnergy(args{:});
        end

        function [strsOut] = ToLabels(obj,opts)
            arguments
                obj
                opts.separator = ""
                opts.style = 'short'
                opts.uncoupled = true                
            end
            strs = obj.ToStrings(separator=opts.separator,style=opts.style);
            strs = regexprep(strs,'^{','\\{');
            strs = regexprep(strs,'}$','\\}');
            strsOut = strjoin(strs,'');
        end

        function [strs] = ToStrings(obj,opts)
            arguments
                obj
                opts.separator = ""
                opts.style = 'default'
                opts.escapeGroups = false
            end
            strs = repmat("",height(obj.Modes),1);
            for i=1:height(obj.Modes)
                E = obj.Excitations(obj.Excitations.ModeId==obj.Modes.Id(i),:);
                E.Class = articulae.ClassLevels(E.Class);
                E = sortrows(E,["Phase" "Activation" "Class"],{'descend' 'descend' 'ascend'});

                switch(opts.style)
                    case 'short'
                        c = false;
                        for j=1:height(E)
                            switch(E.Class(j))
                                case {'C','V'}
                                    strs(i)=strs(i)+E.Symb(j);
                                    c = true;
                                case {'N','R'}
                                    switch(c)
                                        case true
                                            strs(i)=strs(i)+"^{"+E.Symb(j)+"}";
                                        otherwise
                                            strs(i)=strs(i)+E.Symb(j);
                                    end
                                case {'G','L'}
                                    switch(c)
                                        case true
                                            strs(i)=strs(i)+"_{"+E.Symb(j)+"}";
                                        otherwise
                                            strs(i)=strs(i)+E.Symb(j);
                                    end
                            end
                        end

                    otherwise
                        strs(i) = strjoin(E.Symb,opts.separator);
                end
            end

            if opts.escapeGroups
                strs = "\{" + strs + "\}";
            else
                strs = "{" + strs + "}";
            end

            if any(isnan(obj.Excitations.ModeId))
                uncoupled = obj.Excitations(isnan(obj.Excitations.ModeId),["Activation" "Class" "Symb"]);
                uncoupled.Class = articulae.ClassLevels(uncoupled.Class);
                uncoupled = sortrows(uncoupled,{'Activation' 'Class'},{'descend' 'ascend'});
                strs(end+1) = strjoin(uncoupled.Symb,opts.separator);
            end
        end

        function [str] = ToString(obj,opts)
            arguments
                obj
                opts.separator = ""
                opts.style = 'default'
                opts.uncoupled = true;
            end
            strs = obj.ToStrings(separator=opts.separator,style=opts.style);            
            switch(~opts.uncoupled & ~contains(strs(end),'{'))
                case true                    
                    str = strjoin(strs(1:end-1),opts.separator);
                case false
                    str = strjoin(strs,opts.separator);
            end
        end
    end

    methods (Static)
        function [initExc] = phoneSeqToExcitation(phoneSeq,opts)
            % initFromPhoneSeq's activations as a gesturals x excitations
            % array: each gestural's excitations fill its columns in order
            % of decreasing activation
            arguments
                phoneSeq
                opts.nExcitations = 10
            end
            mc = modeConfig().initFromPhoneSeq(phoneSeq);
            G = mc.Articulae.Gestures;
            E = mc.Excitations;                       % sorted by descending activation
            [~,gIx] = ismember(strrep(E.Name,'~',''),G.Name);
            initExc = zeros(height(G),opts.nExcitations);
            for k = 1:height(E)
                eIx = find(initExc(gIx(k),:)==0,1,'first');
                if isempty(eIx)
                    error('modeConfig:tooManyExcitations', ...
                        '%s has more than %d excitations',G.Name(gIx(k)),opts.nExcitations);
                end
                initExc(gIx(k),eIx) = E.Activation(k);
            end
        end

        function [] = applyStateFormat(obj)
            
            if all(isa(obj,'matlab.ui.Figure')) || all(isa(obj,'matlab.graphics.axis.Axes'))
                textObjs = findall(obj,'Type','text');

            elseif isa(obj,'matlab.graphics.primitive.Text')                
                textObjs = obj;
            else
                return;
            end      


            for i=1:numel(textObjs)
                modeConfig.formatState(textObjs(i));
            end

        end

        function [] = formatState(obj,opts)
            arguments
                obj
                opts.color = false
                opts.propSub = [0.75 0.65]
                opts.propSup = [0.75 0.45]
            end

            % symbols needing shrunk sizing are just "the symbols of the
            % superscript/subscript classes" -- N/R render superscript,
            % G/L render subscript (see ToStrings) -- so pull them from
            % the live inventory instead of a separate hardcoded list
            Artic = articulae();
            supSymbols = Artic.Gestures.Symb(ismember(Artic.Gestures.Class,["N" "R"]));
            subSymbols = Artic.Gestures.Symb(ismember(Artic.Gestures.Class,["G" "L"]));

            newStr = obj.String;
            for i=1:numel(supSymbols)
                prop = opts.propSup(mod(i-1,numel(opts.propSup))+1);
                fontSize = ['\\fontsize{' num2str(max(round(obj.FontSize*prop),1)) '}'];
                newStr = regexprep(newStr,['\^\{(' char(supSymbols(i)) ')\}'], ...
                    ['^{' fontSize '$1}' char(8201)]);
            end
            for i=1:numel(subSymbols)
                prop = opts.propSub(mod(i-1,numel(opts.propSub))+1);
                fontSize = ['\\fontsize{' num2str(max(round(obj.FontSize*prop),1)) '}'];
                newStr = regexprep(newStr,['_\{(' char(subSymbols(i)) ')\}'], ...
                    ['_{' fontSize '$1}']);
            end
            obj.String = newStr;
        end

        function exc = excitation()
            exc = cell2table(modeConfig.ExcitationDefaultValues,...
                'VariableNames',modeConfig.ExcitationCols);
        end

        function [nModePairs] = numModePairsFromSystems(Sys)
            nModePairs = sum(Sys.Class==articulae.V & Sys.Sign~=-1);
        end
     
    end
end

