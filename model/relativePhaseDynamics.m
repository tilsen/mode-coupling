function [mc] = relativePhaseDynamics(mc,opts)
arguments
    mc
    opts.omega = 20*2*pi;
    opts.a = 10;
    opts.dt = 1e-3;
    opts.tspan = [0 5];
end

opts.t = opts.tspan(1):opts.dt:opts.tspan(2);

Modes = mc.Modes;
Excitations = mc.Excitations;

mc.Excitations.ThetaRel = nan(height(mc.Excitations),length(opts.t));
mc.Modes.Theta = nan(height(mc.Modes),length(opts.t));

for i=1:height(Modes)

    e = Excitations(Excitations.ModeId==Modes.Id(i),:);

    Phi = zeros(height(e));

    SameLevel = e.Activation==e.Activation';

    switch(Modes.Sign(i))
        case 1
            Phi = Phi + -1*(e.Class==articulae.C & e.Class'==articulae.C); % C-C
            activations = unique(e.Activation(e.Class~=articulae.V));
            th0 = trimarray(linspace(-pi/2,pi/2,numel(activations)+2),1,1);
            [ix,ia] = ismember(e.Activation,activations);
            e.theta0(ix) = th0(ia(ix));
            e.theta0(e.Class==articulae.V) = 0;

        case -1
            Phi = Phi + -1*(e.Type==1 & e.Type'==1);
            activations = unique(e.Activation);
            th0 = trimarray(linspace(-pi/2,pi/2,numel(activations)+2),1,1);
            [ix,ia] = ismember(e.Activation,activations);
            e.theta0(ix) = th0(ia(ix));
    end
    Phi = Phi + 1*((e.Type==0 & e.Type'==1) & SameLevel); %d-type follows i-type

    Phi = Phi.*(1-eye(size(Phi)));

    %add coordination mode to system
    muTheta0 = 0; % median(e.theta0(e.Type==1));
    theta0 = [e.theta0; muTheta0];

    Phi(end+1,:) = zeros(1,height(e));
    Phi(:,end+1) = [e.Type; 0];
    Phi(end,:) = Phi(:,end);

    theta = solveSystem(theta0,Phi,opts);
    
    mc.Modes.Theta(i,:) = theta(end,:);
    mc.Modes.Phi{i} = Phi(1:end-1,1:end-1);

    thetaRelMu = theta(1:end-1,:)-theta(end,:);

    mc.Excitations.ThetaRel(mc.Excitations.ModeId==mc.Modes.Id(i),:) = thetaRelMu;

end

end

%%
function [TH] = solveSystem(theta0,Phi,opts)

dt = opts.dt;
t = opts.t;
w = opts.omega;
a = opts.a;

TH = nan(numel(theta0),numel(t));
TH(:,1) = theta0;

for i=2:numel(t)

    phi = TH(:,i-1)-TH(:,i-1)';
    dth = w - a*sum(Phi.*sin(phi),2);
    TH(:,i) = TH(:,i-1) + dth*dt;

end

end