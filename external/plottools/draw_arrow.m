function arh = draw_arrow(lh, opts)
% DRAW_ARROW Draws an equilateral triangle arrowhead at the end of a line.
%
%   arh = draw_arrow(lh, opts)
%
%   Inputs:
%     lh             - A line handle (must have XData and YData)
%     opts.EdgeColor - Color of the triangle edge (default: [0 0 0])
%     opts.FaceColor - Fill color of the triangle (default: [0 0 0])
%     opts.BaseLength - Base width of the triangle in screen pixels (default: 12)
%
%   Output:
%     arh - Patch handle for the drawn arrowhead

arguments
    lh
    opts.EdgeColor = [0 0 0]
    opts.FaceColor = [0 0 0]
    opts.BaseLength = 12 % base of triangle in pixels
    opts.Anchor = 'tip'
    opts.Rotate = 0
end

% Get the last segment to determine the direction of the arrow
XY = [lh.XData(:) lh.YData(:)];
XY = [linspace(XY(end-1,1), XY(end,1), 100)', linspace(XY(end-1,2), XY(end,2), 100)'];
POS = XY(end-1:end, :);
anchor_data = POS(end, :);
angle_rad = angleFromPoints(POS(end-1, :), anchor_data);

% Get axis handle and tip position in pixels
ax = lh.Parent;

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
        
        angle_rad = -angle_rad - pi/2 + opts.Rotate;
        R = [cos(angle_rad), -sin(angle_rad); sin(angle_rad), cos(angle_rad)];

    case 'base'
        L = opts.BaseLength;          % base width in pixels
        H = sqrt(3)/2 * L;            % height of equilateral triangle
        triangle_pix = [...
            L, 0;                % tip
            0, -H/2;                % base top
            0, H/2];               % base bottom
        
        angle_rad = angle_rad + opts.Rotate;
        R = [cos(angle_rad), -sin(angle_rad); sin(angle_rad), cos(angle_rad)];

end

% Rotate triangle to match line angle
triangle_pix_rot = (R * triangle_pix')';


% Convert triangle vertices back to data space
triangle_data = pixelsToData(ax, triangle_pix_rot);

switch(opts.Anchor)
    case 'tip'
        % Translate triangle to tip location (in pixels)
        triangle_data = triangle_data-triangle_data(1,:)+POS(end,:);
    case 'base'
        triangle_data = triangle_data-mean(triangle_data(2:3,:))+POS(end,:);
end

% Draw the triangle as a filled patch
arh = fill(triangle_data(:,1), triangle_data(:,2), opts.FaceColor, ...
    'EdgeColor', opts.EdgeColor,'parent',ax);

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
