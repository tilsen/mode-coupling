function [W,info] = exploreWeights(opts)
%EXPLOREWEIGHTS  Sample the energy-weight space and score against targets.
%
%   W = exploreWeights() samples weight vectors (one term held fixed at 1),
%   regenerates every configuration that has a target, and records the
%   proportion of results matching their target.
%
%   totalE = sum(X*w') is linear in w with no constant term, so scaling all
%   weights by a positive constant leaves every comparison unchanged. Holding
%   one term at 1 therefore loses no generality -- it removes exactly the one
%   redundant degree of freedom. (That is a projective normalization: it fixes
%   direction, not magnitude. Magnitude acts as a temperature at finite beta,
%   which is why bonding_stochastic divides dE by norm(weights,1).)
%
%   Outputs:
%     W    - table, one row per weight vector: one column per term (in
%            gmConfigurator.EnergyTerms order), plus nMatch, accuracy,
%            nStable. Sorted by accuracy descending.
%     info - per-configuration detail, rows aligned with W:
%              .match/.stable  nSamples x nConfigs logical
%              .results        nSamples x nConfigs string
%              .forms/.words/.targets
%              .terms, .fixedTerm, .seed, .beta, .opts
%
%   opts.hold pins a term at a value instead of sampling it, e.g.
%   hold=struct('phasebias',0) removes the phase-bias term entirely. Values
%   are relative to fixedTerm = 1. Held terms are excluded from varyTerms.
%
%   opts.beta defaults to [], meaning "use gmConfigurator's Beta property".
%   Pass a value only to override it.
%
%   Example:
%       W = exploreWeights(nSamples=30);      % time a small run first
%       [P,S] = weightOrderings(W);

arguments
    opts.form   = []
    opts.word   = []
    opts.group  = []
    opts.excludeGroup = []
    opts.requireTarget = true
    opts.fixedTerm = "bound"
    opts.varyTerms = []
    opts.hold      = struct()       % e.g. struct('phasebias',0) pins a term
    opts.nSamples  = 100
    opts.range     = [1/4 4]        % multiplicative range around defaults
    opts.sampling  = "lhs"          % "lhs" | "random" | "grid"
    opts.gridLevels = 3
    opts.seed      = 0
    opts.beta      = []             % [] = gmConfigurator's Beta property
    opts.applyConfigParams = true
    opts.parallel  = true
    opts.saveFile  = []
end

%% ---------------------------------------------------------------- configs
C = loadConfigs(opts);

if isempty(C)
    error('exploreWeights:noConfigs','no configurations with targets to evaluate');
end

% Only the small columns cross into the loop body. Capturing C (and with it
% C.config) would broadcast every stored configurator to every worker.
forms   = C.form;
words   = C.word;
targets = C.target;
params  = localAsStringCol(C.params, height(C));
nConfig = height(C);

hasTarget = strlength(targets) > 0;
if ~all(hasTarget)
    warning('exploreWeights:untargeted', ...
        '%d of %d configurations have no target; excluded from accuracy', ...
        sum(~hasTarget), nConfig);
end

%% ---------------------------------------------------------------- weights
allTerms = gmConfigurator.EnergyTerms(:);      % canonical order
w0 = gmConfigurator.defWeights();

missing = allTerms(~isfield(w0, allTerms));
if ~isempty(missing)
    error('exploreWeights:missingTerms','defWeights has no field for: %s', ...
        strjoin(missing,', '));
end

fixedTerm = string(opts.fixedTerm);
if ~ismember(fixedTerm, allTerms)
    error('exploreWeights:badFixedTerm','"%s" is not a weight term. Available: %s', ...
        fixedTerm, strjoin(allTerms,', '));
end
if w0.(fixedTerm) == 0
    error('exploreWeights:zeroFixedTerm', ...
        'default weight for "%s" is 0, so it cannot normalize the vector', fixedTerm);
end

% Normalize so the fixed term sits at 1.
scale = w0.(fixedTerm);
wRef  = struct();
for k = 1:numel(allTerms)
    wRef.(allTerms(k)) = w0.(allTerms(k))/scale;
end

% Terms pinned to a specific value (relative to fixedTerm = 1). These are
% excluded from sampling and held at the given value in every vector.
heldTerms = string(fieldnames(opts.hold));
if ~isempty(heldTerms)
    bad = heldTerms(~ismember(heldTerms, allTerms));
    if ~isempty(bad)
        error('exploreWeights:badHoldTerm','unknown term(s) in hold: %s', strjoin(bad,', '));
    end
    if ismember(fixedTerm, heldTerms)
        error('exploreWeights:holdFixedTerm', ...
            '"%s" is the fixed term and is already pinned at 1', fixedTerm);
    end
    for k = 1:numel(heldTerms)
        v = opts.hold.(heldTerms(k));
        if ~isnumeric(v) || ~isscalar(v)
            error('exploreWeights:badHoldValue','hold.%s must be a numeric scalar', heldTerms(k));
        end
        wRef.(heldTerms(k)) = v;
    end
    fprintf('holding fixed: %s\n', strjoin(heldTerms + "=" + ...
        arrayfun(@(t)string(wRef.(t)), heldTerms), ', '));
end

if isempty(opts.varyTerms)
    varyTerms = allTerms(allTerms ~= fixedTerm);
else
    varyTerms = string(opts.varyTerms(:));
    bad = varyTerms(~ismember(varyTerms, allTerms));
    if ~isempty(bad)
        error('exploreWeights:badVaryTerm','unknown term(s): %s', strjoin(bad,', '));
    end
    varyTerms = varyTerms(varyTerms ~= fixedTerm);
end
varyTerms = varyTerms(~ismember(varyTerms, heldTerms));
nVary = numel(varyTerms);

if nVary == 0
    error('exploreWeights:nothingToVary','every term is fixed or held');
end

%% ---------------------------------------------------------------- samples
rng(opts.seed,'twister');

centers = arrayfun(@(t)wRef.(t), varyTerms(:)');
lo = min(opts.range);
hi = max(opts.range);

switch lower(string(opts.sampling))
    case "lhs"
        F = localLatinHypercubeLog(opts.nSamples, nVary, lo, hi);
    case "random"
        F = exp(log(lo) + rand(opts.nSamples,nVary)*(log(hi)-log(lo)));
    case "grid"
        F = localFullGrid(logspace(log10(lo),log10(hi),opts.gridLevels), nVary);
    otherwise
        error('exploreWeights:badSampling','sampling must be lhs, random, or grid');
end

V = F .* centers;

% A term whose default is 0 can't be scaled -- sample it absolutely instead,
% so a currently-disabled term can still be probed.
zeroDefault = centers == 0;
if any(zeroDefault)
    warning('exploreWeights:zeroDefaults', ...
        'default weight is 0 for: %s -- sampling these on an absolute scale', ...
        strjoin(varyTerms(zeroDefault),', '));
    V(:,zeroDefault) = F(:,zeroDefault);
end

V = [centers; V];               % row 1 is the default, as a baseline
nSample = size(V,1);

%% ------------------------------------------------------------ run the sweep
match   = false(nSample,nConfig);
results = strings(nSample,nConfig);
stable  = false(nSample,nConfig);

seed      = opts.seed;
applyPars = opts.applyConfigParams;
betaOpt   = opts.beta;              % [] means: let the class default stand

if isempty(betaOpt)
    cTmp = gmConfigurator();
    betaUsed = cTmp.Beta;
else
    betaUsed = betaOpt;
end

fprintf('exploreWeights: %d weight vectors x %d configurations (beta=%g)\n', ...
    nSample, nConfig, betaUsed);
tStart = tic;

if opts.parallel
    q = parallel.pool.DataQueue;
    done = 0;
    afterEach(q, @(~) localTick());
    parfor s = 1:nSample
        w = localBuildWeights(wRef, varyTerms, V(s,:), fixedTerm);
        [match(s,:), results(s,:), stable(s,:)] = ...
            localRunWeightSet(forms, params, targets, w, seed, applyPars, betaOpt);
        send(q, s);
    end
else
    for s = 1:nSample
        w = localBuildWeights(wRef, varyTerms, V(s,:), fixedTerm);
        [match(s,:), results(s,:), stable(s,:)] = ...
            localRunWeightSet(forms, params, targets, w, seed, applyPars, betaOpt);
        fprintf('  %d/%d  acc=%.3f  (%.1f s)\n', ...
            s, nSample, mean(match(s,hasTarget)), toc(tStart));
    end
end

fprintf('exploreWeights: done in %.1f s\n', toc(tStart));

%% ---------------------------------------------------------------- assemble
allVals = zeros(nSample, numel(allTerms));
for k = 1:numel(allTerms)
    j = find(varyTerms == allTerms(k), 1);
    if isempty(j)
        allVals(:,k) = wRef.(allTerms(k));      % fixed or held
    else
        allVals(:,k) = V(:,j);
    end
end

W = array2table(allVals, 'VariableNames', cellstr(allTerms));
W.nMatch   = sum(match(:,hasTarget),2);
W.accuracy = mean(match(:,hasTarget),2);
W.nStable  = sum(stable,2);
[W,ord] = sortrows(W,'accuracy','descend');

info = struct();
info.match     = match(ord,:);
info.results   = results(ord,:);
info.stable    = stable(ord,:);
info.forms     = forms;
info.words     = words;
info.targets   = targets;
info.hasTarget = hasTarget;
info.terms     = varyTerms;
info.fixedTerm = fixedTerm;
info.seed      = seed;
info.beta      = betaUsed;
info.opts      = opts;

if ~isempty(opts.saveFile)
    save(opts.saveFile,'W','info','-v7.3');
    fprintf('saved to %s\n', opts.saveFile);
end

    function localTick()
        done = done + 1;
        fprintf('  %d/%d  (%.1f s)\n', done, nSample, toc(tStart));
    end
end

%% ===========================================================================
function [match,results,stable] = localRunWeightSet(forms,params,targets,w,seed,applyPars,betaOpt)
% Generate every configuration under one weight vector and score it.
n = numel(forms);
results = strings(1,n);
stable  = false(1,n);

for i = 1:n
    rng(seed+i,'twister');          % identical draws for every weight vector

    mc = modeConfig(forms(i), Weights=w);
    c  = gmConfigurator(mc);

    % Config-specific params first (Beta, Method, StabCrit), then the swept
    % weights, so the sweep wins over any weight set inside params.
    if applyPars && strlength(params(i)) > 0
        c = c.setParams(params(i));
    end
    c.Weights = w;

    if isempty(betaOpt)
        c = c.genModeConfig(Method='bonding_stochastic');
    else
        c = c.genModeConfig(Method='bonding_stochastic', beta=betaOpt);
    end

    results(i) = c.FinalConfig.ToString();
    stable(i)  = ~isempty(c.Stabilized) && c.Stabilized;
end

match = results == targets(:)';
end

%% ===========================================================================
function w = localBuildWeights(wRef, varyTerms, values, fixedTerm)
w = wRef;
for k = 1:numel(varyTerms)
    w.(varyTerms(k)) = values(k);
end
w.(fixedTerm) = 1;
end

%% ===========================================================================
function S = localLatinHypercubeLog(n, d, lo, hi)
% Latin hypercube on a log scale, no Statistics Toolbox needed.
S = zeros(n,d);
for j = 1:d
    u = ((1:n)' - rand(n,1))/n;     % one draw per stratum
    S(:,j) = u(randperm(n));        % strata shuffled independently per dim
end
S = exp(log(lo) + S*(log(hi)-log(lo)));
end

%% ===========================================================================
function G = localFullGrid(levels, d)
if numel(levels)^d > 5e4
    error('exploreWeights:gridTooBig','grid would be %d points; use sampling="lhs"', ...
        numel(levels)^d);
end
c = cell(1,d);
[c{:}] = ndgrid(levels);
G = cell2mat(cellfun(@(x)x(:), c, 'UniformOutput', false));
end

%% ===========================================================================
function s = localAsStringCol(p, n)
if isempty(p)
    s = strings(n,1);
else
    s = string(p(:));
end
s(ismissing(s)) = "";
if numel(s) ~= n, s = strings(n,1); end
end
