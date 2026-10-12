function [h] = stArrow(XY,opts)
arguments
    XY
    opts.FitSpline = false
    opts.nInterp = 1000
    opts.FaceColor = []
    opts.FaceAlpha = 1
    opts.EdgeColor = []
    opts.LineWidth = 1
    opts.Color = [0 0 0]
    opts.BaseLength = 12 % base of triangle in pixels
    opts.Anchor = 'tip'
    opts.TipGap = 0     % stop the arrow this many pixels short of its end point
    opts.Parent = []
end

if ishandle(XY)
    opts.Parent = XY.Parent;
    XY = [XY.XData(:) XY.YData(:)];
elseif isempty(opts.Parent)
    opts.Parent = gca;
end

if isempty(opts.FaceColor), opts.FaceColor = opts.Color; end
if isempty(opts.EdgeColor), opts.EdgeColor = opts.Color; end

if size(XY,2)~=2
    XY = XY';
end

if opts.FitSpline
    fo = cscvn(XY');
    arc = fnplt(fo);
    for i=1:2
        arci(i,:) = interp1(arc(i,:),linspace(1,size(arc,2),opts.nInterp));
    end
    XY = arci';
end

if opts.TipGap>0
    % pull the end point back along the last segment (measured in pixels)
    pp = dataToPixels(opts.Parent,XY(end-1:end,:));
    d = pp(2,:)-pp(1,:);
    pp(2,:) = pp(2,:)-opts.TipGap*d/norm(d);
    XY(end,:) = pixelsToData(opts.Parent,pp(2,:));
end

headXY = getHeadCoords(XY,opts);
h(1) = plot(XY(:,1),XY(:,2),'Color',opts.Color,'LineWidth',opts.LineWidth,Parent=opts.Parent); hold(opts.Parent,'on');
h(2) = fill(headXY(:,1),headXY(:,2),opts.FaceColor,'EdgeColor',opts.EdgeColor,'FaceAlpha',opts.FaceAlpha,Parent=opts.Parent);


end

%coordinates of head patch
function [headXY] = getHeadCoords(XY,opts)
POS = XY(end-1:end, :);
anchor_data = POS(end, :);

% Get axis handle and tip position in pixels
ax = opts.Parent;

% direction of the line as it appears on screen: the angle is taken in pixel
% space (data units can be scaled differently in x and y, which would skew
% the head off the line's axis)
posPix = dataToPixels(ax,POS);
angle_rad = angleFromPoints(posPix(end-1, :), posPix(end, :));

switch(opts.Anchor)
    case 'tip'
        % Build an equilateral triangle in pixel space (tip at origin,
        % pointing right
        L = opts.BaseLength;          % base width in pixels
        H = sqrt(3)/2 * L;            % height of equilateral triangle
        triangle_pix = [...
            0   ,  0;                % tip
            -H/2 , -L;               % base top
            H/2 , -L];             % base bottom
        
        angle_rad = angle_rad - pi/2;
        R = [cos(angle_rad), -sin(angle_rad); sin(angle_rad), cos(angle_rad)];

    case 'base'
        L = opts.BaseLength;          % base width in pixels
        H = sqrt(3)/2 * L;            % height of equilateral triangle
        triangle_pix = [...
            L, 0;                % tip
            0, -H/2;                % base top
            0, H/2];               % base bottom
        
        angle_rad = angle_rad;
        R = [cos(angle_rad), -sin(angle_rad); sin(angle_rad), cos(angle_rad)];

end

% Rotate triangle to match line angle
triangle_pix_rot = (R * triangle_pix')';


% Convert triangle vertices back to data space
headXY = pixelsToData(ax, triangle_pix_rot);

switch(opts.Anchor)
    case 'tip'
        % Translate triangle to tip location (in pixels)
        headXY = headXY-headXY(1,:)+POS(end,:);
    case 'base'
        headXY = headXY-mean(headXY(2:3,:))+POS(end,:);
end



end

% --- Helper Functions ---

function angle = angleFromPoints(p1, p2)
% Returns angle (in radians) from p1 to p2
angle = atan2(p2(2) - p1(2), p2(1) - p1(1));
end

function pix = dataToPixels(ax, data)
origUnits = ax.Units;
% Converts data coordinates to pixel coordinates
ax.Units = 'pixels';
ax_pos = ax.Position;
xl = ax.XLim;
yl = ax.YLim;

% Normalize data within axes limits
xn = (data(:,1) - xl(1)) / diff(xl);
yn = (data(:,2) - yl(1)) / diff(yl);

% Scale to pixel position
xp = ax_pos(1) + xn * ax_pos(3);
yp = ax_pos(2) + yn * ax_pos(4);

pix = [xp, yp];

ax.Units = origUnits;
end

function data = pixelsToData(ax, pix)
origUnits = ax.Units;
% Converts pixel coordinates to data coordinates
ax.Units = 'pixels';
ax_pos = ax.Position;
xl = ax.XLim;
yl = ax.YLim;

% Normalize pixel positions within axis box
xn = (pix(:,1) - ax_pos(1)) / ax_pos(3);
yn = (pix(:,2) - ax_pos(2)) / ax_pos(4);

% Convert to data space
xd = xl(1) + xn * diff(xl);
yd = yl(1) + yn * diff(yl);

data = [xd, yd];
ax.Units = origUnits;
end