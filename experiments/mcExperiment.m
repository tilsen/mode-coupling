classdef mcExperiment

    properties
        TestName
        ConfigData        
        Params
        Runs
        NumReps = 1
        Method = "bonding_stochastic"
        verbose = true
        defaultBeta = 1e6
        defaultStabCrit = 5
        saveDir = "simData"        % relative to the current folder; set to redirect
        overwrite
        Seed
        saveTest = false
        % how much of each run to write out: "iterations" keeps the full
        % relaxation history, "final" keeps only the settled configuration
        SaveDetail (1,1) string {mustBeMember(SaveDetail,["iterations","final"])} = "iterations"
    end

    methods
        function obj = mcExperiment(testName,configData,opts)
            arguments
                testName = "test"
                configData = []                            
                opts.overwrite = false
                opts.dataSource = []
                opts.NumReps = 1
                opts.saveTest = false
                opts.Params = []
                opts.verbose = true
                opts.SaveDetail = []
            end

            obj = handleObjectContructorInputs(obj,opts);
            obj.TestName = testName;
            obj.overwrite = opts.overwrite;

            outputFile = fullfile(obj.saveDir,"simData_" + obj.TestName + ".mat");
            if obj.saveTest && ~obj.overwrite && exist(outputFile,'file')
                fprintf('WARNING: %s exists, will not be saved automatically\n',outputFile);
            end

            if isempty(configData) || ~istable(configData)
                % Resolve the data on the MATLAB path rather than from a
                % hard-coded book/data layout, which lived in another
                % repository and is not here.
                switch(isempty(opts.dataSource))
                    case true
                        dataFiles = string(which("configs.csv"));
                    otherwise
                        dataFiles = arrayfun(@(s)string(which(s + ".csv")),string(opts.dataSource));
                end

                if isempty(dataFiles) || any(dataFiles=="")
                    error('mcExperiment:dataNotFound', ...
                        'config data file not found on the path (looked for: %s)', ...
                        strjoin(string(opts.dataSource)+".csv"," "));
                end

                % tabread, not readtable: readtable types the all-empty
                % params column as double and shifts the rest, so trans
                % comes back numeric and configLabels fails on it
                data = [];
                for i=1:numel(dataFiles)
                    data = [data; tabread(dataFiles(i),'Delimiter',',')]; %#ok<AGROW>
                end
                data = configLabels(data);

                if ~isempty(configData)
                    switch(isnumeric(configData))
                        case false
                            if colExists(data,'group') && all(ismember(configData,data.group))
                                data = data(ismember(data.group,configData),:);
                            else
                                data = data(ismember(data.word,configData),:);
                            end
                            if height(data)==0, fprintf('config name: %s not found\n',configData); return; end
                        case true
                            data = data(configData,:);
                    end
                end
            else
                data = configData;
            end

            obj.ConfigData = data;
            if opts.verbose
                %defWeights = gmConfigurator.defWeights();
            end

        end

        function [obj] = run(obj,numReps)
            arguments
                obj
                numReps = []
            end
            obj.Seed = randi(2^32-1);
            rng(obj.Seed);
            if ~isempty(numReps)
                obj.NumReps = numReps;
            end
            numReps = obj.NumReps;
            obj = obj.constructRuns();
            pm = progressMonitor(height(obj.Runs)*numReps);
            for i=1:height(obj.Runs)
                mc = modeConfig(obj.Runs.form(i));
                for j=1:numReps
                    pm.update(numReps*(i-1)+j,sprintf('set %d, rep %d: ',i,j));
                    cg(i,j) = gmConfigurator(mc);
                    cg(i,j).Weights = obj.Runs.Weights(i);
                    cg(i,j).Beta = obj.Runs.beta(i);
                    cg(i,j).StabCrit = obj.Runs.StabCrit(i);
                    cg(i,j) = cg(i,j).genModeConfig(Method=obj.Method);
                end
                obj.Runs.configs(i,:) = cg(i,:);
                obj.Runs.runData(i) = analyzeConfigurations(cg(i,:),"stabilizedOnly",false,"targets",obj.Runs.target);
            end
            pm.reset();
            if obj.saveTest, obj.save(); end
        end

        function [obj] = constructRuns(obj)
            Weights = gmConfigurator.defWeights();               
            if isempty(obj.Params) 
                obj.Params = struct('beta',obj.defaultBeta,'StabCrit',obj.defaultStabCrit);
            end
            if ~isfield(obj.Params,'beta'), obj.Params.beta = obj.defaultBeta; end            
            if ~isfield(obj.Params,'StabCrit'), obj.Params.StabCrit = obj.StabCrit; end            

            pf = fieldnames(obj.Params);
            wf = intersect(fieldnames(Weights),pf);
            xf = setdiff(pf,wf);

            if numel(wf)>1
                wcombos = obj.Params.(wf{1})(:)';
                for i=2:numel(wf)
                    c = obj.Params.(wf{i})(:)';
                    wcombos = combvec(wcombos,c);
                end
                wcombos = wcombos';
            elseif numel(wf)==0
                wcombos = zeros(1,0);
            else
                wcombos = reshape(obj.Params.(wf{1}),[],1);
            end

            if numel(xf)>1                
                switch(numel(xf))
                    case 2
                        pcombos = combvec(obj.Params.(xf{1}),obj.Params.(xf{2}))';
                end
            else
                pcombos = reshape(obj.Params.(xf{1}),[],1);
            end
            runs = array2table(pcombos,'VariableNames',xf);

            Weights = repmat(Weights,size(wcombos,1),1);
            for i=1:numel(wf)
                vals = num2cell(wcombos(:,i));
                [Weights.(wf{i})] = vals{:};
            end

            nR = height(runs);
            runs = repmat(runs,numel(Weights),1);
            runs.Weights = repelem(Weights,nR,1);

            obj.Runs = [repelem(obj.ConfigData,height(runs),1) repmat(runs,height(obj.ConfigData),1)];

            obj.Runs.paramLabel = "\beta=" + obj.Runs.beta;
            for i=1:numel(wf)
                obj.Runs.paramLabel = obj.Runs.paramLabel + ", " + wf{i} + "=" + ...
                    arrayfun(@(c)string(c.(wf{i})),obj.Runs.Weights);
            end
        end

        function [] = save(obj,opts)
        % SAVE  Write the test to saveDir, at the chosen level of detail.
        %
        %   t.save()                    % obj.SaveDetail (default "iterations")
        %   t.save(Detail="final")      % drop the relaxation history
        %
        % "iterations" keeps each configurator's full IterConfigs, so
        % plotIters(), inspect() and findConfigs(iters=...) still work off
        % the saved file. "final" keeps only the configuration each run
        % settled on, which is all plotConfigs() and the run analyses need
        % and is much smaller -- the relaxation history dominates the file.
            arguments
                obj
                opts.Detail (1,1) string {mustBeMember(opts.Detail,["iterations","final"])} = obj.SaveDetail
            end
            outputFile = fullfile(obj.saveDir,"simData_" + obj.TestName + ".mat");
            if ~obj.overwrite && exist(outputFile,'file')
                fprintf('%s exists, not overwriting\n',outputFile);
                return;
            end
            if ~isfolder(obj.saveDir), mkdir(obj.saveDir); end

            % NB: only the first rep of each run is kept, whatever the
            % detail level -- long-standing behaviour, and lossy when
            % NumReps>1 (plotConfigFreq needs every rep).
            obj.Runs.configs = obj.Runs.configs(:,1);

            if opts.Detail=="final"
                obj.Runs.configs = arrayfun(@mcExperiment.stripIterations,obj.Runs.configs);
            end

            save(outputFile,'obj');
            d = dir(outputFile);
            fprintf('saved %s (detail: %s, %.1f MB)\n', ...
                outputFile,opts.Detail,d.bytes/1024^2);
        end

        function [runs] = selectRuns(obj,runInfo)
            if iscell(runInfo)
                for i=1:2:numel(runInfo)
                    runs = tabindex(obj.Runs,runInfo{i},runInfo{i+1});
                end
            elseif ~isempty(runInfo) && isnumeric(runInfo)
                runs = obj.Runs(runInfo,:);
            else
                runs = obj.Runs;
            end
        end

        function p = plotter(obj)
            p = mcExperimentPlot(obj);
        end

        function configPlots = plotConfigs(obj,varargin)
            configPlots = obj.plotter().plotConfigs(varargin{:});
        end

        function fig = plotConfigFreq(obj,varargin)
            fig = obj.plotter().plotConfigFreq(varargin{:});
        end

        function plotGraphs(obj,varargin)
            obj.plotter().plotGraphs(varargin{:});
        end

        function h = plotGraph(obj,varargin)
            h = obj.plotter().plotGraph(varargin{:});
        end

    end

    methods (Static)
        function cfg = stripIterations(cfg)
        % Drop a configurator's relaxation history, keeping the settled
        % configuration. IterConfigs is left holding that one entry rather
        % than emptied, because plotFinal() reads IterConfigs(end).
            cfg.IterConfigs = cfg.FinalConfig;
            cfg.Decisions = {};
        end
    end
end
