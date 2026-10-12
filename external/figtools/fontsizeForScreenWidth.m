function fs = fontsizeForScreenWidth(varargin)
%FONTSIZEFORSCREENWIDTH  Font size to fit text into a screen fraction
%
%   fs = fontsizeForScreenWidth(text, frac)
%   fs = fontsizeForScreenWidth(nChars, frac)
%   fs = fontsizeForScreenWidth(..., Name, Value)
%
% Inputs
%   text    : character vector or string scalar
%   nChars  : number of characters (integer)
%   frac    : fraction of screen width to occupy (0–1)
%
% Name–Value options
%   'ScreenWidthPx' : screen width in pixels (default: primary screen)
%   'CharAspect'   : character width / font size (default: 0.6)
%   'DPI'          : screen DPI (default: 96)
%
% Output
%   fs : font size in points

    % ---- Parse positional inputs ----
    if nargin < 2
        error('Need at least two inputs: text/nChars and frac.');
    end

    first = varargin{1};
    frac  = varargin{2};

    if ischar(first) || isstring(first)
        nChars = strlength(string(first));
    elseif isnumeric(first) && isscalar(first)
        nChars = first;
    else
        error('First input must be text or number of characters.');
    end

    % ---- Defaults ----
    p = inputParser;
    addParameter(p, 'ScreenWidthPx', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'CharAspect', 0.6, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'DPI', 96, @(x) isnumeric(x) && isscalar(x));
    parse(p, varargin{3:end});

    charAspect = p.Results.CharAspect;
    dpi        = p.Results.DPI;

    % ---- Determine screen width ----
    if isempty(p.Results.ScreenWidthPx)
        mp = get(0,'MonitorPositions');
        screenWidthPx = mp(1,3);   % primary monitor width
    else
        screenWidthPx = p.Results.ScreenWidthPx;
    end

    % ---- Geometry ----
    targetWidthPx = frac * screenWidthPx;

    % px per point
    pxPerPoint = dpi / 72;

    % text width ≈ nChars * charAspect * fontSize * pxPerPoint
    fs = targetWidthPx / (nChars * charAspect * pxPerPoint);
end
