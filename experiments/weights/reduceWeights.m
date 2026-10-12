function [OUT] = reduceWeights(w,opts)
%REDUCEWEIGHTS  Shrink a working weight vector toward the smallest, then the
%most robust, vector that still hits the target accuracy.
%
%   OUT = reduceWeights(w) takes a weight struct known to reach the target
%   (typically gmConfigurator.defWeights()) and runs three phases:
%
%     SHRINK   move each term toward 1 (and toward 0 where that is free) as
%              far as accuracy allows, minimizing opts.objective. Repeated in
%              passes until nothing moves, since the first pass is
%              path-dependent.
%     CENTER   for each term, find the interval it can move within while
%              accuracy holds, and place it at the geometric centre. This
%              buys margin -- distance from the nearest tie -- at some cost
%              in compactness. Controlled by opts.center (0 = skip).
%     SNAP     round each term to a nearby "nice" value and keep the rounding
%              if accuracy survives, so the reported vector is quotable.
%
%   Since bonding_stochastic divides dE by norm(weights,1), scaling the whole
%   vector changes nothing. "Reducing" therefore means compressing the spread
%   of ratios, not lowering magnitudes. opts.fixedTerm stays pinned throughout.
%
%   opts.objective:
%     "sumlog"  (default) sum of |log(w)| over free terms. Symmetric in
%               ratios, so a term at 1/5 counts the same as one at 5.
%     "range"   max(log w) - min(log w). Compresses the dynamic range; will
%               happily leave a middling term alone to pull in an extreme one.
%     "sum"     sum(w). Pulls large terms down hard, ignores small ones.
%     "maxabs"  max |log w|. Minimax: only the worst offender counts.
%
%   Outputs (all weight structs are directly usable):
%     OUT.wShrunk   after the shrink phase
%     OUT.wCentered after centering (== wShrunk if opts.center == 0)
%     OUT.wFinal    after snapping; the one to report
%     OUT.slack     per-term feasible interval around wCentered
%     OUT.trace     table of every accepted move
%     OUT.nEval     number of scoreWeights calls
%
%   Cost: each evaluation is a full run over the configuration set. Expect
%   roughly nProbe evaluations per term per phase per pass. With parallel=true
%   the probes within one line search run concurrently, so wall time is about
%   one evaluation per line search rather than nProbe.
%
%   Example:
%       OUT = reduceWeights(gmConfigurator.defWeights(), excludeGroup="locality");
%       disp(OUT.slack)

arguments
    w struct

    % --- configuration selection (passed to scoreWeights) ----------------
    opts.form          = []
    opts.word          = []
    opts.group         = []
    opts.excludeGroup  = "locality"
    opts.requireTarget = true

    % --- execution -------------------------------------------------------
    opts.seed     = 0
    opts.beta     = []                % [] = gmConfigurator's Beta property
    opts.parallel = true

    % --- what counts as success -----------------------------------------
    opts.targetAcc = []               % [] = accuracy of the input vector

    % --- reduction -------------------------------------------------------
    opts.objective = "sumlog"         % sumlog | range | sum | maxabs
    opts.fixedTerm = "bound"
    opts.freeTerms = []               % [] = every term but fixedTerm
    opts.allowZero = true             % probe 0 as well (term removal)
    opts.maxPasses = 3
    opts.nProbe    = 8                % candidates per line search
    opts.logTol    = 0.02             % stop when a move is smaller than this
                                      % in log units (~2%)

    % --- margin and presentation ----------------------------------------
    opts.center = 1                   % 0 = skip, 1 = full geometric centring
    opts.snap   = false
    opts.snapValues = [0.001 0.002 0.005 0.01 0.02 0.05 0.1 0.2 0.25 0.5 ...
                       1 2 3 4 5 6 8 10 12 15 20 25 30 40 50 75 100 150 200]

    opts.verbose = true
    opts.saveFile = "reduction.mat"   % relative names resolve against this
                                      % function's folder; [] or "" to skip

    % --- exact constraint region ----------------------------------------
    opts.cone       = false           % also derive the cone by LP: exact
                                      % two-sided bounds per term, the most
                                      % compact vector, and the most
                                      % tie-resistant one. Needs the
                                      % Optimization Toolbox.
    opts.coneMargin = 1e-3            % RELATIVE: A*w >= coneMargin*sum(w)
    opts.coneFrom   = "final"         % which vector to record from:
                                      % "start" | "shrunk" | "final"
end

%% ------------------------------------------------------------------ setup
SEL = struct('form',opts.form,'word',opts.word,'group',opts.group, ...
             'excludeGroup',opts.excludeGroup,'requireTarget',opts.requireTarget);
selArgs = namedargs2cell(SEL);

terms = gmConfigurator.EnergyTerms(:);
missing = terms(~isfield(w, terms));
if ~isempty(missing)
    error('reduceWeights:missingTerms','weight struct has no field for: %s', ...
        strjoin(missing,', '));
end

fixedTerm = string(opts.fixedTerm);
if ~ismember(fixedTerm, terms)
    error('reduceWeights:badFixedTerm','"%s" is not a weight term', fixedTerm);
end

if isempty(opts.freeTerms)
    freeTerms = terms(terms ~= fixedTerm);
else
    freeTerms = string(opts.freeTerms(:));
    freeTerms = freeTerms(freeTerms ~= fixedTerm);
end

% Work in the fixedTerm = 1 chart throughout.
scale = w.(fixedTerm);
if scale == 0
    error('reduceWeights:zeroFixedTerm','"%s" is 0 and cannot be the reference', fixedTerm);
end
for k = 1:numel(terms)
    w.(terms(k)) = w.(terms(k))/scale;
end

ev = struct('n',0,'selArgs',{selArgs},'seed',opts.seed,'beta',opts.beta, ...
            'parallel',opts.parallel);

acc0 = localAcc(w, ev);
ev.n = ev.n + 1;

if isempty(opts.targetAcc)
    targetAcc = acc0;
else
    targetAcc = opts.targetAcc;
end

if acc0 < targetAcc
    error('reduceWeights:startsBelowTarget', ...
        'input vector scores %.3f, below the target %.3f', acc0, targetAcc);
end

if opts.verbose
    fprintf('start: acc %.3f, target %.3f, objective "%s" = %.4g\n', ...
        acc0, targetAcc, opts.objective, localObjective(w, freeTerms, opts.objective));
    localShow(w, terms, opts.fixedTerm);
end

trace = cell(0,5);
wStart = w;                 % before shrink mutates the working copy

%% ------------------------------------------------------------- 1. shrink
if opts.verbose, fprintf('\n=== SHRINK ===\n'); end

for pass = 1:opts.maxPasses
    moved = false;

    % Process the terms whose reduction would help the objective most, first.
    gain = arrayfun(@(t) localGain(w, freeTerms, t, opts.objective), freeTerms);
    [~,ord] = sort(gain,'descend');

    for kk = 1:numel(ord)
        t  = freeTerms(ord(kk));
        v0 = w.(t);
        if v0 == 0, continue; end

        [vNew, ev] = localLineSearch(w, t, v0, 1, targetAcc, ev, opts);

        % A term that can go to zero is maximally reduced; probe it directly.
        if opts.allowZero && abs(log(vNew)) > opts.logTol
            wz = w; wz.(t) = 0;
            if localAcc(wz, ev) >= targetAcc
                vNew = 0;
            end
            ev.n = ev.n + 1;
        end

        if vNew == 0 || abs(log(vNew) - log(v0)) > opts.logTol
            w.(t) = vNew;
            moved = true;
            trace(end+1,:) = {"shrink", t, v0, vNew, ...
                localObjective(w, freeTerms, opts.objective)}; %#ok<AGROW>
            if opts.verbose
                fprintf('  %-14s %8.4g -> %-8.4g  obj %.4g\n', t, v0, vNew, ...
                    localObjective(w, freeTerms, opts.objective));
            end
        elseif opts.verbose && pass == 1
            fprintf('  %-14s %8.4g     (pinned)\n', t, v0);
        end
    end

    if ~moved
        if opts.verbose, fprintf('  pass %d: nothing moved, stopping\n', pass); end
        break
    end
end

wShrunk = w;

%% ------------------------------------------------------------- 2. centre
% Coordinate-wise intervals do not guarantee joint feasibility, so the
% centred vector is verified and walked back toward wShrunk if it fails.

slack = table(freeTerms, nan(numel(freeTerms),1), nan(numel(freeTerms),1), ...
    nan(numel(freeTerms),1), 'VariableNames', {'term','lo','value','hi'});

if opts.center > 0
    if opts.verbose, fprintf('\n=== CENTER (margin) ===\n'); end

    wc = wShrunk;
    for kk = 1:numel(freeTerms)
        t  = freeTerms(kk);
        v0 = wShrunk.(t);
        if v0 == 0
            slack{kk,2:4} = [0 0 0];
            continue
        end

        [lo, ev] = localLineSearch(wShrunk, t, v0, v0/64,  targetAcc, ev, opts);
        [hi, ev] = localLineSearch(wShrunk, t, v0, v0*64,  targetAcc, ev, opts);

        vMid = exp(log(lo) + opts.center*(0.5*(log(lo)+log(hi)) - log(lo)));
        wc.(t) = vMid;
        slack{kk,2:4} = [lo vMid hi];

        if opts.verbose
            fprintf('  %-14s [%.4g, %.4g] -> %.4g\n', t, lo, hi, vMid);
        end
    end

    % Joint check, with a walk-back toward wShrunk if the corners don't hold.
    lambda = 1;
    while lambda > 1e-3
        wTry = localBlend(wShrunk, wc, freeTerms, lambda);
        if localAcc(wTry, ev) >= targetAcc
            ev.n = ev.n + 1;
            break
        end
        ev.n = ev.n + 1;
        lambda = lambda/2;
        if opts.verbose
            fprintf('  joint check failed; backing off to lambda=%.3g\n', lambda);
        end
    end
    wCentered = localBlend(wShrunk, wc, freeTerms, lambda);
    trace(end+1,:) = {"center", "(all)", NaN, lambda, ...
        localObjective(wCentered, freeTerms, opts.objective)};
else
    wCentered = wShrunk;
end

%% --------------------------------------------------------------- 3. snap
wFinal = wCentered;

if opts.snap
    if opts.verbose, fprintf('\n=== SNAP ===\n'); end
    for kk = 1:numel(freeTerms)
        t  = freeTerms(kk);
        v0 = wFinal.(t);
        if v0 == 0, continue; end

        cand = opts.snapValues(:);
        [~,ix] = sort(abs(log(cand/v0)));         % nearest first, in log space
        cand = cand(ix(1:min(4,numel(ix))));

        for c = cand(:)'
            if abs(log(c/v0)) < 1e-9, break; end   % already there
            wt = wFinal; wt.(t) = c;
            ok = localAcc(wt, ev) >= targetAcc;
            ev.n = ev.n + 1;
            if ok
                wFinal.(t) = c;
                trace(end+1,:) = {"snap", t, v0, c, ...
                    localObjective(wFinal, freeTerms, opts.objective)}; %#ok<AGROW>
                if opts.verbose
                    fprintf('  %-14s %8.4g -> %.4g\n', t, v0, c);
                end
                break
            end
        end
    end
end

%% -------------------------------------------------------------- assemble
accShrunk   = localAcc(wShrunk,   ev);
accCentered = localAcc(wCentered, ev);
accFinal    = localAcc(wFinal,    ev);
ev.n = ev.n + 3;

OUT = struct();
OUT.wStart     = wStart;                % in the fixedTerm=1 chart
OUT.wShrunk    = wShrunk;
OUT.wCentered  = wCentered;
OUT.wFinal     = wFinal;
OUT.accStart   = acc0;
OUT.accShrunk  = accShrunk;
OUT.accCentered= accCentered;
OUT.accFinal   = accFinal;
OUT.targetAcc  = targetAcc;
OUT.slack      = slack;
OUT.terms      = terms;
OUT.freeTerms  = freeTerms;
OUT.fixedTerm  = fixedTerm;
OUT.objective  = opts.objective;
OUT.objStart   = localObjective(OUT.wStart,    freeTerms, opts.objective);
OUT.objShrunk  = localObjective(wShrunk,   freeTerms, opts.objective);
OUT.objFinal   = localObjective(wFinal,    freeTerms, opts.objective);
OUT.nEval      = ev.n;
OUT.opts       = opts;

if isempty(trace)
    OUT.trace = table();
else
    OUT.trace = cell2table(trace, 'VariableNames', ...
        {'phase','term','from','to','objective'});
end

%% ---------------------------------------------------------- 4. cone (exact)
% The search phases bisect toward boundaries one coordinate at a time, so
% every interval they report is conditional on the other terms staying put.
% The cone gives the exact joint region in one pass.
if opts.cone
    if opts.verbose, fprintf('\n=== CONE (exact) ===\n'); end

    switch lower(string(opts.coneFrom))
        case "start",  wRec = wStart;
        case "shrunk", wRec = wShrunk;
        otherwise,     wRec = wFinal;
    end

    [accRec,~,~,infoRec] = scoreWeights(wRec, selArgs{:}, ...
        seed=opts.seed, beta=opts.beta, recordDecisions=true, ...
        verbose=opts.verbose);

    if ~isfield(infoRec,'A') || isempty(infoRec.A)
        warning('reduceWeights:noConstraints', ...
            ['no constraint rows recorded -- check genModeConfig accepts ' ...
             'recordDecisions and populates obj.Decisions']);
        OUT.cone = struct('A',[]);
    else
        OUT.cone = weightCone(infoRec.A, terms, ...
            fixedTerm = fixedTerm, margin = opts.coneMargin, verbose = opts.verbose);
        OUT.cone.A            = infoRec.A;
        OUT.cone.recordedFrom = wRec;
        OUT.cone.accuracy     = accRec;

        % The search-based slack intervals are one-at-a-time; the cone bounds
        % are joint. Where they disagree, the cone is the stricter truth.
        if ~isempty(slack) && any(~isnan(slack.lo))
            B = OUT.cone.bounds;
            cmp = table(slack.term, slack.lo, slack.hi, ...
                nan(height(slack),1), nan(height(slack),1), ...
                'VariableNames', {'term','searchLo','searchHi','coneLo','coneHi'});
            [tf,loc] = ismember(cmp.term, B.term);
            cmp.coneLo(tf) = B.lo(loc(tf));
            cmp.coneHi(tf) = B.hi(loc(tf));
            OUT.cone.comparison = cmp;
            if opts.verbose
                fprintf('\nsearch intervals (one term at a time) vs cone bounds (joint):\n');
                disp(cmp)
            end
        end
    end
end

%% ------------------------------------------------------------- report
if opts.verbose
    fprintf('\n=== RESULT ===\n');
    fprintf('objective "%s": start %.4g -> shrunk %.4g -> final %.4g\n', ...
        opts.objective, OUT.objStart, OUT.objShrunk, OUT.objFinal);
    if OUT.objFinal > OUT.objShrunk
        fprintf(['  centring and snapping gave back %.4g of the %.4g that shrink\n' ...
                 '  won -- use wShrunk for compactness, wFinal for margin, or\n' ...
                 '  lower opts.center to trade between them\n'], ...
            OUT.objFinal-OUT.objShrunk, OUT.objStart-OUT.objShrunk);
    end
    fprintf('accuracy: start %.3f, shrunk %.3f, centred %.3f, final %.3f (target %.3f)\n', ...
        acc0, accShrunk, accCentered, accFinal, targetAcc);
    fprintf('evaluations: %d\n\n', ev.n);
    localShow(wFinal, terms, opts.fixedTerm);

    if accFinal < targetAcc
        warning('reduceWeights:belowTarget', ...
            'final vector scores %.3f, below target -- use wShrunk instead', accFinal);
    end
end

if ~isempty(opts.saveFile) && strlength(string(opts.saveFile)) > 0
    f = localResolvePath(opts.saveFile);
    RED = OUT; %#ok<NASGU>
    save(f,'RED','-v7.3');
    if opts.verbose, fprintf('\nsaved to %s\n', f); end
    OUT.saveFile = f;
end
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
function [vBest, ev] = localLineSearch(wBase, t, v0, vLimit, targetAcc, ev, opts)
% Move w.(t) from v0 toward vLimit as far as accuracy allows. Probes a
% log-spaced grid (in parallel when enabled), then refines once between the
% last feasible point and the first infeasible one.

vBest = v0;
if abs(log(vLimit/v0)) < opts.logTol, return; end

for round = 1:2
    probes = exp(linspace(log(vBest), log(vLimit), opts.nProbe+1));
    probes = probes(2:end);                      % skip the current value

    ok = false(size(probes));
    if opts.parallel
        parfor p = 1:numel(probes)
            wp = wBase; wp.(t) = probes(p);
            ok(p) = localAcc(wp, ev) >= targetAcc;
        end
    else
        for p = 1:numel(probes)
            wp = wBase; wp.(t) = probes(p);
            ok(p) = localAcc(wp, ev) >= targetAcc;
        end
    end
    ev.n = ev.n + numel(probes);

    % Feasibility need not be monotone along the path (the cone boundary can
    % be crossed more than once), so take the furthest feasible probe, not
    % the first infeasible one.
    last = find(ok, 1, 'last');
    if isempty(last), return; end

    vPrev = vBest;
    vBest = probes(last);

    if last == numel(probes), return; end        % reached the limit
    vLimit = probes(last+1);                     % refine into the gap
    if abs(log(vLimit/vBest)) < opts.logTol, return; end
    if abs(log(vBest/vPrev)) < opts.logTol, return; end
end
end

%% ===========================================================================
function a = localAcc(w, ev)
a = scoreWeights(w, ev.selArgs{:}, seed=ev.seed, beta=ev.beta);
end

%% ===========================================================================
function v = localObjective(w, freeTerms, objective)
x = arrayfun(@(t) w.(t), freeTerms);
x = x(x > 0);                       % a removed term costs nothing
if isempty(x), v = 0; return; end
L = log(x);

switch lower(string(objective))
    case "sumlog", v = sum(abs(L));
    case "range",  v = max([L;0]) - min([L;0]);   % include the fixed term at 1
    case "sum",    v = sum(x);
    case "maxabs", v = max(abs(L));
    otherwise
        error('reduceWeights:badObjective', ...
            'objective must be sumlog, range, sum, or maxabs');
end
end

%% ===========================================================================
function g = localGain(w, freeTerms, t, objective)
% How much would the objective improve if this term went all the way to 1?
wt = w; wt.(t) = 1;
g = localObjective(w, freeTerms, objective) - localObjective(wt, freeTerms, objective);
end

%% ===========================================================================
function wb = localBlend(wA, wB, freeTerms, lambda)
% Geometric interpolation from wA (lambda=0) to wB (lambda=1).
wb = wA;
for k = 1:numel(freeTerms)
    t = freeTerms(k);
    a = wA.(t); b = wB.(t);
    if a == 0 || b == 0
        if lambda >= 1, wb.(t) = b; else, wb.(t) = a; end
    else
        wb.(t) = exp((1-lambda)*log(a) + lambda*log(b));
    end
end
end

%% ===========================================================================
function localShow(w, terms, fixedTerm)
for k = 1:numel(terms)
    mark = "";
    if terms(k) == fixedTerm, mark = "   (fixed)"; end
    fprintf('  %-14s %10.4g%s\n', terms(k), w.(terms(k)), mark);
end
end
