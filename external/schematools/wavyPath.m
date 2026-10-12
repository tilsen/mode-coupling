function [XY] = wavyPath(endpoints,ampfac,opts)
% wavyPath  Points of a wavy line between two endpoints.
%   XY = wavyPath([x0 y0; x1 y1],ampfac) returns an N-by-2 polyline that
%   oscillates about the straight line from the first endpoint to the
%   second. ampfac is the wave amplitude as a proportion of the line's length.
%
%   Options: freq (cycles along the line, default 4), phase (radians, default
%   0: a cosine, which starts and ends at +amplitude; phase=-pi/2 gives a sine,
%   which starts and ends exactly on the endpoints when freq is an integer or
%   half-integer), nPoints (default 100), taper (fraction of the length over
%   which the wave fades out at the end, default 0: none), tail (fraction of
%   the length at the very end that is exactly straight, default 0).
%
%   draw_wavy_line applies this to an existing line object; use the path
%   directly to build a wavy arrow, e.g. stArrow(wavyPath(P,0.05,phase=-pi/2)).
arguments
    endpoints (2,2) double
    ampfac = 0.1
    opts.freq = 4
    opts.phase = 0
    opts.nPoints = 100
    opts.taper = 0         % fraction of the length over which the amplitude fades to zero at the end
    opts.tail = 0          % fraction of the length at the very end that is exactly straight (amplitude zero)
end

xdo = endpoints(:,1)';
ydo = endpoints(:,2)';

amp = ampfac*sqrt(diff(xdo).^2+diff(ydo).^2);

% translate the line to the origin
xd = xdo-xdo(1);
yd = ydo-ydo(1);

% rotate the line to horizontal
th = angle(xd(2) + 1i * yd(2));

PP = [xd' yd']*[cos(th) -sin(th); sin(th) cos(th)];

nxd = linspace(PP(1,1),PP(2,1),opts.nPoints)';

ths = linspace(0,1,numel(nxd))';
nyd = amp*cos(opts.freq*2*pi*ths + opts.phase);
if opts.taper>0 || opts.tail>0
    % fade the wave out at the end so the line arrives straight along its axis
    % (an arrowhead drawn at the end then points along the axis)
    nyd = nyd.*min(1,max(0,(1-ths-opts.tail)/max(opts.taper,eps)));
end

% restore the original orientation
oPP = [nxd nyd]*[cos(-th) -sin(-th); sin(-th) cos(-th)];
XY = oPP + [xdo(1) ydo(1)];

end
