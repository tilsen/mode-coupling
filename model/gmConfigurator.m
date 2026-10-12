classdef gmConfigurator

    properties
        InitConfig modeConfig
        IterConfigs modeConfig
        FinalConfig modeConfig        
        Weights        
        Method = "bonding_stochastic"
        Beta = 1e6; % colder as beta -> inf, only most likely configuration
        MaxIters = 100;
        StabCrit = 5;
        Stabilized
        Metricalizer = "English"
        Decisions = {}
    end

    properties (SetAccess = private)
        % settings the last genModeConfig call actually ran with (its
        % options override Method/Beta/StabCrit for that run only)
        LastRun = struct()
    end

    properties (Constant)
        Params = ["Beta" "StabCrit" "MaxIters" "Method" "Metricalizer"];
        EnergyTerms = ["nucleic" "exclusion" "dependency" "phasebias" ...
                   "adaptation" "phonotactics" "bound" "unbound"];
        defaultWeightsSource = "defaultWeights"
    end

    methods
        
        function [obj] = gmConfigurator(init)
            if nargin==0
                obj.InitConfig = [];
                obj.Weights = [];
            else
                obj.InitConfig = init; 
                obj.Weights = obj.defWeights();
            end
        end

        function obj = genModeConfig(obj,opts)
            arguments
                obj
                opts.Method = []
                opts.beta = []
                opts.StabCrit = []
                opts.recordDecisions = false
            end
            
            obj.InitConfig.Weights = obj.Weights;
            weights = obj.Weights;
            terms = gmConfigurator.EnergyTerms;
            weights = arrayfun(@(t)weights.(t), terms);   

            % options apply to this run only; the object's own
            % Method/Beta/StabCrit are left as they are
            method = lower(obj.Method);
            if ~isempty(opts.Method), method = lower(opts.Method); end
            beta = obj.Beta;
            if ~isempty(opts.beta), beta = opts.beta; end
            stabCrit = obj.StabCrit;
            if ~isempty(opts.StabCrit), stabCrit = opts.StabCrit; end
            obj.LastRun = struct('Method',string(method),'Beta',beta, ...
                'StabCrit',stabCrit,'MaxIters',obj.MaxIters,'Weights',obj.Weights);

            if string(class(obj.Metricalizer))~="gmMetricalizer"
                obj = obj.initMetricalizer();
            end

            obj.InitConfig = obj.metricalize(obj.InitConfig);
            
            obj.IterConfigs(1) = obj.InitConfig;

            iter = 1;
            noChange = 0;
            obj.Stabilized = false;


            while iter<obj.MaxIters
                iter = iter+1;
                
                %calculate energy from all possible demotions and bonding,
                %includes current configuration:
                altConfigs = obj.getAltConfigs(obj.IterConfigs(iter-1));
                
                for i=1:numel(altConfigs)
                    altConfigs(i) = altConfigs(i).calcEnergies(weights);
                end
                altE = arrayfun(@(c)c.Energies.totalE,altConfigs);
                currentE = obj.IterConfigs(iter-1).Energies.totalE;

                selIx = [];

                switch(method)
                    case 'ideal_relaxation'
                        [minEn,minIx] = min(altE);
                        if minEn<currentE, config = altConfigs(minIx); selIx=minIx; end

                    case 'bonding_stochastic'                        
                        dE = altE-currentE;
                        dE = dE / norm(weights,1); %beta will be per units of normalized energy
                        w = exp(-beta*(dE-min(dE))); %boltzmann weights
                        w(~isfinite(w))=0;
                        s = sum(w);
                        if s~=0
                            p = w/s;
                            ix = find(rand<=cumsum(p),1,'first');
                            config = altConfigs(ix);
                            selIx = ix;
                        end

                    otherwise
                        % No silent fall-through: an unrecognized name
                        % would leave config unchanged and be reported as
                        % a stabilized run.
                        error('gmConfigurator:unknownMethod', ...
                            ['Unknown Method "%s". Expected one of: ' ...
                             'ideal_relaxation, bonding_stochastic.'],method);
                end
                
                if opts.recordDecisions && ~isempty(selIx)
                    Xalt = cell2mat(arrayfun(@(c){sum(c.Energies.X,1)}, altConfigs(:)));
                    obj.Decisions{end+1} = struct('X',Xalt,'selected',selIx,'iter',iter);
                end

                config = obj.metricalize(config);
                
                obj.IterConfigs(iter) = config;

                if obj.configsEqual(obj.IterConfigs(iter),obj.IterConfigs(iter-1))
                    noChange = noChange+1;
                    if noChange>=stabCrit
                        obj.Stabilized = true;
                        break;
                    end
                else
                    noChange = 0; % Reset noChange counter if configuration changes
                end                
            end
            obj.IterConfigs = obj.IterConfigs(1:end-stabCrit+1); %included repeated iteration
            obj.FinalConfig = obj.IterConfigs(end);
        end

        function [n] = numIters(obj)
            n = numel(obj.IterConfigs);
        end
        
        function [obj] = initMetricalizer(obj)
            obj.Metricalizer = gmMetricalizer(obj.Metricalizer);
        end

        function [config] = metricalize(obj,config)
            if string(class(obj.Metricalizer))=="gmMetricalizer"
                config = obj.Metricalizer.metricalize(config);
            else
                obj = obj.initMetricalizer();
                config = obj.Metricalizer.metricalize(config);
            end
        end

        function [p] = plotter(obj)
            p = gmConfiguratorPlot(obj);
        end

        function [cPlot] = plotFinal(obj,opts)
            arguments
                obj
                opts.?plotopts.Configuration
            end
            args = namedargs2cell(opts);
            cPlot = obj.plotter().plotFinal(args{:});
        end

        function [obj,h] = inspect(obj,startIter,opts)
            arguments
                obj
                startIter = 1;
                opts.?plotopts.Inspector
            end
            args = namedargs2cell(opts);
            h = obj.plotter().inspect(startIter,args{:});
        end

        function [configPlots] = plotIters(obj,plotIters,opts)
            arguments
                obj
                plotIters = []
                opts.?plotopts.Iterations
            end
            args = namedargs2cell(opts);
            configPlots = obj.plotter().plotIters(plotIters,args{:});
        end

        function [pars] = getParams(obj)
            pars = obj.Weights;
            for i=1:length(obj.Params)
                pars.(obj.Params(i)) = obj.(obj.Params(i));
            end
        end
        function [obj] = setParams(obj,paramsStr)
            paramsStr = string(paramsStr);
            if isempty(paramsStr) || all(ismissing(paramsStr)) || all(strlength(paramsStr)==0), return; end
            paramsVals = regexp(paramsStr,'\[(.*?)\]','match');

            for j=1:numel(paramsVals)
                strs = strsplit(regexprep(paramsVals(j),'\[|\]',''),' ');
                name = strs(1);
                if ismember(name,["Metricalizer" "Method"])
                    obj.(name) = strs(2);
                    continue
                end
                value = str2double(strs(2));
                if isnan(value)
                    error('gmConfigurator:badParamValue', ...
                        'value "%s" for "%s" is not numeric',strs(2),name);
                end
                if ismember(name,obj.Params)
                    obj.(name) = value;
                elseif ismember(name,gmConfigurator.EnergyTerms)
                    obj.Weights.(name) = value;
                else
                    error('gmConfigurator:unknownParam', ...
                        '"%s" is neither a configurator parameter (%s) nor an energy term (%s)', ...
                        name,strjoin(obj.Params,', '),strjoin(gmConfigurator.EnergyTerms,', '));
                end
            end
        end
    end

    methods (Static)
        function [weights] = defWeights(opts)
            arguments
                opts.refresh (1,1) logical = false % re-read the CSV
            end
            persistent cachedWeights
            if isempty(cachedWeights) || opts.refresh
                cachedWeights = struct();
                w = tabread(gmConfigurator.defaultWeightsFile());
                for i=1:height(w)
                    cachedWeights.(w.term{i}) = w.value(i);
                end
            end
            weights = cachedWeights;
        end
        function [] = editDefaultWeights(varargin)
            % editDefaultWeights("exclusion",20,"phasebias",0.1)
            if nargin<2 || mod(nargin,2)~=0
                error('gmConfigurator:editDefaultWeights', ...
                    'specify weight,value pairs');
            end
            file = gmConfigurator.defaultWeightsFile();
            w = tabread(file);
            terms = string(w.term);
            names = string(varargin(1:2:end));
            values = [varargin{2:2:end}];
            unknown = names(~ismember(names,terms));
            if ~isempty(unknown)
                error('gmConfigurator:editDefaultWeights', ...
                    'unknown weight(s): %s',strjoin(unknown,', '));
            end
            for i=1:numel(names)
                w.value(terms==names(i)) = values(i);
            end
            writetable(w,file);
            gmConfigurator.defWeights(refresh=true); % drop the cached defaults
        end
        function [filePath] = defaultWeightsFile()            
            filePath = which(gmConfigurator.defaultWeightsSource()+".csv");
        end
        function [same] = configsEqual(config1,config2)
            same = false;                        
            if ~all(isequaln(config1.Excitations.ModeId,config2.Excitations.ModeId)), return; end
            if ~all(isequaln(config1.Excitations.Phase,config2.Excitations.Phase)), return; end
            same = true;
        end
        %
        function [altConfigs] = getAltConfigs(config,includeCurrent,opts)
            % Unique candidate states by default; unique=false retains
            % transition multiplicities. includeCurrent=false excludes no-ops.
            arguments
                config
                includeCurrent (1,1) logical = true
                opts.unique (1,1) logical = true
            end
            modeIds = config.Modes.Id;
            cs = config.Excitations.ModeId;
            qs = string(cs) + "," + string(config.Excitations.Phase);

            bondings = cellfun(@(c){gmConfigurator.bondSys(cs,modeIds,c)},...
                num2cell(find(isnan(cs))));
            if isempty(bondings), bondings = {}; end

            %unique qStates of coupled systems not in the lowest mode
            %(uncoupled ones have no orbit to demote):
            q1 = unique(qs(~isnan(cs) & cs~=modeIds(end)),'stable');
            demotionCands = arrayfun(@(c){find(qs==c)'},q1);

            if ~iscell(demotionCands), demotionCands = {demotionCands}; end

            %demotionCands = num2cell(find(~isnan(cs) & cs~=modeIds(end)));
            demotions = cellfun(@(c){gmConfigurator.demoteSys(cs,modeIds,c)},demotionCands);

            if isempty(demotions), demotions = {}; end

            alt_configs = [bondings{:} demotions{:}];
            altConfigs = repmat(config,size(alt_configs,2),1);
            for i=1:numel(altConfigs)
                altConfigs(i).Excitations.ModeId = alt_configs(:,i);
                altConfigs(i).Excitations.Phase = altConfigs(i).genPhases();
                altConfigs(i) = altConfigs(i).updateStates();
            end
            stateKey = @(c)string(mat2str( ...
                [c.Excitations.ModeId(:),c.Excitations.Phase(:)],17));
            if includeCurrent
                altConfigs(end+1) = config;
            else
                keys = arrayfun(stateKey,altConfigs);
                altConfigs(keys==stateKey(config)) = [];
            end
            if opts.unique && ~isempty(altConfigs)
                keys = arrayfun(stateKey,altConfigs);
                [~,keep] = unique(keys,'stable');
                altConfigs = altConfigs(keep);
            end

            
        end

        %bondings
        function [configs] = bondSys(config,modeIds,c)
            configs = repmat(config,1,numel(modeIds));
            configs(c,:) = modeIds;
        end

        % demote system in configuration
        function [config] = demoteSys(config,modeIds,sys)
            demoteMode = @(x)-sign(x).*(abs(x)+1*(sign(x)==-1));
            newModes = demoteMode(config(sys));
            config(sys(ismember(newModes,modeIds))) = newModes(ismember(newModes,modeIds));
        end

        function [T] = energiesTable(configE,opts)
            arguments
                configE
                opts.sort = true
            end
            T = array2table(configE.modeEnergies,'VariableNames',configE.energyTerms);
            if opts.sort
                [~,srtixs] = sort(configE.weights,'descend');
                T = T(:,srtixs);
            end
        end
    end

end