function [accuracy,match,results,info] = scoreWeights(w,opts)
%SCOREWEIGHTS  Run every target configuration under one weight struct.
%
%   acc = scoreWeights(w) regenerates each configuration returned by
%   loadConfigs using the weight struct w, and returns the proportion
%   matching their target.
%
%   Uses the same config loading, filtering, and per-configuration seeding
%   (rng(seed+i)) as exploreWeights, so the two are directly comparable.
%
%   Unlike exploreWeights this does no normalization and has no fixed term,
%   so any weight -- including bound -- can be set to anything, including 0.
%   That makes it the right tool for ablation, where exploreWeights would
%   refuse to zero its own reference term.
%
%   opts.beta defaults to [], meaning "use gmConfigurator's Beta property".
%   Pass a value only to override it. Since bonding_stochastic normalizes
%   dE by norm(weights,1), beta is in units of normalized energy and the
%   right magnitude depends on that normalization -- keeping the default in
%   one place (the class) avoids the harness and the model disagreeing.
%
%   Example (ablation: what does each term contribute?):
%       w0    = gmConfigurator.defWeights();
%       terms = gmConfigurator.EnergyTerms;
%       base  = scoreWeights(w0);
%       acc   = nan(numel(terms),1);
%       for k = 1:numel(terms)
%           w = w0; w.(terms(k)) = 0;
%           acc(k) = scoreWeights(w);
%       end
%       disp(table(terms(:), acc, base-acc, ...
%            'VariableNames',{'zeroed','accuracy','drop'}))

arguments
    w struct
    opts.form   = []
    opts.word   = []
    opts.group  = []
    opts.excludeGroup = []
    opts.requireTarget = true
    opts.seed   = 0
    opts.beta   = []                % [] = gmConfigurator's Beta property
    opts.applyConfigParams = true
    opts.recordDecisions = false    % collect the constraint rows that make
                                    % this run's trajectory the chosen one
    opts.verbose = false
end

terms = gmConfigurator.EnergyTerms(:);
missing = terms(~isfield(w, terms));
if ~isempty(missing)
    error('scoreWeights:missingTerms','weight struct has no field for: %s', ...
        strjoin(missing,', '));
end

C = loadConfigs(opts);

if isempty(C)
    error('scoreWeights:noConfigs','no configurations to evaluate');
end

forms   = C.form;
targets = C.target;
params  = string(C.params(:));
params(ismissing(params)) = "";
n = height(C);

% Accuracy is only meaningful against a target. If untargeted rows slipped
% through, score only the targeted ones rather than counting them as misses.
hasTarget = strlength(targets) > 0;
if ~all(hasTarget)
    warning('scoreWeights:untargeted', ...
        '%d of %d configurations have no target; excluded from accuracy', ...
        sum(~hasTarget), n);
end

results = strings(n,1);
stable  = false(n,1);
rowsPer = cell(n,1);
decPer  = cell(n,1);

for i = 1:n
    rng(opts.seed+i,'twister');

    mc = modeConfig(forms(i), Weights=w);
    c  = gmConfigurator(mc);
    if opts.applyConfigParams && strlength(params(i)) > 0
        c = c.setParams(params(i));
    end
    c.Weights = w;

    args = {'Method','bonding_stochastic'};
    if ~isempty(opts.beta), args = [args {'beta',opts.beta}]; end %#ok<AGROW>
    if opts.recordDecisions, args = [args {'recordDecisions',true}]; end %#ok<AGROW>
    c = c.genModeConfig(args{:});

    results(i) = c.FinalConfig.ToString();
    stable(i)  = ~isempty(c.Stabilized) && c.Stabilized;

    if opts.recordDecisions
        decPer{i}  = c.Decisions;
        rowsPer{i} = localMarginRows(c.Decisions);
    end
end

match    = results == targets;
accuracy = mean(match(hasTarget));

if opts.verbose
    fprintf('accuracy %.3f (%d/%d), %d stable, beta=%g\n', ...
        accuracy, sum(match(hasTarget)), sum(hasTarget), sum(stable), ...
        localBeta(opts.beta));
end

info = struct('words',C.word,'forms',forms,'targets',targets, ...
              'results',results,'stable',stable,'hasTarget',hasTarget, ...
              'weights',w,'beta',localBeta(opts.beta));

if opts.recordDecisions
    % Only configurations that actually hit their target contribute. A
    % failed run's trajectory is one we do NOT want to preserve, so its
    % constraints would pin the weights to the wrong answer.
    keep = match & hasTarget;
    A = vertcat(rowsPer{keep});
    nDropped = 0;
    if ~isempty(A)
        A(all(abs(A) < 1e-12, 2), :) = [];      % ties constrain nothing
        A = unique(round(A, 10), 'rows');

        % At finite beta the selection is argmin only up to near-ties: when
        % two alternatives are separated by less than about 1/beta in
        % normalised energy, the draw can land on either. Those decisions
        % produce rows the recording vector itself violates, which would make
        % the cone empty. Drop them, and say how many.
        wv   = arrayfun(@(t) w.(t), terms);
        marg = A*wv;
        viol = marg < -1e-9;
        if any(viol)
            nDropped = nnz(viol);
            warning('scoreWeights:nonArgmin', ...
                ['%d of %d constraint rows are violated by the recording ' ...
                 'vector (worst %.3g, i.e. %.3g normalised) -- near-ties, dropped'], ...
                nDropped, numel(viol), min(marg), min(marg)/norm(wv,1));
            A(viol,:) = [];
        end
    end
    info.A           = A;
    info.decisions   = decPer;
    info.rowsPer     = rowsPer;
    info.usedConfigs = keep;
    info.nDropped    = nDropped;
    if opts.verbose
        fprintf('recorded %d constraint rows from %d of %d configurations', ...
            size(A,1), nnz(keep), n);
        if nDropped > 0, fprintf(' (%d near-ties dropped)', nDropped); end
        fprintf('\n');
    end
end
end

%% ===========================================================================
function M = localMarginRows(D)
% Every rejected alternative j at every decision gives a row x_j - x_selected,
% which must have a non-negative inner product with w for the same choice to
% be made again. currentE cancels in the Boltzmann weights, so the selected
% alternative's own row is all that matters as the reference.
M = [];
for d = 1:numel(D)
    X = D{d}.X;
    s = D{d}.selected;
    R = X - X(s,:);
    R(s,:) = [];
    M = [M; R]; %#ok<AGROW>
end
end

%% ===========================================================================
function b = localBeta(betaOpt)
% Resolve the beta actually in force, for reporting.
if isempty(betaOpt)
    c = gmConfigurator();
    b = c.Beta;
else
    b = betaOpt;
end
end
