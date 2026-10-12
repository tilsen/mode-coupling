function [h,th] = drawBrace(pos,opts)
% drawBrace  Draw a curly brace in the box pos = [x y width height].
%   h = drawBrace(pos,direction="down") draws it with its tip pointing in the
%   given direction ("right" (default), "up", "left", "down").
%   [h,th] = drawBrace(pos,label="text") also places a text label, centered
%   on the brace: labelPos="inside" (default) rests it on the brace's middle
%   section in the pocket between the arms (the side opposite the tip),
%   "tip" puts it just beyond the tip.
arguments
    pos
    opts.direction = "right"
    opts.parent = []
    opts.curvature = 8*pi
    opts.color = [ 0 0 0]
    opts.lineWidth = 2
    opts.tipPos (1,1) double = 0.5      % position of the tip along the brace's span (0-1)
    opts.label = ""
    opts.labelPos (1,1) string {mustBeMember(opts.labelPos,["inside","tip"])} = "inside"
    opts.labelFontSize = 14
    opts.labelProps cell = {}
end
if isempty(opts.parent)
    opts.parent = gca;
end
% Create brace using sinh functions
n = 100;
t1 = linspace(-opts.curvature, opts.curvature, n);
x1 = sinh(t1);
x = [x1 fliplr(x1)];
t = linspace(-1,1,numel(x));
% displace the tip along the span (default: centered); the two halves of the
% brace are stretched/compressed to meet at the new tip position
% (tipPos runs along the box's own x or y axis, left-to-right / bottom-to-top,
% whichever way the brace points)
p = min(max(opts.tipPos,0.02),0.98);
if any(lower(string(opts.direction))==["left" "up"]), p = 1-p; end
t = (t<0).*(-1+(t+1)*2*p) + (t>=0).*((2*p-1)+t*(2-2*p));
x = x - min(x);
x = x/max(x);
x = 2*(x-(1/2));

% rotate based on direction using rotation matrix
switch lower(opts.direction)
    case "right"
        theta = 0;
    case "up"
        theta = pi/2;
    case "left"
        theta = pi;
    case "down"
        theta = -pi/2;
end

% Apply rotation matrix
R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
coords = R * [x; t];
xr = coords(1,:);
yr = coords(2,:);

% Scale and translate based upon position
xp = pos(1) + pos(3)/2 + xr * pos(3)/2;
yp = pos(2) + pos(4)/2 + yr * pos(4)/2;

% Draw the brace
h = line(xp, yp, 'Parent', opts.parent, 'Color', opts.color, 'LineWidth', opts.lineWidth);

th = gobjects(0);
if strlength(opts.label)>0
    ctr = pos(1:2) + pos(3:4)/2;
    tipDir = (R*[1;0])';                       % unit vector from center toward the tip
    half = pos(3:4)/2;
    switch opts.labelPos
        case "inside"
            % resting on the brace's middle section, in the pocket between
            % the arms (opposite side from the tip), centered along the brace
            xy = ctr - tipDir.*0.04.*pos(3:4);
            hal = 'center'; val = 'middle';
            if tipDir(2)<-0.5, val = 'bottom'; elseif tipDir(2)>0.5, val = 'top'; end
            if tipDir(1)>0.5, hal = 'right'; elseif tipDir(1)<-0.5, hal = 'left'; end
        case "tip"
            xy = ctr + tipDir.*half;
            hal = 'center'; val = 'middle';
            if tipDir(2)<-0.5, val = 'top'; elseif tipDir(2)>0.5, val = 'bottom'; end
            if tipDir(1)>0.5, hal = 'left'; elseif tipDir(1)<-0.5, hal = 'right'; end
    end
    th = text(opts.parent,xy(1),xy(2),opts.label,'HorizontalAlignment',hal, ...
        'VerticalAlignment',val,'FontSize',opts.labelFontSize,'Color',opts.color, ...
        opts.labelProps{:});
end
end