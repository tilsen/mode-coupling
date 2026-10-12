classdef gmMetricalizer

    properties
        config modeConfig
        Params = []
        stabTol = 1e-4
        maxIters = 100
        Metricalization = []     
    end

    properties (Constant)
        defaultParams = struct(...
            "beginInput", 0,...
            "endInput",0,...
            "alpha",2/3,... %lateral weight
            "beta",1,...    %global input weight modifier
            "gamma",1/10,...%decay weight
            "internalWeight",2/3,...
            "accentualWeight",2,...
            "beginWeight",1,...
            "endWeight",1);
    end

    methods

        function [obj] = gmMetricalizer(Params,opts)
            arguments
                Params = []
                opts.maxIters = []                
            end

            if isempty(Params) 
                obj.Params = obj.defaultParams;
            elseif ischar(Params) || isstring(Params)
                obj.Params = obj.defaultParams;
                switch(Params)
                    case 'English'                        
                        obj.Params.endInput = -1;
                        obj.Params.beginInput = 0;
                    case 'none'                        
                        obj.maxIters = 0;
                    otherwise
                        error('gmMetricalizer:unknownParams', ...
                            ['Params "%s" is not recognized; ' ...
                             'expected "English" or "none".'],Params);
                end
            elseif isstruct(Params)
                obj.Params = obj.defaultParams;
                fn = fieldnames(Params);
                unknown = setdiff(fn,fieldnames(obj.defaultParams));
                if ~isempty(unknown)
                    error('gmMetricalizer:unknownParam', ...
                        'unknown parameter(s): %s',strjoin(unknown',', '));
                end
                for i=1:numel(fn)
                    obj.Params.(fn{i}) = Params.(fn{i});
                end
            else
                error('gmMetricalizer:badParams', ...
                    ['Params must be [], a preset name, or a struct of ' ...
                     'parameter overrides']);
            end

            if ~isempty(opts.maxIters)
                obj.maxIters = opts.maxIters;
            end
        end

 
        function [config] = metricalize(obj,config,opts)
            arguments
                obj
                config modeConfig
                opts.verbose = false
                opts.outputSimulation = false
                opts.displayOutput = false
            end

            if isempty(config.Metricalization)
                metricalization = obj.initMetricalization(config);
            else
                metricalization = config.Metricalization;
            end

            if obj.maxIters==0
                config.Metricalization = metricalization;
                config.Modes.metricalAct = zeros(height(config.Modes),1);
                return;
            end

            nSylb = height(metricalization.Syllables);
            X = nan(nSylb,obj.maxIters);

            modeOccupation = cellfun(@(c)double(~isempty(c)),config.Modes.sIds);
            modeOccupation_p = modeOccupation(1:2:end);
            modeOccupation_n = modeOccupation(2:2:end);
            metricalization.Syllables.internalAct = modeOccupation_n;

            % only nucleic (non-negative-sign) vocalic excitations carry
            % accentuation into the lexical input
            nucleic = config.Excitations.Class==articulae.V & config.Excitations.Sign~=-1;
            accentualAct = cellfun(@(c,d)sum(config.Excitations.Accentuation(...
                ismember(config.Excitations.Id,c) & config.Excitations.ModeId==d & nucleic)),...
                config.Modes.sIds,num2cell(config.Modes.Id));

            metricalization.Syllables.accentualAct = sum(reshape(accentualAct,2,[]))';

            weights = [obj.Params.internalWeight obj.Params.accentualWeight obj.Params.beginWeight obj.Params.endWeight];
            inputs = table2array(metricalization.Syllables(:,["internalAct" "accentualAct" "beginInput" "endInput"]));
            inputs = sum(inputs .* weights,2);
            inputs = inputs.*modeOccupation_p;
            
            X(:,1) = inputs;

            for i=2:obj.maxIters

                %neighbor influences
                lateral = [0; -X(1:end-1,i-1)] + [-X(2:end,i-1); 0];

                dx_lateral = obj.Params.alpha*tanh(lateral);
                dx_external = obj.Params.beta*(inputs - X(:,i-1));
                dx_norm = -obj.Params.gamma*X(:,i-1);
                dx = dx_lateral+dx_external+dx_norm;

                X(:,i) = X(:,i-1)+dx;

                if all(abs(diff(X(:,i-1:i),[],2))<obj.stabTol)
                    X = X(:,1:i);
                    metricalization.stabilized = true;
                    break;
                end

            end

            if opts.verbose && ~metricalization.stabilized
                fprintf('metricalization not stabilized\n');
            end

            Xfinal = X(:,end);

            Xnorm = Xfinal;

            Xnorm(Xnorm<0)=0; %floor
            if max(Xnorm)~=0
                Xnorm = Xnorm/max(Xnorm);
            end

            if opts.outputSimulation
                metricalization.Sim = X;
                metricalization.FinalNorm = Xnorm;
            end

            metricalization.Syllables.metricalAct = Xnorm;
            config.Metricalization = metricalization;
            config.Modes.metricalAct = repelem(Xnorm,2,1);

            if opts.displayOutput
                out = metricalization.Syllables;
                out.rawAct = Xfinal;
                disp(out);
            end
        end

        function [m] = initMetricalization(obj,config)
            Syllables = config.Modes(config.Modes.Sign==1,:);
            nSylb = height(Syllables);
            Syllables.beginInput = zeros(nSylb,1);
            Syllables.endInput = zeros(nSylb,1);
            Syllables.beginInput(1) = obj.Params.beginInput;
            Syllables.endInput(end) = obj.Params.endInput;
            Syllables.internalAct = zeros(nSylb,1);
            Syllables.metricalAct = zeros(nSylb,1);
            Syllables.accentualAct = zeros(nSylb,1);
            m.Syllables = Syllables;
            m.Sim = [];
            m.stabilized = false;
            m.Params = obj.Params;            
        end

    end
end