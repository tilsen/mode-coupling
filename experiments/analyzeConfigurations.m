function [Sim] = analyzeConfigurations(CG,opts)
arguments
    CG
    opts.stabilizedOnly = true   
    opts.sortVar = 'energy';
    opts.sortDir = 'descend';    
    opts.targets = []
end

%% configuration trajectories
Traj.rep = (1:numel(CG))';
Traj.states = arrayfun(@(d){arrayfun(@(c)c.ToString(separator=""),d.IterConfigs)},CG(:));
Traj.TotalE = arrayfun(@(d){cell2mat(arrayfun(@(c){c.Energies.totalE},d.IterConfigs))},CG(:));
Traj.stabilized = [CG.Stabilized]';
Traj.FinalE = cellfun(@(c)c(end),Traj.TotalE);
Traj.numIters = cellfun(@(c)length(c),Traj.states);
Traj.finalConfig = cellfun(@(c)c(end),Traj.states);
Traj.stateLabs = arrayfun(@(d){arrayfun(@(c)c.ToLabels(),d.IterConfigs)},CG(:));
Traj.configPars = expandv(arrayfun(@(c){c.getParams()},CG(:)));
Traj = struct2table(Traj);
Traj = movevars(Traj,'states','After','stateLabs');
%Traj = sortrows(Traj,{'FinalE' 'numIters'});

%
switch(opts.stabilizedOnly)
    case true
        Traj = Traj(Traj.stabilized,:);
end

%% states
States.state = horzcat(Traj.states{:})';
States.energy = horzcat(Traj.TotalE{:})';
iters = cellfun(@(c){1:numel(c)},Traj.TotalE)';
States.iters = horzcat(iters{:})';
States.stateLab = horzcat(Traj.stateLabs{:})';
States = struct2table(States);

% state statistics
stateStats = grpstats(States,"state","mean",DataVars=["iters" "energy"]);
stateStats.Properties.VariableNames = mregexprep(tabcols(stateStats),'mean_','','GroupCount','count');
stateStats = sortrows(stateStats,opts.sortVar,opts.sortDir);

[~,ia] = ismember(stateStats.state,States.state);
stateStats.label = States.stateLab(ia);

% Labels (ToLabels, short style) can collide where the state strings
% (ToString) do not, since the short style carries less. Number the
% duplicates rather than stopping: labels are display only, and the
% transition matrix below is keyed on state, not label.
uLabs = unique(stateStats.label);
if numel(uLabs)~=height(stateStats)
    warning('analyzeConfigurations:nonUniqueStateLabels', ...
        '%d state(s) share a label with another; numbering the duplicates.', ...
        height(stateStats)-numel(uLabs));
    nStatesPerLab = arrayfun(@(c)sum(stateStats.label==c),uLabs);
    ixs = find(nStatesPerLab>1);
    for i=1:numel(ixs)
        rowIxs = find(ismember(stateStats.label,uLabs(ixs(i))));
        stateStats.label(rowIxs) = stateStats.label(rowIxs) + "_" + (1:numel(rowIxs))';
    end
end

A.trans = zeros(numel(stateStats.state),numel(stateStats.state));
for i=1:height(Traj)
    s = Traj.states{i};
    for j=1:numel(s)-1
        ixr = stateStats.state==s(j);
        ixc = stateStats.state==s(j+1);
        A.trans(ixr,ixc) = A.trans(ixr,ixc)+1;
    end
end

A.trans(A.trans==0) = nan;
A.logTrans = log(A.trans);
A.logTrans(isinf(A.logTrans)) = nan;

A.tr_norm = nansum(A.trans,2); %#ok<NANSUM>
A.tr_norm(A.tr_norm==0)=nan;
A.tr_p = A.trans./A.tr_norm;

epsThresh = 1e-12;              % tweak if you want stricter/looser cutoff
A.tr_p(~(A.tr_p > epsThresh)) = 0;
A.stats = stateStats;

A.finalStats = tabcell2str(tabulater(Traj.finalConfig,'colname','state'));
A.finalStats.prop = A.finalStats.percent/100; A.finalStats.percent = [];
A.finalStats.stabilized = arrayfun(@(c)sum(Traj.finalConfig(Traj.stabilized)==c),A.finalStats.state);
A.finalStats.prop_stabilized = A.finalStats.stabilized./A.finalStats.count;

[~,ia] = ismember(A.finalStats.state,A.stats.state);
A.finalStats.stateLab = A.stats.label(ia);
if ~isempty(opts.targets)
    A.finalStats.isTarget = ismember(A.finalStats.state,opts.targets);
end

%%
Sim.Traj = Traj;
Sim.States = States;
Sim.Analysis = A;

end