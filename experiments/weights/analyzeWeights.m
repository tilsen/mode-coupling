function [RES] = analyzeWeights(opts)
%ANALYZEWEIGHTS  Infer which energy terms matter and how they must be ordered.
%
%   RES = analyzeWeights() runs the full pipeline and returns a struct with
%   every intermediate result.
%
%   RES = analyzeWeights(analyses=[...]) runs only the named stages.
%   Prerequisites are pulled in automatically, so analyses="diagnosis" also
%   runs baseline, ablation, sweep, and orderings.
%
%   Stages, in execution order:
%
%     "beta"       ladder over beta to check the selection is cold enough.
%                  bonding_stochastic divides dE by norm(weights,1), so beta
%                  is in units of normalized energy and its right magnitude
%                  depends on the weight scale. Run after any change to the
%                  normalization or to the default weight magnitudes.
%     "baseline"   accuracy at the default weights.
%     "ablation"   PRESENCE: zero each term in turn. Does it need to be
%                  nonzero at all? Needs baseline.
%     "sweep"      sample the weight space (exploreWeights).
%     "box"        did the best vectors press against the sampled bounds?
%                  Needs sweep.
%     "orderings"  RANK: pairwise necessity and leverage. Needs sweep.
%     "diagnosis"  cross presence against rank. Needs ablation + orderings.
%     "failures"   configurations no sampled vector ever matched. Needs sweep.
%     "verify"     re-score the sweep's best vector through scoreWeights.
%                  Needs sweep.
%     "matrices"   reshape the pairwise table into leverage / necessity /
%                  ratio matrices, ordered by inferred rank. Needs orderings.
%     "cone"       EXACT: record the constraint rows that make the chosen
%                  trajectory optimal, then answer by linear programming
%                  instead of sampling -- two-sided bounds per term, forced
%                  orderings, and the most tie-resistant vector. Uses wBest
%                  if verify has run, otherwise the defaults. Requires the
%                  Optimization Toolbox.
%
%   PRESENCE and RANK are independent questions. bound scores low on rank and
%   high on presence; phasebias scored low on both. A term is only removable
%   if it is low on BOTH.
%
%   RES = analyzeWeights(resume="weightAnalysis.mat", analyses="orderings")
%   reloads a saved run and recomputes only that stage.
%
%   Examples:
%       RES = analyzeWeights();                          % everything
%       RES = analyzeWeights(analyses="ablation");       % + baseline
%       RES = analyzeWeights(analyses=["sweep" "orderings" "box"], nSamples=200)
%       RES = analyzeWeights(analyses="beta");           % just the cold check

arguments
    % --- configuration selection (shared by every stage) -----------------
    opts.form          = []
    opts.word          = []
    opts.group         = []
    opts.excludeGroup  = "locality"   % phasebias=1 there encodes a different
                                      % language's settings, not this model's
    opts.requireTarget = true

    % --- sweep -----------------------------------------------------------
    opts.fixedTerm = "bound"          % scale reference
    opts.hold      = struct()         % e.g. struct('phasebias',0)
    opts.varyTerms = []
    opts.nSamples  = 100
    opts.range     = [1/16 16]        % multiplicative box around defaults
    opts.sampling  = "lhs"

    % --- execution -------------------------------------------------------
    opts.seed       = 0
    opts.beta       = []              % [] = gmConfigurator's Beta property
    opts.parallel   = true
    opts.betaLadder = [1e2 1e3 1e4 1e5 1e6]

    % --- inference -------------------------------------------------------
    opts.tol         = 0              % accuracy within this of max = "best"
    opts.minLeverage = 0.02
    opts.coneMargin  = 1e-3           % RELATIVE margin: require
                                      % A*w >= coneMargin*sum(w). Scale
                                      % invariant, so it works with the
                                      % norm(w,1) division in the model.
                                      % A decision is frozen once
                                      % beta*coneMargin exceeds about 10.
                                      % 0 gives the closed cone, whose
                                      % boundary is exact ties.

    % --- control ---------------------------------------------------------
    opts.analyses    = "all"
    opts.resume      = []             % .mat from a previous run
    opts.saveFile    = "weightAnalysis.mat"   % relative names resolve against
                                              % this function's folder
    opts.clearCaches = true           % drop cached CSV reads before starting
end

if opts.clearCaches
    clear gmConfigurator articulae
end

RES    = localInit(opts);
stages = localResolve(opts.analyses);

fprintf('running: %s\n', strjoin(stages,' -> '));

for s = 1:numel(stages)
    switch stages(s)
        case "beta",      RES = stageBeta(RES);
        case "baseline",  RES = stageBaseline(RES);
        case "ablation",  RES = stageAblation(RES);
        case "sweep",     RES = stageSweep(RES);
        case "box",       RES = stageBox(RES);
        case "orderings", RES = stageOrderings(RES);
        case "diagnosis", RES = stageDiagnosis(RES);
        case "failures",  RES = stageFailures(RES);
        case "verify",    RES = stageVerify(RES);
        case "matrices",  RES = stageMatrices(RES);
        case "cone",      RES = stageCone(RES);
    end
end

RES.stagesRun = stages;

if ~isempty(opts.saveFile) && strlength(string(opts.saveFile)) > 0
    f = localResolvePath(opts.saveFile);
    save(f,'RES','-v7.3');
    fprintf('\nsaved to %s\n', f);
    RES.saveFile = f;
end
end

%% ===========================================================================
function RES = stageCone(RES)
% Exact constraint region, by linear programming rather than sampling.
fprintf('\n=== CONE (exact) ===\n');

if isfield(RES,'wBest') && ~isempty(fieldnames(RES.wBest))
    w = RES.wBest;
    fprintf('recording from wBest\n');
else
    w = RES.w0;
    fprintf('recording from the defaults (run "verify" first to use wBest)\n');
end

[acc,~,~,info] = scoreWeights(w, RES.selArgs{:}, ...
    seed=RES.opts.seed, beta=RES.opts.beta, recordDecisions=true, verbose=true);

if ~isfield(info,'A') || isempty(info.A)
    warning('analyzeWeights:noConstraints', ...
        ['no constraint rows recorded -- check that genModeConfig accepts ' ...
         'recordDecisions and populates obj.Decisions']);
    RES.CONE = struct('A',[],'accuracy',acc);
    return
end

if acc < 1
    fprintf(['note: the recording vector scores %.3f, so the cone describes ' ...
             'only the %d configurations it got right\n'], acc, nnz(info.usedConfigs));
end

RES.CONE = weightCone(info.A, RES.terms, ...
    fixedTerm = RES.opts.fixedTerm, ...
    margin    = RES.opts.coneMargin, ...
    beta      = RES.betaInForce, ...
    verbose   = true);

RES.CONE.A          = info.A;
RES.CONE.accuracy   = acc;
RES.CONE.usedConfigs = info.usedConfigs;
RES.CONE.recordedFrom = w;
if isfield(info,'nDropped'), RES.CONE.nDropped = info.nDropped; end

if isfield(info,'nDropped') && info.nDropped > 0
    fprintf(['%d near-tie decision(s) dropped: the cone describes the ' ...
             'argmin-consistent\npart of the trajectory, so those choices ' ...
             'stay seed-dependent whatever the weights\n'], info.nDropped);
end

% The point of this stage: two-sided bounds that a Hasse diagram cannot show.
B = RES.CONE.bounds;
free = B.term(B.lo <= 0 & B.unbounded);
if ~isempty(free)
    fprintf('unconstrained in the cone: %s\n', strjoin(free,', '));
end

% An LP vector is a claim about the model, not a measurement of it. Score the
% two candidates so the stage says outright whether they hold up.
if ~isempty(fieldnames(RES.CONE.minSum))
    RES.CONE.minSumAcc = scoreWeights(RES.CONE.minSum, RES.selArgs{:}, ...
        seed=RES.opts.seed, beta=RES.opts.beta);
    fprintf('minSum scores %.3f\n', RES.CONE.minSumAcc);
end
if ~isempty(fieldnames(RES.CONE.interior))
    RES.CONE.interiorAcc = scoreWeights(RES.CONE.interior, RES.selArgs{:}, ...
        seed=RES.opts.seed, beta=RES.opts.beta);
    fprintf('interior scores %.3f (relative margin %.4g)\n', ...
        RES.CONE.interiorAcc, RES.CONE.maxMargin);
end
end

%% ===========================================================================
function RES = stageMatrices(RES)
% Reshape the long-form pairwise table into square matrices, ordered by
% inferred rank so the positive block lands in the upper triangle.
fprintf('\n=== MATRICES ===\n');

terms = RES.terms;
n     = numel(terms);
ix    = @(t) find(terms == t, 1);

L = nan(n);   % leverage: mean acc when a>b minus mean acc when a<b
N = nan(n);   % necessity: fraction of best vectors with a>b
Rlo = nan(n); % ratio bounds over the best vectors
Rhi = nan(n);

for i = 1:height(RES.P)
    a = ix(RES.P.termA(i));  b = ix(RES.P.termB(i));
    if isempty(a) || isempty(b), continue; end
    L(a,b)   = RES.P.leverage(i);
    N(a,b)   = RES.P.necessity(i);
    Rlo(a,b) = RES.P.minRatio(i);
    Rhi(a,b) = RES.P.maxRatio(i);
end

% Rank order: by net leverage (row mean minus column mean), which is a
% Borda-style score and agrees with the Hasse levels when those are clean.
net = mean(L,2,'omitnan') - mean(L,1,'omitnan')';
net(isnan(net)) = 0;
[~,ord] = sort(net,'descend');

MAT = struct();
MAT.terms     = terms(ord);
MAT.leverage  = L(ord,ord);
MAT.necessity = N(ord,ord);
MAT.minRatio  = Rlo(ord,ord);
MAT.maxRatio  = Rhi(ord,ord);
MAT.netLeverage = net(ord);

% NaN means the pair never varied its ordering in the sample -- the box could
% not separate them. That is not the same as zero leverage, so flag it.
MAT.unseparated = isnan(L(ord,ord)) & ~eye(n,'logical');

RES.MAT = MAT;

fprintf('rank order by net leverage: %s\n', strjoin(MAT.terms,' > '));

nUn = nnz(triu(MAT.unseparated,1));
if nUn > 0
    fprintf('%d pair(s) never varied their ordering -- NaN, not zero:\n', nUn);
    [r,c] = find(triu(MAT.unseparated,1));
    for k = 1:numel(r)
        fprintf('  %s / %s\n', MAT.terms(r(k)), MAT.terms(c(k)));
    end
end

% Any positive leverage below the diagonal contradicts the rank order.
below = tril(MAT.leverage,-1);
if any(below(:) > 0)
    [r,c] = find(below > 0);
    fprintf('inconsistent with the rank order (positive below diagonal):\n');
    for k = 1:numel(r)
        fprintf('  %s > %s  (leverage %+.3f)\n', ...
            MAT.terms(r(k)), MAT.terms(c(k)), MAT.leverage(r(k),c(k)));
    end
end

disp(array2table(round(MAT.leverage,3), ...
    'VariableNames', cellstr(MAT.terms), 'RowNames', cellstr(MAT.terms)))
end

%% ===========================================================================
function f = localResolvePath(name)
% Resolve a relative filename against this function's own folder.
name = string(name);
[p,~,e] = fileparts(name);
if strlength(e) == 0, name = name + ".mat"; end
if strlength(p) > 0
    f = name;                                   % caller gave a path; honour it
else
    f = fullfile(fileparts(mfilename('fullpath')), name);
end
end

%% ===========================================================================
%  stage plumbing
%% ===========================================================================
function stages = localResolve(requested)
% Canonical execution order, and what each stage needs before it.
order = ["beta" "baseline" "ablation" "sweep" "box" "orderings" "diagnosis" ...
         "failures" "verify" "matrices" "cone"];

deps = struct( ...
    'beta',      strings(1,0), ...
    'baseline',  strings(1,0), ...
    'ablation',  "baseline", ...
    'sweep',     strings(1,0), ...
    'box',       "sweep", ...
    'orderings', "sweep", ...
    'diagnosis', ["ablation" "orderings"], ...
    'failures',  "sweep", ...
    'verify',    "sweep", ...
    'matrices',  "orderings", ...
    'cone',      strings(1,0));

requested = string(requested(:))';
if any(requested == "all")
    stages = order;
    return
end

bad = requested(~ismember(requested, order));
if ~isempty(bad)
    error('analyzeWeights:badStage','unknown analysis: %s. Available: %s', ...
        strjoin(bad,', '), strjoin(order,', '));
end

% Pull in prerequisites transitively.
want  = requested;
added = true;
while added
    added = false;
    for k = 1:numel(want)
        d   = deps.(want(k));
        new = d(~ismember(d, want));
        if ~isempty(new)
            want  = [want new]; %#ok<AGROW>
            added = true;
        end
    end
end

pulled = unique(want(~ismember(want, requested)));
if ~isempty(pulled)
    fprintf('prerequisites added: %s\n', strjoin(pulled,', '));
end

stages = order(ismember(order, want));   % canonical order
end

%% ===========================================================================
function RES = localInit(opts)
% Shared context: selection, weights, terms, and the beta actually in force.

if ~isempty(opts.resume)
    L   = load(opts.resume,'RES');
    RES = L.RES;
    fprintf('resumed from %s (stages present: %s)\n', ...
        opts.resume, strjoin(RES.stagesRun,', '));
else
    RES = struct();
end

RES.opts = opts;

SEL = struct('form',opts.form,'word',opts.word,'group',opts.group, ...
             'excludeGroup',opts.excludeGroup,'requireTarget',opts.requireTarget);
RES.SEL     = SEL;
RES.selArgs = namedargs2cell(SEL);

RES.terms = gmConfigurator.EnergyTerms(:);
RES.w0    = gmConfigurator.defWeights();

cTmp = gmConfigurator();
if isempty(opts.beta)
    RES.betaInForce = cTmp.Beta;
else
    RES.betaInForce = opts.beta;
end

fprintf('terms: %s\n', strjoin(RES.terms,', '));
fprintf('defaults: %s\n', strjoin(RES.terms + "=" + ...
    arrayfun(@(t)string(num2str(RES.w0.(t))), RES.terms), ', '));
fprintf('beta in force: %g\n', RES.betaInForce);

C = loadConfigs(SEL);
if isempty(C)
    error('analyzeWeights:noConfigs','selection matched no configurations');
end
fprintf('configurations: %d', height(C));
if ~isempty(SEL.excludeGroup)
    fprintf('  (excluding group: %s)', strjoin(string(SEL.excludeGroup),', '));
end
fprintf('\ngroups present: %s\n', strjoin(unique(string(C.group))',', '));
RES.nConfig = height(C);

% An ablation only tests presence relative to the baseline it starts from.
% A term already at 0 cannot be ablated, and multiplicative sampling cannot
% move it off 0 either.
zeroDefaults = RES.terms(arrayfun(@(t) RES.w0.(t)==0, RES.terms));
if ~isempty(zeroDefaults)
    warning('analyzeWeights:zeroDefault', ...
        ['already 0 in defaultWeights.csv: %s -- ablation is a no-op for these, ' ...
         'and multiplicative sampling cannot move them off 0'], ...
        strjoin(zeroDefaults,', '));
end
RES.zeroDefaults = zeroDefaults;
end

%% ===========================================================================
%  stages
%% ===========================================================================
function RES = stageBeta(RES)
fprintf('\n=== BETA LADDER ===\n');
b   = RES.opts.betaLadder(:);
acc = nan(numel(b),1);
for k = 1:numel(b)
    acc(k) = scoreWeights(RES.w0, RES.selArgs{:}, seed=RES.opts.seed, beta=b(k));
    fprintf('  beta=%-9g -> %.3f\n', b(k), acc(k));
end
RES.betaLadder = table(b, acc, 'VariableNames', {'beta','accuracy'});

[~,bestK] = max(acc);
if b(bestK) > RES.betaInForce
    warning('analyzeWeights:betaTooHot', ...
        ['accuracy peaks at beta=%g but beta in force is %g -- raise ' ...
         'gmConfigurator.Beta or pass beta='], b(bestK), RES.betaInForce);
else
    fprintf('  beta=%g is in the cold regime\n', RES.betaInForce);
end
end

%% ===========================================================================
function RES = stageBaseline(RES)
fprintf('\n=== BASELINE ===\n');
t = tic;
[acc,match,results,info] = scoreWeights(RES.w0, RES.selArgs{:}, ...
    seed=RES.opts.seed, beta=RES.opts.beta, verbose=true);
fprintf('  [%.1f s]\n', toc(t));

RES.baseAcc     = acc;
RES.baseMatch   = match;
RES.baseResults = results;
RES.baseInfo    = info;
end

%% ===========================================================================
function RES = stageAblation(RES)
% PRESENCE sensitivity: one run per term with that term zeroed. No
% normalization and no fixed term, so bound ablates like anything else.
fprintf('\n=== ABLATION (presence) ===\n');
t = tic;

acc = nan(numel(RES.terms),1);
for k = 1:numel(RES.terms)
    w = RES.w0;
    w.(RES.terms(k)) = 0;
    acc(k) = scoreWeights(w, RES.selArgs{:}, seed=RES.opts.seed, beta=RES.opts.beta);
    fprintf('  zeroed %-14s -> %.3f\n', RES.terms(k), acc(k));
end

ABL = table(RES.terms, acc, RES.baseAcc-acc, ...
    'VariableNames', {'term','accuracyWithout','drop'});
RES.ABL = sortrows(ABL,'drop','descend');

fprintf('  [%.1f s]\n', toc(t));
disp(RES.ABL)

removable = RES.ABL.term(RES.ABL.drop <= 0);
if isempty(removable)
    fprintf('every term costs something when removed\n');
else
    fprintf('no accuracy cost when zeroed: %s\n', strjoin(removable,', '));
    fprintf('  (removable only if they ALSO show no rank leverage -- see diagnosis)\n');
end
end

%% ===========================================================================
function RES = stageSweep(RES)
fprintf('\n=== SWEEP (rank) ===\n');
o = RES.opts;
[W,info] = exploreWeights(RES.selArgs{:}, ...
    fixedTerm = o.fixedTerm, ...
    hold      = o.hold, ...
    varyTerms = o.varyTerms, ...
    nSamples  = o.nSamples, ...
    range     = o.range, ...
    sampling  = o.sampling, ...
    seed      = o.seed, ...
    beta      = o.beta, ...
    parallel  = o.parallel);

RES.W    = W;
RES.info = info;

nBest = sum(W.accuracy >= max(W.accuracy) - o.tol);
fprintf('best accuracy %.3f over %d of %d vectors\n', ...
    max(W.accuracy), nBest, height(W));
if isfield(RES,'baseAcc')
    fprintf('  (baseline was %.3f)\n', RES.baseAcc);
end
end

%% ===========================================================================
function RES = stageBox(RES)
% A best-scoring vector pressed against a sampled bound means the optimum is
% probably outside the box, and the ratios from orderings are truncated.
fprintf('\n=== BOX CHECK ===\n');
o     = RES.opts;
scale = RES.w0.(o.fixedTerm);
heldT = string(fieldnames(o.hold));
best  = RES.W.accuracy >= max(RES.W.accuracy) - o.tol;
atEdge = strings(0,1);

fprintf('range %.4g to %.4g, %d vector(s) at peak\n', ...
    min(o.range), max(o.range), sum(best));

for k = 1:numel(RES.terms)
    t = RES.terms(k);
    if t == o.fixedTerm || ismember(t,heldT), continue; end
    c = RES.w0.(t)/scale;
    if c == 0, continue; end                  % sampled absolutely, no box
    lo = c*min(o.range);
    hi = c*max(o.range);
    v  = RES.W.(t)(best);
    flag = "";
    if min(v) <= lo*1.01 || max(v) >= hi*0.99
        flag = "  <-- AT EDGE";
        atEdge(end+1,1) = t; %#ok<SAGROW>
    end
    fprintf('  %-14s best %.4g to %.4g   box %.4g to %.4g%s\n', ...
        t, min(v), max(v), lo, hi, flag);
end

RES.atEdge = atEdge;
if ~isempty(atEdge)
    fprintf('\nwiden range and re-run the sweep: %s\n', strjoin(atEdge,', '));
end
if sum(best) < 5
    fprintf(['\nonly %d vector(s) at peak -- orderings will pool lower-scoring\n' ...
             'ones and its necessity column will not mean much. Re-center the\n' ...
             'range on the winner and re-run the sweep.\n'], sum(best));
end
end

%% ===========================================================================
function RES = stageOrderings(RES)
fprintf('\n=== ORDERINGS (rank) ===\n');
[RES.P, RES.S] = weightOrderings(RES.W, ...
    tol=RES.opts.tol, minLeverage=RES.opts.minLeverage);
end

%% ===========================================================================
function RES = stageDiagnosis(RES)
% Cross PRESENCE against RANK. Rank sensitivity per term is the largest
% absolute leverage it takes part in.
fprintf('\n=== COMBINED DIAGNOSIS ===\n');

rankSens = zeros(numel(RES.terms),1);
for k = 1:numel(RES.terms)
    rows = RES.P.termA == RES.terms(k) | RES.P.termB == RES.terms(k);
    if any(rows), rankSens(k) = max(abs(RES.P.leverage(rows))); end
end

ablDrop = RES.ABL.drop(arrayfun(@(t)find(RES.ABL.term==t,1), RES.terms));

DIAG = table(RES.terms, rankSens, ablDrop, ...
    'VariableNames', {'term','maxLeverage','ablationDrop'});
DIAG.verdict = strings(height(DIAG),1);
for k = 1:height(DIAG)
    needed  = DIAG.ablationDrop(k) > 0;
    ordered = DIAG.maxLeverage(k) >= RES.opts.minLeverage;
    if      needed &&  ordered, DIAG.verdict(k) = "structural + ranked";
    elseif  needed && ~ordered, DIAG.verdict(k) = "needed, rank free";
    elseif ~needed &&  ordered, DIAG.verdict(k) = "rank matters, magnitude free";
    else,                       DIAG.verdict(k) = "DEAD - candidate for removal";
    end
end

RES.DIAG = sortrows(DIAG,'ablationDrop','descend');
disp(RES.DIAG)
end

%% ===========================================================================
function RES = stageFailures(RES)
fprintf('\n=== FAILURES ===\n');
never = all(~RES.info.match,1) & RES.info.hasTarget(:)';

fprintf('ceiling %.3f -- %d of %d configurations never matched under any of %d vectors\n', ...
    max(RES.W.accuracy), sum(never), sum(RES.info.hasTarget), height(RES.W));

if any(never)
    RES.FAIL = table(RES.info.words(never), RES.info.targets(never), ...
        RES.info.results(1,never)', ...
        'VariableNames', {'word','target','resultAtBest'});
    disp(RES.FAIL)
    fprintf('these are not a weighting problem -- look at the model or the targets\n');
else
    RES.FAIL = table();
end
end

%% ===========================================================================
function RES = stageVerify(RES)
% Round-trip the sweep's best weights through scoreWeights. A mismatch means
% weights or beta are not being passed identically by the two paths.
fprintf('\n=== VERIFY ===\n');

wBest = table2struct(RES.W(1, cellstr(RES.terms)));
chk   = scoreWeights(wBest, RES.selArgs{:}, seed=RES.opts.seed, beta=RES.opts.beta);

fprintf('best vector re-scored: %.3f (sweep reported %.3f)', chk, RES.W.accuracy(1));
if abs(chk - RES.W.accuracy(1)) > 1e-12
    fprintf('   *** MISMATCH ***');
end
fprintf('\n\nbest weights:\n');
for k = 1:numel(RES.terms)
    fprintf('  %-14s %.4g\n', RES.terms(k), wBest.(RES.terms(k)));
end

RES.wBest    = wBest;
RES.wBestChk = chk;
end
