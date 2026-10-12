classdef modeSelection

    properties
        Config modeConfig
        Modes
        Excitations
        Gestures
        TractSystems
        Articulators
        tspan = []
        dt = 1e-3
        Nt = []
        M2E, E2G, G2T, T2G, T2A
        M = []      %modes
        Xi = []     %mode activation level
        oscM = []
        fbM = []
        E = []      %gestural excitations
        G = []      %gestures
        ifbG = []
        efbG = []
        fbG = []
        F = []      %tract system fields
        T = []      %tract systems
        A = []      %articulators
        t = []
        stateVars = ["M" "Xi" "oscM" "fbM" "E" "G" "ifbG" "efbG" "fbG" "F" "T" "A"]
        stateVarLabels = ["x_{\mu}" "\Xi" "\theta_{\mu}" "\hat{\mu}" "g" "G" "\hat{g}^{int}" "\hat{g}^{ext}" "\hat{g}" "F" "T" "A"];
        modeGain = 10;
        % A selected mode gates the growth of the others until its
        % feedback reaches degateThreshold, then the next mode can grow and
        % be selected (epochs overlap by (1-degateThreshold)/gain); at
        % feedback 1 the mode is suppressed and decays. Each selected mode
        % runs its own phase oscillator.
        selectionThreshold = 1     % a mode is selected when its activation reaches this
        % Feedback (fraction of suppression) a selected mode must reach
        % before a gated mode is released, by the sign of the mode being
        % released: {+} modes use degateThresholdPlus, {-} modes
        % degateThresholdMinus.
        degateThresholdPlus = 0.20
        degateThresholdMinus = 0.42
        modeCapacity = 1.1         % activation plateau of a growing or selected mode
        modeDecay = 10             % rate at which a suppressed mode decays to modeFloor
        modeFloor = 0.1
        modeFeedbackGain = 6;   % baseline feedback gain of a mode; sets epoch length (~1/gain)
        % Decrements from the baseline, by mode sign and the classes of the
        % gesturals coupled to the mode (one decrement per class present,
        % so a mode holding a C and a V gestural loses both), plus a
        % decrement per unit of the mode's metrical activation. A lower
        % gain lengthens the mode's selection epoch (~1/gain).
        fbGainPlusC = 0.5
        fbGainPlusV = 1.5
        fbGainMinusC = 0.25
        fbGainMinusV = 1.0
        fbGainMetrical = 0.5
        modeFeedbackGainOverride = []   % explicit per-mode gains (1 x nModes) replace the composition rule
        % How the composition effect is realized. "gain": a mode's feedback
        % and its phase oscillator run at its own (lower/higher) gain, so
        % its whole epoch is time-scaled. "threshold": the oscillator keeps
        % the baseline gain and the epoch is cut or extended by a
        % per-mode feedback threshold (baseline gain / mode gain). Epoch
        % lengths are the same either way; only the gestural phase timing
        % within the epoch differs.
        feedbackVariation = "gain"
        impTime = 0.250;
        % Every gestural exerts a subtle force on the tract field, gated by a
        % steep sigmoid of its mode activation (centered on influenceCenter,
        % width influenceWidth), at up to gestureInfluence of a fully active
        % gestural's force (0 turns it off). The force weights are low-pass
        % filtered with time constant gestureRamp (s; 0 = no smoothing), so
        % the field changes ramp rather than step.
        gestureInfluence = 0.1
        influenceCenter = 1.0
        influenceWidth = 0.03
        gestureRamp = 0.02
    end

    methods
        function obj = modeSelection(config)
            obj.Config = config;

            obj.Modes = config.Modes;
            obj.Excitations = config.Excitations;
            td = tdModel;
            obj.Gestures = td.Gestures;
            obj.TractSystems = td.TractSystems;
            obj.Articulators = td.Effectors;

            % Conform excitation names. An excitation is named for its
            % gesture and gestures.csv already carries that gesture's
            % task-dynamic name, so look it up rather than rebuilding it
            % from the spelling. A "~" marks a repeated excitation and is
            % not part of the gesture name.
            names = strrep(obj.Excitations.Name,'~','');
            [hasG,gIx] = ismember(names,config.Articulae.Gestures.Name);
            tdn = strings(size(names));
            tdn(hasG) = config.Articulae.Gestures.TDName(gIx(hasG));
            % a gesture with no tract-variable parameters has no TDName;
            % it keeps its own name so the check below can report it
            names(tdn~="") = tdn(tdn~="");
            obj.Excitations.Name = names;

            obj.M2E = obj.Modes.Id==(obj.Excitations.ModeId');
            obj.E2G = obj.Excitations.Name==[obj.Gestures.Name];
            obj.G2T = td.GestureToTract;
            obj.T2G = obj.G2T';
            obj.T2A = td.TractToEffector;

            %check that all excitations are associated with exactly one system:
            es_assoc = sum(obj.E2G,2);
            if any(es_assoc~=1)
                ixs = find(es_assoc~=1);
                for i=1:numel(ixs)
                    switch es_assoc(ixs(i))
                        case 0
                            fprintf('unassociated excitation: %s\n',obj.Excitations.Name(ixs(i)));
                        otherwise
                            fprintf('multiply associated excitation: %s\n',obj.Excitations.Name(ixs(i)));
                    end
                end

            end

        end

        function obj = initSim(obj,opts)
            arguments
                obj
                opts.tspan = [0 5]
                opts.dt = []
                opts.fieldPoints = []   % default: the tract systems' FieldPoints
            end
            opts = handleMethodInputs(obj,opts);
            if isempty(opts.fieldPoints)
                opts.fieldPoints = obj.TractSystems(1).FieldPoints;
            end

            obj.t = opts.tspan(1):opts.dt:opts.tspan(2);
            obj.Nt = length(obj.t);

            obj.M = zeros(obj.Nt,height(obj.Modes));
            obj.Xi = zeros(obj.Nt,height(obj.Modes));
            obj.oscM = zeros(obj.Nt,height(obj.Modes));
            % obj.ifbM = zeros(obj.Nt,height(obj.Modes));
            % obj.efbM = zeros(obj.Nt,height(obj.Modes));
            obj.fbM = zeros(obj.Nt,height(obj.Modes));
            obj.E = zeros(obj.Nt,height(obj.Excitations));
            obj.G = zeros(obj.Nt,numel(obj.Gestures));
            obj.ifbG = zeros(obj.Nt,numel(obj.Gestures));
            obj.efbG = zeros(obj.Nt,numel(obj.Gestures));
            obj.fbG = zeros(obj.Nt,numel(obj.Gestures));
            obj.F = zeros(obj.Nt,numel(obj.TractSystems),opts.fieldPoints);
            obj.T = cat(3,(1/2)*ones(obj.Nt,numel(obj.TractSystems)),zeros(obj.Nt,numel(obj.TractSystems))); %position, velocity
            obj.A = zeros(obj.Nt,numel(obj.Articulators),2); %position, velocity

            obj.M(1,:) = obj.initModeActivations();

        end

        function gains = modeFeedbackGains(obj)
            % Feedback gain of each mode (1 x nModes): the baseline, less
            % the decrements for the classes of the coupled gesturals.
            nModes = height(obj.Modes);
            if ~isempty(obj.modeFeedbackGainOverride)
                gains = reshape(obj.modeFeedbackGainOverride,1,[]);
                if isscalar(gains), gains = repmat(gains,1,nModes); end
                return
            end
            gains = obj.modeFeedbackGain*ones(1,nModes);
            for m = 1:nModes
                cls = obj.Excitations.Class(obj.M2E(m,:));
                hasC = any(cls==articulae.C);
                hasV = any(cls==articulae.V);
                if obj.Modes.Sign(m)>0
                    dec = hasC*obj.fbGainPlusC + hasV*obj.fbGainPlusV;
                else
                    dec = hasC*obj.fbGainMinusC + hasV*obj.fbGainMinusV;
                end
                if ismember('metricalAct',obj.Modes.Properties.VariableNames)
                    dec = dec + obj.fbGainMetrical*obj.Modes.metricalAct(m);
                end
                gains(m) = max(obj.modeFeedbackGain-dec,0.1*obj.modeFeedbackGain);
            end
        end

        function act = initModeActivations(obj)
            modeOcc = (sum(obj.M2E,2)>0)';     % modes that have excitations coupled to them
            act = zeros(1,height(obj.Modes));
            mact = linspace(1,0,sum(modeOcc)+2);
            act(modeOcc) = mact(2:end-1);
        end

        function obj = simulate(obj)
            dt = obj.dt; %#ok<*PROPLC,*PROP>
            t = obj.t;
            Nt = length(t);
            s = struct();

            modeGain = obj.modeGain;
            % per-mode feedback ramp (the feedback is a fraction of the mode's
            % threshold, so it is suppressed at 1) and oscillator rates
            modeFeedbackGain = obj.modeFeedbackGains();
            oscRate = modeFeedbackGain;
            if obj.feedbackVariation=="threshold"
                oscRate = obj.modeFeedbackGain*ones(size(modeFeedbackGain));
            end
            impTime = obj.impTime;
            gFeedbackGain = [obj.Gestures.Stiffness];

            for i=1:numel(obj.stateVars)
                s.(obj.stateVars(i)) = obj.(obj.stateVars(i));
            end

            s.selected = false(size(s.M));
            s.selection = false(size(s.M));
            s.supressed = false(size(s.M));

            nModes = size(s.M,2);

            modeOcc = (sum(obj.M2E,2)>0)';

            % target phase of each excitation: its lag behind the
            % highest-phase excitation of its own mode (uncoupled: none)
            [~,mIx] = ismember(obj.Excitations.ModeId,obj.Modes.Id);
            coupled = mIx>0;
            modeMax = accumarray(mIx(coupled),obj.Excitations.Phase(coupled), ...
                [height(obj.Modes) 1],@max,NaN);
            ePhases = inf(1,height(obj.Excitations));
            ePhases(coupled) = -(obj.Excitations.Phase(coupled)-modeMax(mIx(coupled)))'/(2*pi);

            fieldCoords = linspace(0,1,size(s.F,3));
            gestForce = @(mu,sigma)exp(-((fieldCoords-mu).^2)./(2*sigma.^2));
            forceDistr = gestForce([obj.Gestures.Target]',[obj.Gestures.FieldSigma]');
            neutrDistr = (1/10)*gestForce(repmat(0.5,numel(obj.TractSystems),1),(1/2));
            gGatingFcn = @(x)double(x>=1) + (x<1).*(x.^4);
            eGatingFcn = @(x)double(x>=1);

            eSigma = 20*dt*(10*(obj.Excitations.Class==articulae.V)' + (1/2)*(obj.Excitations.Class~=articulae.V)');
            gaussFcn = @(x,mu,sigma)exp(-(1/2)*((x-mu)./sigma).^2);
            eGaussFcn = @(x,mu)gaussFcn(x,mu,eSigma).*(x>mu);

            plotState = @(c)modeSelection.Plot(obj.collectStateVars(c));

            [~,mIxs] = sort(s.M(1,:),'descend');
            s.Xi(1,mIxs) = 1:nModes;

            degateThr = obj.degateThresholdPlus*ones(1,nModes);
            degateThr(obj.Modes.Sign'<0) = obj.degateThresholdMinus;
            active = false(1,nModes);   % selected and in feedback
            done = false(1,nModes);     % suppressed (inhibition of return)
            gW = zeros(1,size(s.G,2));  % smoothed force weight of each gestural on the field

            for i=2:Nt

                m0 = s.M(i-1,:);
                newSel = modeOcc & ~active & ~done & (m0>=obj.selectionThreshold);
                s.selection = newSel;
                active = active | newSel;

                % growth is gated before impTime and while any selected
                % mode is still in the early part of its feedback
                fbPrev = s.fbM(i-1,:)';
                frozen = (t(i)<=impTime) | any(active(:) & (fbPrev<degateThr),1);   % per mode
                grow = modeGain*m0.*(obj.modeCapacity-m0);
                dM = zeros(1,nModes);
                dM(active) = grow(active);                       % selected: hold the plateau
                growing = modeOcc & ~active & ~done & ~frozen;
                dM(growing) = grow(growing);
                dM(done) = obj.modeDecay*(obj.modeFloor-m0(done));   % suppressed: decay
                s.M(i,:) = max(m0+dM*dt,0);

                s.fbM(i,:) = s.fbM(i-1,:) + modeFeedbackGain.*double(active)*dt;
                doscM = oscRate.*(s.oscM(i-1,:)>0) + double(active);
                s.oscM(i,:) = s.oscM(i-1,:) + doscM*dt;

                sup = active & (s.fbM(i,:)>=1);
                if any(sup)
                    done(sup) = true;
                    active(sup) = false;
                    s.fbM(i,sup) = 0;
                    s.oscM(i,sup) = 0;
                end
                s.selected(i,:) = active;
                s.supressed(i,:) = sup;
                [~,rankOrder] = sort(s.M(i,:),'descend');
                s.Xi(i,rankOrder) = 1:nModes;

                if any(s.selection)
                    % the gesturals of a newly selected mode start with fresh
                    % feedback; those of overlapping modes keep theirs
                    gNew = ((double(newSel)*double(obj.M2E))*double(obj.E2G))>0;
                    s.ifbG(i-1,gNew) = 0;
                    s.fbG(i-1,gNew) = 0;
                end
                
                eActivation = (s.M(i-1,:)*obj.M2E);
                ePhase = s.oscM(i-1,:)*obj.M2E;
                dE = 10*(eActivation*(1/2) - s.E(i-1,:)) + 1000*eGaussFcn(ePhase,ePhases).*(eActivation>=1);
                
                s.E(i,:) = min(s.E(i-1,:) + dE*dt,2);
                difbG = gFeedbackGain.*double(gGatingFcn(s.G(i-1,:)));
                s.ifbG(i,:) = s.ifbG(i-1,:) + difbG*dt;
                s.fbG(i,:) = s.ifbG(i,:)+s.efbG(i,:);

                fbGthresh = s.fbG(i-1,:)>=1;
                
                if any(fbGthresh>=1)
                    eSup = (obj.E2G*fbGthresh')'>=1;
                    s.ifbG(i,fbGthresh) = 0;
                    s.fbG(i,fbGthresh) = 0;
                    s.E(i,eSup) = (1/2);
                end

                s.G(i,:) = gGatingFcn(eGatingFcn(s.E(i,:))*obj.E2G);

                % force of each gestural on the field: its activation, plus a subtle
                % influence gated by a steep sigmoid of its mode activation (about
                % 1 when the mode is selected, 1/2 at the selection threshold,
                % ~0 well below it), all low-pass filtered so it ramps
                uE = 1./(1+exp(-(eActivation-obj.influenceCenter)/obj.influenceWidth));
                uG = max(uE'.*double(obj.E2G),[],1);
                wTarget = s.G(i,:) + (1-s.G(i,:)).*obj.gestureInfluence.*uG;
                if obj.gestureRamp>0
                    gW = gW + (dt/obj.gestureRamp)*(wTarget-gW);
                else
                    gW = wTarget;
                end
                s.F(i,:,:) = obj.T2G * (gW'.*forceDistr) + neutrDistr;

                a=2;
                fieldCentroids = sum(squeeze(s.F(i,:,:).^a).*fieldCoords,2)./sum(squeeze(s.F(i,:,:).^a),2);
                fieldCentroids(isnan(fieldCentroids)) = 0.5;

                K = 100*sum(s.F(i-1,:,:),3);
                dTx = s.T(i-1,:,2);
                dTv = -2*sqrt(K).*s.T(i-1,:,2) - K.*(s.T(i-1,:,1)-fieldCentroids');

                s.T(i,:) = s.T(i-1,:) + [dTx dTv]*dt;

            end

            obj = obj.collectStateVars(s);

        end

        function obj = collectStateVars(obj,s)
            for i=1:numel(obj.stateVars)
                obj.(obj.stateVars(i)) = s.(obj.stateVars(i));
            end
        end

        function p = plotter(obj)
            p = modeSelectionPlot(obj);
        end

        function h = plot(obj,opts)
            arguments
                obj
                opts.?plotopts.ModeSelection
            end

            args = namedargs2cell(opts);
            h = obj.plotter().plot(args{:});
        end

    end

end
