classdef tdModel
    
    properties
        Gestures (:,1) gesture
        TractSystems (:,1) tractSystem
        Effectors (:,1) effector
        GestureToTract        
        TractToEffector 
        TractMode
        Score        
        dt = 1e-3
        DefaultRamp % ramp given to gestures that do not set their own
        G,T,E
        G2T
        t
        tspan
    end

    methods
        function obj = tdModel(gestSource,tractSource,opts)
            arguments
                gestSource = 'gestures.csv';
                tractSource = 'tractSystems.csv';
                opts.Ramp = 0.05 % full onset/offset ramp duration (s)
                opts.tractMode = 'scalar'
                opts.tspan = []
            end

            if ~isempty(opts.tspan)
                obj.tspan = opts.tspan;
            end
            data = tabread(gestSource);

            % gestures.csv is the whole gestural inventory; only the
            % rows carrying tract-variable parameters are task-dynamic
            % gestures. Those keep their own names (TDName, e.g. TTCD_clo)
            % rather than the inventory spelling ("TT clo"), because scores
            % are written against them -- see addActivationInterval.
            if ismember('TractSystem',tabcols(data))
                data = data(data.TractSystem~="" & ~ismissing(data.TractSystem),:);
                data.TractSystems = data.TractSystem;
                data.Name = data.TDName;
            end

            obj.DefaultRamp = opts.Ramp;
            for i=1:height(data)
                obj.Gestures(i) = gesture(data.Name(i),'Ramp',opts.Ramp);
                obj.Gestures(i).TractSystem = data.TractSystems(i);
                obj.Gestures(i).Target = data.Target(i);
                if ~isnumeric(data.Stiffness(i))
                    switch(data.Stiffness(i))
                        case "C"
                            obj.Gestures(i).Stiffness = 5;
                        case "V"
                            obj.Gestures(i).Stiffness = 3;
                        otherwise
                            % No silent fall-through: an
                            % unrecognized class would keep
                            % gesture's default stiffness.
                            error('tdModel:unknownStiffnessClass', ...
                                ['Gesture "%s" has Stiffness "%s"; ' ...
                                 'expected a number, "C" or "V".'], ...
                                data.Name(i),data.Stiffness(i));
                    end
                else
                    obj.Gestures(i).Stiffness = data.Stiffness(i);
                end
            end

            obj.TractMode = opts.tractMode;

            data = tabread(tractSource);
            for i=1:height(data)
                obj.TractSystems(i) = tractSystem(data.Name(i),Type=opts.tractMode);
            end            
            effectors = string(setdiff(tabcols(data),'Name','stable'));
            for i=1:numel(effectors)
                obj.Effectors(i) = effector(effectors(i));
            end

            map = table2array(data(:,2:end));
            map(isnan(map)) = 0;
            map = map./sum(abs(map),2);
            obj.TractToEffector =  map;
            
            obj = obj.updateGestureToTract();
        end

        function [obj] = updateGestureToTract(obj)
            obj.GestureToTract = false(numel(obj.Gestures),numel(obj.TractSystems));
            for i=1:numel(obj.Gestures)
                ix = find([obj.TractSystems.Name]==obj.Gestures(i).TractSystem);
                obj.GestureToTract(i,ix) = true;
            end
        end

        function [obj] = addGesture(obj,name,tractSystem,target,opts)
            arguments
                obj
                name
                tractSystem
                target
                opts.stiffness = []
                opts.ramp = []
                opts.rampType = []
            end

            if ismember(name,[obj.Gestures.Name])
                fprintf('WARNING: gesture %s already exists\n',name);
                return;
            end

            obj.Gestures(end+1) = gesture(name,'TractSystem',tractSystem,'Target',target, ...
                'Ramp',obj.DefaultRamp);
            if ~isempty(opts.ramp), obj.Gestures(end).Ramp = opts.ramp; end
            if ~isempty(opts.rampType), obj.Gestures(end).RampType = opts.rampType; end
            if ~isempty(opts.stiffness), obj.Gestures(end).Stiffness = opts.stiffness; end
            obj = obj.updateGestureToTract();
        end

        function [obj] = addActivationInterval(obj,gesture,tspan)
            if isempty(obj.Score)
                obj.Score = table(string(gesture),tspan,'VariableNames',{'Gesture' 'tspan'});
            else
                warning('off','MATLAB:table:RowsAddedExistingVars');
                obj.Score.Gesture(end+1) = string(gesture);
                obj.Score.tspan(end,:) = tspan;
            end
        end

        function [obj] = simulate(obj,opts)
            arguments
                obj
                opts.dt = obj.dt;
                opts.tspan = []
                opts.auto_postspan = 0.250                
            end

            if isempty(opts.tspan)
                opts.tspan = obj.tspan;
            end

            % infer timespan from score
            if isnan(opts.tspan(2))
                opts.tspan(2) = max(obj.Score.tspan(:)) + opts.auto_postspan;
            end

            tractSystemTypes = string({obj.TractSystems.Type});
            if all(tractSystemTypes=="scalar")
                tractSystemType = 'scalar';
            elseif all(tractSystemTypes=="field")
                tractSystemType = 'field';
            else
                fprintf("ERROR: all tract systems must be same type\n");
                return;
            end

            obj = obj.initSimulation(dt=opts.dt,tspan=opts.tspan);
            switch(tractSystemType)
                case 'scalar'                    
                    obj = obj.simScalar(dt=opts.dt,tspan=opts.tspan);
                case 'field'                    
                    obj = obj.simField(dt=opts.dt,tspan=opts.tspan);
            end

            for i=1:height(obj.Score)
                ix = find(obj.G.Name==obj.Score.Gesture(i));
                obj.Score.activation(i,:) = sum(obj.G.X(ix,:),1);
            end

        end

        function [obj] = simScalar(obj,opts)
            arguments
                obj
                opts.dt = obj.dt;
                opts.tspan = [0 nan]
            end
            Xt = obj.T.X(:,:,1);
            Xe = obj.E.X(:,:,1);
            Vt = obj.T.X(:,:,2);
            Ve = obj.E.X(:,:,2);

            Kt = obj.T.K/obj.dt;
            Bt = 2*sqrt(Kt);
            Tt = obj.T.Target;
            
            T2E = obj.TractToEffector;

            for i=2:numel(obj.t)
                dXt = Vt(:,i-1);
                dVt = -Bt(:,i-1).*Vt(:,i-1) - Kt(:,i-1).*(Xt(:,i-1)-Tt(:,i-1));
                Xt(:,i) = Xt(:,i-1) + dXt*opts.dt;
                Vt(:,i) = Vt(:,i-1) + dVt*opts.dt;
                
                dXe = Ve(:,i-1);                
                dVe = T2E' * dVt;
                Xe(:,i) = Xe(:,i-1) + dXe*opts.dt;
                Ve(:,i) = Ve(:,i-1) + dVe*opts.dt;                
                
            end

            obj.T.X = cat(3,Xt,Vt);
            obj.E.X = cat(3,Xe,Ve);

        end

        function [obj] = simField(obj,opts)
            arguments
                obj
                opts.dt = obj.dt;
                opts.tspan = [0 nan]
            end

            fieldCoords = obj.TractSystems(1).Field;
            gestForce = @(mu,sigma)exp(-((fieldCoords-mu).^2)./(2*sigma.^2));
            forceDistr = obj.G.Gain.*gestForce(obj.G.T,obj.G.Sigma);

            g2t = obj.G2T;

            Xt = obj.T.X(:,:,1);
            Xe = obj.E.X(:,:,1);
            Vt = obj.T.X(:,:,2);
            Ve = obj.E.X(:,:,2);

            Kt = obj.T.K;
            Bt = obj.T.beta;
            Tt = obj.T.Target;

            Ft = obj.T.F;

            g = obj.G.X;
            
            T2E = obj.TractToEffector;

            for i=2:numel(obj.t)
                
                Kt(:,i-1) = sum(Ft(:,i-1,:),3)/obj.dt;
                Bt(:,i-1) = 2*sqrt(Kt(:,i-1));

                dXt = Vt(:,i-1);
                dVt = -Bt(:,i-1).*Vt(:,i-1) - Kt(:,i-1).*(Xt(:,i-1)-Tt(:,i-1));
                Xt(:,i) = Xt(:,i-1) + dXt*opts.dt;
                Vt(:,i) = Vt(:,i-1) + dVt*opts.dt;
                
                dXe = Ve(:,i-1);                
                dVe = T2E' * dVt;
                Xe(:,i) = Xe(:,i-1) + dXe*opts.dt;
                Ve(:,i) = Ve(:,i-1) + dVe*opts.dt;  
                Ft(:,i,:) = g2t'*(g(:,i).*forceDistr);
                Tt(:,i) = sum(squeeze(Ft(:,i,:)).*fieldCoords,2)./sum(squeeze(Ft(:,i,:)),2);
            end

            obj.T.F = Ft;
            obj.T.X = cat(3,Xt,Vt);
            obj.T.K = Kt;
            obj.T.Target = Tt;
            obj.T.beta = Bt;
            obj.E.X = cat(3,Xe,Ve);

        end        

        function [obj] = initSimulation(obj,opts)
            arguments
                obj
                opts.dt = obj.dt
                opts.tspan    
                opts.neutrWeight = 0.5
                opts.rampType = "";
            end
            obj.t = opts.tspan(1):opts.dt:opts.tspan(2);
            obj.G = table([obj.Gestures.Name]','VariableNames',{'Name'});
            obj.T = table([obj.TractSystems.Name]','VariableNames',{'Name'});
            obj.E = table([obj.Effectors.Name]','VariableNames',{'Name'});

            
            obj.tspan = opts.tspan;

            %gestural states
            switch(obj.TractMode)
                case 'field'
                    obj.G.Gain = [obj.Gestures.FieldGain]';
                    obj.G.Sigma = [obj.Gestures.FieldSigma]';
                    obj.G.X = zeros(height(obj.G),length(obj.t));
                    obj.G.T = [obj.Gestures.Target]';
                    obj.G.RampType = [obj.Gestures.RampType]';

                    Neutr = array2table([obj.TractSystems.Name]'+"_neutr",'VariableNames',{'Name'});
                    Neutr.Gain = [obj.TractSystems.NeutrGain]';
                    Neutr.Sigma = [obj.TractSystems.NeutrSigma]';
                    Neutr.X = opts.neutrWeight*ones(height(Neutr),numel(obj.t));
                    Neutr.T = [obj.TractSystems.Neutr]';
                    % inert for neutrals -- their activation is held at
                    % neutrWeight rather than ramped, so defActivation never
                    % reads this -- but obj.G carries a RampType in field
                    % mode, and the two tables have to agree to concatenate
                    Neutr.RampType = repmat("sigmoid",height(Neutr),1);

                case 'scalar'
                    obj.G.K = [obj.Gestures.Stiffness]';
                    obj.G.beta = 2*sqrt(obj.G.K);
                    obj.G.X = zeros(height(obj.G),length(obj.t));
                    obj.G.T = [obj.Gestures.Target]';

                    Neutr = array2table([obj.TractSystems.Name]'+"_neutr",'VariableNames',{'Name'});
                    Neutr.K = [obj.TractSystems.Stiffness]';
                    Neutr.beta = 2*sqrt(Neutr.K);
                    Neutr.X = opts.neutrWeight*ones(height(Neutr),numel(obj.t));
                    Neutr.T = [obj.TractSystems.Neutr]';

            end
            obj.G = [obj.G; Neutr];
            obj.G2T = [obj.GestureToTract;eye(height(Neutr))];
                   


            for i=1:height(obj.Score)
                ix = find(obj.G.Name==obj.Score.Gesture(i));
                for j=1:numel(ix)
                    obj.G.X(ix(j),:) = obj.G.X(ix(j),:) + ...
                        obj.defActivation(obj.Score.tspan(i,:),obj.Gestures(ix(j)));
                end
            end

            %tract system states                      
            switch(obj.TractMode)
                case 'field'
                    fieldCoords = obj.TractSystems(1).Field;

                    obj.T.F = nan(height(obj.T),length(obj.t),obj.TractSystems(1).FieldPoints);
                    
                    gestForce = @(mu,sigma)exp(-((fieldCoords-mu).^2)./(2*sigma.^2));
                    initForces = obj.G.Gain.*obj.G.X(:,1).*gestForce(obj.G.T,obj.G.Sigma);
                    
                    obj.T.F(:,1,:) = obj.G2T'*initForces;
                    obj.T.X = zeros(height(obj.T),length(obj.t),2);
                    
                    cntr = sum(squeeze(obj.T.F(:,1,:)).*fieldCoords,2)./sum(squeeze(obj.T.F(:,1,:)),2);
                    
                    obj.T.Target = nan(height(obj.T),1);
                    obj.T.Target(:,1) = cntr;    
                    obj.T.X(:,1,1) = cntr;
                    obj.T.K = nan(height(obj.T),numel(obj.t));
                    obj.T.beta = nan(height(obj.T),numel(obj.t));

                otherwise
                    obj.T.X = nan(height(obj.T),length(obj.t),2);
                    obj.T.X(:,1,:) = vertcat(obj.TractSystems.InitState);
                    
                    blend = @(m,x,y)(m' * (x.*y)) ./ (m' * x);

                    obj.T.Target = blend(obj.G2T,obj.G.X,obj.G.T);
                    obj.T.K = blend(obj.G2T,obj.G.X,obj.G.K);
                    obj.T.beta = 2*sqrt(obj.T.K);
            end

            %effector states            
            obj.E.X = nan(height(obj.E),length(obj.t),2);            
            obj.E.X(:,1,:) = vertcat(obj.Effectors.InitState);
            
        end        

        function act = defActivation(obj,tspan,gest)
            arguments
                obj
                tspan
                gest                
            end
            ramp = gest.Ramp;

            intStep = @(ons,off)(obj.t>=ons & obj.t<=off);                        
            switch(gest.RampType)
                case 'sigmoid'
                    % Ramp is the whole ramp: the sigmoid (1% at x=-1, 99%
                    % at x=1) is centred half a ramp in and scaled by half
                    % a ramp, so activation is ~1% at onset and ~99% one
                    % ramp later (mirrored at offset)
                    sigmoid = @(x) 1./(1 + exp(-4.4*x));
                    rampOn = @(ons,ramp)sigmoid((obj.t-(ons+ramp(1)/2))/max(ramp(1)/2,obj.dt));
                    rampOff = @(off,ramp)sigmoid(((off-ramp(end)/2)-obj.t)/max(ramp(end)/2,obj.dt));
                    actfcn = @(ons,off,ramp)rampOn(ons,ramp).*rampOff(off,ramp);

                case 'decay'
                    % onset as for 'sigmoid'; linear decay at rate ramp(end)
                    % per second from the onset midpoint
                    sigmoid = @(x) 1./(1 + exp(-4.4*x));
                    rampOn = @(ons,ramp)sigmoid((obj.t-(ons+ramp(1)/2))/max(ramp(1)/2,obj.dt));
                    rampOff = @(ons,ramp)max(1-max(obj.t-(ons+ramp(1)/2),0)*ramp(end),0);
                    actfcn = @(ons,off,ramp)intStep(ons,off).*rampOn(ons,ramp).*rampOff(ons,ramp);

                case 'custom'
                    actfcn = @(ons,off,ramp)gest.ActivationFcn;
                    

                otherwise
                    rampOn = @(ons,ramp)min((obj.t-ons)/max(ramp(1),obj.dt),1);
                    rampOff = @(off,ramp)min((off-obj.t)/max(ramp(end),obj.dt),1);
                    actfcn = @(ons,off,ramp)intStep(ons,off).*rampOn(ons,ramp).*rampOff(off,ramp);
                    
            end
            act = actfcn(tspan(1),tspan(2),ramp);
        end

        function p = plotter(obj)
            p = tdModelPlot(obj);
        end

        function sc = plotScore(obj,varargin)
            % Plot score and activation curves. Accepts all gestScore.plot
            % options (fontSize, tierHeight, plotTiers, labelPos, parent,
            % etc.) plus LineWidth for the activation curves.
            % Example: td.plotScore(fontSize=22,tierHeight=1.5,labelPos='center')
            sc = obj.plotter().plotScore(varargin{:});
        end

        function tract = plotTractSystems(obj,varargin)
            tract = obj.plotter().plotTractSystems(varargin{:});
        end

        function tract = plotTractField(obj,varargin)
            tract = obj.plotter().plotTractField(varargin{:});
        end

        function eff = plotEffectors(obj,varargin)
            eff = obj.plotter().plotEffectors(varargin{:});
        end

        function h = plotJacobian(obj,varargin)
            h = obj.plotter().plotJacobian(varargin{:});
        end


        function [obj] = matchScoreColorsToTractVars(obj)            
            for i=1:height(obj.Score)
                tractVar = obj.Gestures(ismember([obj.Gestures(:).Name],obj.Score.Gesture(i))).TractSystem;
                obj.Score.color(i,:) = obj.T.color(obj.T.Name==tractVar,:);
            end
        end
    end

    
end
