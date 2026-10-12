function [T] = getRatioIntervals(RES,opts)
%GETRATIOINTERVALS  Plot-ready table for a ratio interval (forest) plot.
%
%   T = getRatioIntervals(RES) returns one row per ordering constraint, with
%   the range of w_a/w_b observed across the best-scoring vectors. Drawn as
%   horizontal bars on a log x-axis with a reference line at 1, this shows
%   how much SLACK each constraint has: a bar spanning 5 to 114 is a loose
%   requirement, one spanning 1.2 to 1.4 is tight.
%
%   The width is the point of the figure, so the honest version has to say
%   which endpoints are real and which are artefacts of where you sampled.
%   Each term was sampled over center*[range(1) range(2)], so the ratio a/b
%   could only ever land in (center_a/center_b)*[r1/r2, r2/r1]. When an
%   observed endpoint sits at that limit, the constraint is wider than the
%   box could show and the bar is truncated, not measured. truncLo/truncHi
%   flag exactly that -- draw those ends as arrows rather than caps.
%
%   Columns:
%     pair, from, to        the ordering, as text and as terms
%     lo, hi                observed ratio range over the best vectors
%     logLo, logHi          log10 of the same, for plotting
%     widthDecades          log10(hi/lo); the slack, in orders of magnitude
%     leverage, necessity   carried through from the ordering table
%     y                     row position, 1 at the bottom
%     boxLo, boxHi          what the sampling box could have produced
%     truncLo, truncHi      endpoint sits at the box limit
%     crossesOne            interval spans 1, i.e. the ordering flips within
%                           the best set (only possible when source is "P")
%
%   opts.source   "S" (default) or "P" with your own thresholds.
%   opts.sortBy   "leverage" (default), "width", "ratio", or "none".
%
%   Example:
%       T = getRatioIntervals(RES);
%       figure; hold on
%       xline(1,'k--');
%       for i = 1:height(T)
%           plot([T.lo(i) T.hi(i)], [T.y(i) T.y(i)], '-', 'LineWidth',3);
%       end
%       set(gca,'XScale','log','YTick',T.y,'YTickLabel',T.pair);
%       xlabel('w_a / w_b over the best-scoring vectors');

arguments
    RES struct
    opts.source       = "S"
    opts.minNecessity = 1
    opts.minLeverage  = 0
    opts.sortBy       = "leverage"
    opts.verbose      = true
end

%% ------------------------------------------------------- pick the rows
switch upper(string(opts.source))
    case "S"
        if ~isfield(RES,'S') || isempty(RES.S)
            error('getRatioIntervals:noS','RES.S is empty');
        end
        E = RES.S;
    case "P"
        if ~isfield(RES,'P') || isempty(RES.P)
            error('getRatioIntervals:noP','RES.P is empty');
        end
        E = RES.P(RES.P.necessity >= opts.minNecessity & ...
                  RES.P.leverage  >= opts.minLeverage, :);
    otherwise
        error('getRatioIntervals:badSource','source must be "S" or "P"');
end

if isempty(E)
    error('getRatioIntervals:noRows','no pair met the thresholds');
end

%% ------------------------------------- what the sampling box could reach
% Each free term was sampled over center*[r1 r2]; a fixed or held term sits
% at a single value. So the ratio a/b is confined to
%   (center_a/center_b) * [r1/r2, r2/r1]   with the span collapsing to a
% point for any term that was not sampled.
o = RES.opts;
w0 = RES.w0;
fixedTerm = string(o.fixedTerm);
scale = w0.(fixedTerm);
heldTerms = string(fieldnames(o.hold));

    function [c,span] = termBox(t)
        % centre of the term, and the multiplicative span it was sampled over
        if t == fixedTerm
            c = 1;  span = [1 1];
        elseif ismember(t, heldTerms)
            c = o.hold.(t);  span = [1 1];
        else
            c = w0.(t)/scale;
            span = [min(o.range) max(o.range)];
            if c == 0                   % sampled absolutely, not scaled
                c = 1;
            end
        end
    end

n = height(E);
lo = E.minRatio(:);
hi = E.maxRatio(:);
boxLo = nan(n,1); boxHi = nan(n,1);

for i = 1:n
    [ca,sa] = termBox(E.termA(i));
    [cb,sb] = termBox(E.termB(i));
    if cb == 0 || ca == 0
        continue                        % ratio undefined; leave as NaN
    end
    boxLo(i) = (ca/cb) * (sa(1)/sb(2));
    boxHi(i) = (ca/cb) * (sa(2)/sb(1));
end

tolLog  = 0.02;                          % within ~5% of the limit
truncLo = isfinite(lo) & isfinite(boxLo) & abs(log(lo./boxLo)) < tolLog;
truncHi = isfinite(hi) & isfinite(boxHi) & abs(log(hi./boxHi)) < tolLog;

%% ---------------------------------------------------------- assemble
T = table();
T.pair      = E.termA + " > " + E.termB;
T.from      = E.termA;
T.to        = E.termB;
T.lo        = lo;
T.hi        = hi;
T.logLo     = log10(lo);
T.logHi     = log10(hi);
T.widthDecades = log10(hi./lo);
T.leverage  = E.leverage;
T.necessity = E.necessity;
T.boxLo     = boxLo;
T.boxHi     = boxHi;
T.truncLo   = truncLo;
T.truncHi   = truncHi;
T.crossesOne = lo < 1 & hi > 1;

switch lower(string(opts.sortBy))
    case "leverage", T = sortrows(T,'leverage','ascend');   % strongest on top
    case "width",    T = sortrows(T,'widthDecades','ascend');
    case "ratio",    T = sortrows(T,'lo','ascend');
    case "none"      % leave as is
    otherwise
        error('getRatioIntervals:badSort','sortBy must be leverage, width, ratio, or none');
end

T.y = (1:height(T))';                    % bottom to top

%% ------------------------------------------------------------ report
if opts.verbose
    fprintf('%d constraint(s)\n', height(T));
    for i = height(T):-1:1
        mark = "";
        if T.truncLo(i) || T.truncHi(i), mark = "   [truncated by the box]"; end
        fprintf('  %-30s %8.3g to %-8.3g  (%.2f decades, leverage %+.3f)%s\n', ...
            T.pair(i), T.lo(i), T.hi(i), T.widthDecades(i), T.leverage(i), mark);
    end

    nTrunc = nnz(T.truncLo | T.truncHi);
    if nTrunc > 0
        fprintf(['\n%d bar(s) touch the sampling limit -- those ends are lower ' ...
                 'bounds on\nthe true slack. Widen opts.range and re-sweep to ' ...
                 'measure them.\n'], nTrunc);
    end
    if any(T.crossesOne)
        fprintf('%d interval(s) span 1: the ordering flips within the best set\n', ...
            nnz(T.crossesOne));
    end
end
end