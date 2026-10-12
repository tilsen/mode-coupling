function [OUT] = weightCone(A,terms,opts)
%WEIGHTCONE  Exact queries over the region of weights that reproduce a run.
%
%   At high beta the selection is argmin, so every choice the search made is a
%   comparison (x_j - x_s)*w >= 0 between the rejected alternative j and the
%   selected one s. Stacking those rows gives A, and {w : A*w >= 0} is exactly
%   the set of weight vectors that reproduce the same trajectory.
%
%   MARGINS ARE RELATIVE. bonding_stochastic divides dE by norm(w,1), so what
%   decides whether a choice is frozen is beta*dE/sum(w), not dE. An absolute
%   margin therefore fights the fixedTerm=1 normalisation -- you cannot scale
%   w up to buy more of it, and the achievable range is capped by an arbitrary
%   quantity. opts.margin here is a fraction of sum(w):
%
%       A*w >= margin * sum(w)
%
%   which is still linear (w >= 0) and is invariant to scaling. A decision is
%   effectively frozen once beta*margin exceeds about 10, so with beta = 1e4 a
%   margin of 1e-3 is ample. margin = 0 gives the closed cone, whose boundary
%   consists of exact ties -- vectors there score below 1.000 because a tie is
%   a coin flip at any beta. Use margin = 0 for the mathematics, a positive
%   margin for a vector you intend to run.
%
%   OUT.bounds      per term, the exact lowest and highest value anywhere in
%                   the cone. The two-sided bound a Hasse diagram cannot show.
%                   Unboundedness is detected by solving at two caps and
%                   seeing which ceilings scale with them.
%   OUT.necessary   ordered pairs where w_a <= w_b is infeasible, i.e. the
%                   ordering is forced, not merely observed in a sample.
%   OUT.interior    the vector maximising the relative margin -- the most
%                   tie-resistant weighting. Cap-free, unlike an absolute
%                   maximin point.
%   OUT.maxMargin   that margin. Multiply by beta to see how frozen it is.
%   OUT.minSum      the vector minimising sum(w) at the requested margin.
%
%   Caveat: A encodes the trajectory that was taken. Weights outside the cone
%   may still reach the targets by a different route, so A*w >= 0 is
%   sufficient for success, not necessary.
%
%   Requires the Optimization Toolbox (linprog).

arguments
    A double
    terms = gmConfigurator.EnergyTerms(:)
    opts.fixedTerm = "bound"
    opts.margin    = 1e-3     % fraction of sum(w); 0 = closed cone
    opts.ub        = 1e6      % cap for the bound solves; a second solve at
                              % 100x this detects genuinely open directions
    opts.pairEps   = 1e-9
    opts.beta      = []       % for reporting beta*margin only
    opts.verbose   = true
end

if isempty(which('linprog'))
    error('weightCone:noLinprog', ...
        'linprog not found -- the Optimization Toolbox is required');
end

terms = string(terms(:));
K = numel(terms);
if size(A,2) ~= K
    error('weightCone:sizeMismatch','A has %d columns but there are %d terms', ...
        size(A,2), K);
end

fixedIx = find(terms == string(opts.fixedTerm), 1);
if isempty(fixedIx)
    error('weightCone:badFixedTerm','"%s" is not a term', opts.fixedTerm);
end

R = size(A,1);
m = opts.margin;

% A*w >= m*sum(w)   ->   (A - m*ones)*w >= 0   ->   -(A - m*ones)*w <= 0
Aeff  = A - m*ones(R,K);
Aineq = -Aeff;
bineq = zeros(R,1);
Aeq   = zeros(1,K);  Aeq(fixedIx) = 1;
beq   = 1;
lb    = zeros(K,1);

o = optimoptions('linprog','Display','none');

%% ------------------------------------------------- feasibility of the cone
ub = opts.ub*ones(K,1);
[~,~,flag] = linprog(zeros(K,1), Aineq, bineq, Aeq, beq, lb, ub, o);
if flag ~= 1
    [mm, wmm] = localMaxMargin(A, K, fixedIx, o);
    if isnan(mm)
        error('weightCone:infeasible', ...
            ['the cone is empty even at margin 0. The recorded rows are ' ...
             'mutually contradictory -- check that they all came from one ' ...
             'weight vector and that near-tie rows were dropped.']);
    else
        error('weightCone:marginTooLarge', ...
            ['no vector achieves a relative margin of %g. The maximum is ' ...
             '%.4g (beta*margin = %.3g at beta=%g). Lower opts.margin.'], ...
            m, mm, mm*localBetaVal(opts.beta), localBetaVal(opts.beta));
    end
end

%% ------------------------------------------------------- per-term bounds
[lo1,hi1] = localBounds(Aineq,bineq,Aeq,beq,lb,opts.ub,      K,o);
[~,  hi2] = localBounds(Aineq,bineq,Aeq,beq,lb,opts.ub*100,  K,o);

% A ceiling that scales with the cap is not a ceiling. Comparing two caps
% catches vertices that sit at a fixed multiple of it, which a single-cap
% test misses.
unbounded = ~isfinite(hi2) | (hi2 > 10*hi1);
hi = hi1;  hi(unbounded) = Inf;

OUT = struct();
OUT.bounds = table(terms, lo1, hi, hi./lo1, unbounded, ...
    'VariableNames', {'term','lo','hi','spread','unbounded'});

%% --------------------------------------------------- necessary orderings
rows = cell(0,2);
for a = 1:K
    for b = 1:K
        if a == b, continue; end
        extra = zeros(1,K); extra(a) = 1; extra(b) = -1;
        [~,~,f] = linprog(zeros(K,1), [Aineq; extra], ...
            [bineq; -opts.pairEps], Aeq, beq, lb, ub, o);
        if f ~= 1
            rows(end+1,:) = {terms(a), terms(b)}; %#ok<AGROW>
        end
    end
end
if isempty(rows)
    OUT.necessary = table(strings(0,1),strings(0,1), ...
        'VariableNames',{'termA','termB'});
else
    OUT.necessary = cell2table(rows, 'VariableNames', {'termA','termB'});
end

%% ------------------------------------------ most tie-resistant vector
[maxM, wMax] = localMaxMargin(A, K, fixedIx, o);
OUT.maxMargin = maxM;
if ~isnan(maxM)
    OUT.interior  = localStruct(terms, wMax);
    OUT.margins   = (A*wMax)/sum(wMax);
else
    OUT.interior = struct();  OUT.margins = [];
end

%% ------------------------------------------------------ most compact vector
[z,v,f] = linprog(ones(K,1), Aineq, bineq, Aeq, beq, lb, ub, o);
if f == 1
    OUT.minSum = localStruct(terms, z);
    OUT.minSumValue = v;
    OUT.minSumMargins = (A*z)/sum(z);
else
    OUT.minSum = struct(); OUT.minSumValue = NaN; OUT.minSumMargins = [];
end

OUT.terms     = terms;
OUT.fixedTerm = string(opts.fixedTerm);
OUT.nRows     = R;
OUT.margin    = m;

%% ------------------------------------------------------------- report
if opts.verbose
    b = localBetaVal(opts.beta);
    fprintf('cone from %d rows, %s fixed at 1, relative margin %g', ...
        R, opts.fixedTerm, m);
    if ~isnan(b), fprintf(' (beta*margin = %.3g)', m*b); end
    fprintf('\n');
    disp(OUT.bounds)

    if isempty(OUT.necessary)
        fprintf('no ordering is forced\n');
    else
        fprintf('forced orderings:\n');
        for i = 1:height(OUT.necessary)
            fprintf('  %-14s > %s\n', OUT.necessary.termA(i), OUT.necessary.termB(i));
        end
    end

    if ~isnan(maxM)
        fprintf('largest achievable relative margin: %.4g', maxM);
        if ~isnan(b), fprintf('  (beta*margin = %.3g)', maxM*b); end
        fprintf('\n');
        if ~isnan(b) && maxM*b < 10
            fprintf(['  note: below ~10 the tightest decision is not frozen, ' ...
                     'so some choices stay seed-dependent\n']);
        end
    end

    open = OUT.bounds.term(OUT.bounds.unbounded);
    if ~isempty(open)
        fprintf('no upper bound: %s\n', strjoin(open,', '));
        fprintf('  (the floors are the finding; the ceilings do not exist)\n');
    end
end
end

%% ===========================================================================
function [lo,hi] = localBounds(Aineq,bineq,Aeq,beq,lb,ubScalar,K,o)
ub = ubScalar*ones(K,1);
lo = nan(K,1); hi = nan(K,1);
for k = 1:K
    c = zeros(K,1); c(k) = 1;
    [~,v,f] = linprog( c, Aineq, bineq, Aeq, beq, lb, ub, o);
    if f == 1, lo(k) = v; end
    [~,v,f] = linprog(-c, Aineq, bineq, Aeq, beq, lb, ub, o);
    if f == 1, hi(k) = -v; end
end
end

%% ===========================================================================
function [maxM, w] = localMaxMargin(A, K, fixedIx, o)
% max t  s.t.  A*w >= t,  sum(w) = 1,  w >= 0.
% Normalising by sum(w) rather than capping makes t a relative margin, so the
% answer does not depend on an arbitrary upper bound. The returned w is
% rescaled so the fixed term sits at 1.
R = size(A,1);
Ai = [-A, ones(R,1)];
Ae = [ones(1,K), 0];
[z,~,f] = linprog([zeros(K,1); -1], Ai, zeros(R,1), Ae, 1, [zeros(K,1); 0], [], o);
if f ~= 1
    maxM = NaN; w = [];
    return
end
maxM = z(K+1);
w    = z(1:K);
if w(fixedIx) > 0
    w = w / w(fixedIx);
end
end

%% ===========================================================================
function b = localBetaVal(betaOpt)
if ~isempty(betaOpt)
    b = betaOpt;
    return
end
try
    c = gmConfigurator();
    b = c.Beta;
catch
    b = NaN;
end
end

%% ===========================================================================
function s = localStruct(terms, v)
s = struct();
for k = 1:numel(terms)
    s.(terms(k)) = v(k);
end
end
