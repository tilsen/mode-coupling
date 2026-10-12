function [P,S] = weightOrderings(W,opts)
%WEIGHTORDERINGS  Extract pairwise ordering constraints from a weight sweep.
%
%   [P,S] = weightOrderings(W) takes the table from exploreWeights and
%   reports, for every ordered pair of energy terms (a,b):
%
%     necessity - among the best-scoring weight vectors, the fraction with
%                 w_a > w_b. A value of 1 means every good vector sampled
%                 put a above b, so the ordering looks required.
%
%     leverage  - mean accuracy when w_a > w_b minus mean accuracy when
%                 w_a < w_b, over ALL samples. This says how much the
%                 ordering matters, separately from whether it holds among
%                 the winners. Necessity near 1 with leverage near 0 usually
%                 means the sampling range, not the model, forced it.
%
%     minRatio/maxRatio - range of w_a/w_b over the best vectors, i.e. how
%                 much slack the constraint has.
%
%   P is every pair; S is the subset that looks genuinely required.
%
%   Caveat: with Beta large the selection is effectively argmin, so accuracy
%   is exactly piecewise constant in w -- the space is carved into cones by
%   hyperplanes through the origin, and every w inside a cone gives identical
%   results. Sampling finds constraints holding within the box you sampled,
%   not globally.

arguments
    W table
    opts.tol = 0                % accuracy within this of max counts as best
    opts.minBest = 5            % require at least this many best vectors
    opts.minLeverage = 0.02
    opts.verbose = true
end

meta  = ["nMatch" "accuracy" "nStable"];
terms = string(W.Properties.VariableNames);
terms = terms(~ismember(terms, meta));

acc  = W.accuracy;
best = acc >= max(acc) - opts.tol;

if sum(best) < opts.minBest
    [~,ord] = sort(acc,'descend');
    best = false(height(W),1);
    best(ord(1:min(opts.minBest,height(W)))) = true;
    warning('weightOrderings:fewBest', ...
        'fewer than %d vectors at peak accuracy; using the top %d instead', ...
        opts.minBest, sum(best));
end

if opts.verbose
    fprintf('best accuracy %.3f over %d of %d sampled vectors\n', ...
        max(acc), sum(best), height(W));
end

n = numel(terms);
rows = cell(0,6);

for a = 1:n
    for b = 1:n
        if a == b, continue; end
        wa = W.(terms(a));
        wb = W.(terms(b));

        gt = wa > wb;
        lt = wa < wb;
        if ~any(gt) || ~any(lt)
            continue                 % this ordering never varied
        end

        necessity = mean(gt(best));
        leverage  = mean(acc(gt)) - mean(acc(lt));

        r = wa ./ wb;
        rb = r(best);
        rb = rb(isfinite(rb));
        if isempty(rb), rb = NaN; end

        rows(end+1,:) = {terms(a), terms(b), necessity, leverage, ...
            min(rb), max(rb)}; %#ok<AGROW>
    end
end

if isempty(rows)
    P = table(); S = table();
    warning('weightOrderings:noPairs','no pair varied its ordering across samples');
    return
end

P = cell2table(rows, 'VariableNames', ...
    {'termA','termB','necessity','leverage','minRatio','maxRatio'});
P = sortrows(P, {'necessity','leverage'}, {'descend','descend'});

S = P(P.necessity == 1 & P.leverage >= opts.minLeverage, :);

if opts.verbose
    if isempty(S)
        fprintf('no ordering held universally among the best vectors\n');
    else
        fprintf('\nOrderings holding in every best-scoring vector:\n');
        for i = 1:height(S)
            fprintf('  %-14s > %-14s   (leverage %+.3f, ratio %.2f-%.2f)\n', ...
                S.termA(i), S.termB(i), S.leverage(i), S.minRatio(i), S.maxRatio(i));
        end
    end
end
end
