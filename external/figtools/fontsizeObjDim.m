function fs = fontsizeObjDim(nChar, frac, dims, opts)
arguments
    nChar
    frac
    dims = "x"                  % "x", "y", or "xy"
    opts.parent = []            % graphics handle to measure against; defaults to gcf for
                                 % text/number input, or to the handles' own common parent
                                 % (e.g. their axes) when nChar is graphics text handle(s)
    opts.charAspect = 0.6       % fallback only (used when nChar is a bare number, not text
                                 % or handles): avg char width ≈ charAspect * fontSize (points)
    opts.charHeightAspect = 1.0 % fallback only: avg char height ≈ charHeightAspect * fontSize
    opts.maxFontSize = Inf      % clamp: useful when a short string in a wide/tall parent would otherwise blow up
    opts.minFontSize = 1        % clamp: useful when a long string in a narrow/short parent would otherwise vanish
    opts.FontName = 'default'   % trial-text mode only: match the font the caller will actually apply
    opts.FontWeight = 'normal'  % trial-text mode only: match the weight the caller will actually apply
    opts.FontAngle = 'normal'   % trial-text mode only
    opts.Interpreter = 'tex'    % trial-text mode only
    opts.maxIter = 6            % handle/trial-text modes: iterations of resize-and-remeasure
    opts.tol = 0.05             % handle/trial-text modes: stop once FontSize changes less than this (points)
end

% --- What kind of input is nChar? ---
isHandles = ~isempty(nChar) && all(isgraphics(nChar(:))) && all(isprop(nChar(:),'Extent'));

if isHandles
    t = nChar(:);
    if isempty(opts.parent)
        parents = unique([t.Parent]);
        if ~isscalar(parents)
            error('fontsizeObjDim:ambiguousParent', ...
                'Text handles have different parents; pass opts.parent explicitly.');
        end
        opts.parent = parents;
    end
else
    isText = ~isnumeric(nChar);
    if isText
        strs = string(nChar);
        strs = strs(strlength(strs) > 0);
        isText = ~isempty(strs);
    end
    if isempty(opts.parent)
        opts.parent = gcf;
    end
end

p = opts.parent;
if ~isgraphics(p)
    error('opts.parent must be a valid graphics handle (or leave empty for gcf).');
end

% --- Get parent size directly in points ---
% Font size is already in points, so measuring the parent in points too
% avoids converting through pixels + get(0,'ScreenPixelsPerInch') — that
% conversion is a known source of error on displays with OS-level scaling
% (125%/150%/etc, common on Windows), where the two don't always agree and
% every computed font size ends up skewed by the mismatch.
oldUnits = get(p,'Units');
try
    set(p,'Units','points');
    posPt = get(p,'Position');
catch
    % Fallback for object types that don't support 'points' units
    set(p,'Units','pixels');
    posPx = get(p,'Position');
    dpi = get(0,'ScreenPixelsPerInch');
    posPt = posPx * 72/dpi;
end
set(p,'Units',oldUnits);

objWidthPt  = posPt(3);
objHeightPt = posPt(4);

% --- Parse dims and frac ---
dims = lower(string(dims));

if isscalar(frac)
    fracX = frac;
    fracY = frac;
else
    fracX = frac(1);
    fracY = frac(2);
end

useX = contains(dims,"x");
useY = contains(dims,"y");

if ~useX && ~useY
    error('dims must contain "x", "y", or "xy".');
end

if isHandles || (~isHandles && isText)
    % --- Handle or trial-text mode: iteratively resize throwaway trial
    % text (cloned from the real handles, or built fresh from a string)
    % until it actually measures up to the target fraction of the parent,
    % rather than estimating from a fixed per-character heuristic. This is
    % exact for whatever font, weight, and interpreter is really in play,
    % and self-corrects for any non-linearity in how MATLAB renders text
    % at different sizes.
    %
    % Fitting always happens on trial text in a private, invisible scratch
    % figure, never on the real (possibly already-visible) handles. The
    % iteration needs several drawnow calls to remeasure Extent at each
    % candidate size; calling drawnow while mutating a handle that lives in
    % the figure a Live Script is displaying as output is what makes the
    % script record a scrubbable "playback" of every intermediate font
    % size. A scratch figure is never shown as output, so it never gets
    % captured that way.
    persistent scratchAx
    if isempty(scratchAx) || ~isvalid(scratchAx)
        scratchFig = figure('Visible','off','HandleVisibility','off', ...
            'IntegerHandle','off','Tag','fontsizeObjDim_scratch');
        scratchAx = axes(scratchFig,'Visible','off','Units','points');
    else
        delete(get(scratchAx,'Children'));
    end

    if isHandles
        nT = numel(t);
        trial = gobjects(nT,1);
        for i = 1:nT
            % Position must be a real (non-NaN) point -- Extent doesn't
            % resolve for text MATLAB can't lay out at a defined location.
            trial(i) = text(scratchAx,0,0,t(i).String,'Units','points', ...
                'FontName',t(i).FontName,'FontWeight',t(i).FontWeight, ...
                'FontAngle',t(i).FontAngle,'Interpreter',t(i).Interpreter);
        end
    else
        fontNameArgs = {};
        if ~strcmp(opts.FontName,'default')
            fontNameArgs = {'FontName',opts.FontName};
        end
        trial = gobjects(numel(strs),1);
        for i = 1:numel(strs)
            trial(i) = text(scratchAx,0,0,strs(i),'Units','points', ...
                fontNameArgs{:},'FontWeight',opts.FontWeight, ...
                'FontAngle',opts.FontAngle,'Interpreter',opts.Interpreter);
        end
    end

    fs = 12; % starting guess; converges to the right answer regardless
    set(trial,'FontSize',fs);
    for iter = 1:opts.maxIter %#ok<NASGU>
        drawnow;
        ext = cell2mat(get(trial,{'Extent'}));
        ratios = [];
        if useX
            measuredW = max(ext(:,3));
            if measuredW>0, ratios(end+1) = (fracX*objWidthPt)/measuredW; end %#ok<AGROW>
        end
        if useY
            measuredH = max(ext(:,4));
            if measuredH>0, ratios(end+1) = (fracY*objHeightPt)/measuredH; end %#ok<AGROW>
        end
        if isempty(ratios), break; end
        newFs = min(max(fs*min(ratios), opts.minFontSize), opts.maxFontSize);
        converged = abs(newFs-fs) < opts.tol;
        fs = newFs;
        set(trial,'FontSize',fs);
        if converged, break; end
    end

    if isHandles
        set(t,'FontSize',fs);
    end
else
    % --- Bare-number fallback: no real text to measure, so estimate from
    % the charAspect/charHeightAspect heuristic ---
    nChar = max(double(nChar),1);
    widthPerPt  = nChar*opts.charAspect;
    heightPerPt = opts.charHeightAspect;

    fsCandidates = [];
    if useX
        fsCandidates(end+1) = (fracX*objWidthPt) / widthPerPt; %#ok<AGROW>
    end
    if useY
        fsCandidates(end+1) = (fracY*objHeightPt) / heightPerPt; %#ok<AGROW>
    end
    fs = min(fsCandidates);
    if ~isfinite(fs) || fs <= 0
        fs = NaN;
    else
        fs = min(max(fs, opts.minFontSize), opts.maxFontSize);
    end
end

end
