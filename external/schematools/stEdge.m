classdef stEdge

    properties
        Source
        Target
        Id = ""
        Label = ""
        EdgeSpec = ""
        Direction = "forward"
        CapStyles = ["arrow" "arrow"]
        Anchors = [] %overrides node anchors
        Angle
        ArrowLength = 8
        LineWidth = 1
        NumLines = 1        
        Color = [0 0 0]
        LineStyle = "-"
        LabelLoc = 0.5        
        LabelPos = ""
        LabelFontSize = 16;
        LabelRotation = 0
        FontAngle = "normal";
        Interpreter = "tex"
        CurveArc = nan        
        Visible = "on"
        LabelVisible = "on"
        FaceColor = [0 0 0]
        EdgeColor = [0 0 0]
        FaceAlpha = 1
        SourceXY = [nan nan]
        TargetXY = [nan nan]        
        LineHandle
        CapHandles
        LabelHandle        
    end

    methods
        function obj = stEdge(E)
            obj = obj.setProps(E);
            obj.LineHandle = gobjects(0);
            obj.CapHandles = gobjects(0);
            obj.LabelHandle = gobjects(0);
        end

        function [obj] = setProp(obj,prop,val)
            obj.(prop) = val;
        end

        function obj = setProps(obj,E)
            props = E.Properties.VariableNames;
            metaObj = metaclass(obj);
            classProps = {metaObj.PropertyList.Name};
            fig = figure('Visible','off');
            for i=1:length(props)
                if ismember(props(i),classProps)
                    switch(class(E.(props{i})))
                        case 'string'
                            if ~all(ismissing(E.(props{i})))
                                obj.(props{i}) = obj.validateProp(props{i},E.(props{i}));
                            end
                        case {'double' 'single'}
                            if ~all(isnan(E.(props{i})))
                                obj.(props{i}) = obj.validateProp(props{i},E.(props{i}));
                            end
                        otherwise
                            obj.(props{i}) = obj.validateProp(props{i},E.(props{i}));
                    end
                end
            end
            delete(fig);
            obj = obj.setProp('Angle',obj.getAngle());
        end

        function value = validateProp(obj,propName,value)
            mc = ?matlab.graphics.chart.primitive.Line;
            props = mc.PropertyList;
            if ismember(propName,{props.Name})
                h = plot(nan,nan,'Parent',gca);
                allowedValues = set(h,propName);
                if ~isempty(allowedValues) && ~ismember(value,allowedValues)
                    %metaObj = metaclass(obj);
                    %classProps = {metaObj.PropertyList.Name};
                    value = obj.(propName);
                end                
                delete(h);
            end
        end

        function obj = update(obj,E)
            obj = obj.setProps(E);
            obj = obj.draw();
        end

        function [obj] = draw(obj,opts)

            arguments
                obj
                opts.parent = [];
                opts.numCurvePoints = 500
            end

            if isempty(opts.parent)
                opts.parent = gca;
            end

            POS = [obj.SourceXY; obj.TargetXY];
            obj.Angle = obj.angleFromPoints(POS(1,:),POS(2,:));

            if ~any(isnan(obj.CurveArc)) && obj.Direction~="both"
                if numel(obj.CurveArc)==2
                    [x,y] = obj.arcThrough3Points(POS(1,:),obj.CurveArc,POS(2,:),opts.numCurvePoints);
                    POS = [x;y]';
                else
                    POS = obj.arcPoints(POS(1,:), POS(2,:), obj.CurveArc, opts.numCurvePoints);
                end
            end

            switch(obj.Direction)
                case "none"
                    caps = {};
                    obj.CapHandles = gobjects(0);  

                case "both"
                    basewidth = obj.pixelsToAxesUnits(obj.ArrowLength,gca);                    
                    angle = obj.angleFromPoints(POS(end-1,:),POS(end,:));
                    [headx1,heady1] = obj.equilateralTriangleFromTip(basewidth,POS(end,:),angle-pi/2);
                    basemidpoint1 = [mean(headx1([2 3])) mean(heady1([2 3]))];
                    POS(end,:) = basemidpoint1;

                    angle = obj.angleFromPoints(POS(2,:),POS(1,:));
                    [headx2,heady2] = obj.equilateralTriangleFromTip(basewidth,POS(1,:),angle-pi/2);
                    basemidpoint2 = [mean(headx2([2 3])) mean(heady2([2 3]))];
                    POS(1,:) = basemidpoint2;
                    caps = {[headx1' heady1'],[headx2' heady2']};
                    obj.CapHandles = gobjects(2);  

                case "forward"
                    basewidth = obj.pixelsToAxesUnits(obj.ArrowLength,gca);                    
                    angle = obj.angleFromPoints(POS(end-1,:),POS(end,:));
                    [headx,heady] = obj.equilateralTriangleFromTip(basewidth,POS(end,:),angle-pi/2);

                    basemidpoint = [mean(headx([2 3])) mean(heady([2 3]))];
                    POS(end,:) = basemidpoint;
                    caps = {[headx' heady']};
                    obj.CapHandles = gobjects(1);  

                case "backward"
                    basewidth = obj.pixelsToAxesUnits(obj.ArrowLength,gca);                    
                    angle = obj.angleFromPoints(POS(1,:),POS(2,:))+pi;
                    [headx,heady] = obj.equilateralTriangleFromTip(basewidth,POS(1,:),angle-pi/2);

                    basemidpoint = [mean(headx([2 3])) mean(heady([2 3]))];
                    POS(1,:) = basemidpoint;
                    caps = {[headx' heady']};
                    obj.CapHandles = gobjects(1);                     

            end

            if obj.NumLines>1
                switch(mod(obj.NumLines,2))
                    case 0
                        al = textAlignment(rad2deg(obj.Angle-pi/2));
                        offsets = obj.pixelsToAxesUnits(3*obj.LineWidth,gca).*[al.xoffset al.yoffset];
                        POS = [POS-offsets;  nan nan; POS+offsets];
                    case 1

                end
            end

            if isempty(obj.LineHandle) || ~isgraphics(obj.LineHandle)
                obj.LineHandle = plot(POS(:,1),POS(:,2));
            end
            props = {'LineStyle','LineWidth','Color'};
            for i=1:length(props)
                obj.LineHandle.(props{i}) = obj.(props{i});
            end
                      
            props = {'EdgeColor','FaceAlpha','FaceColor'};
            for i=1:length(caps)
                if ~isgraphics(obj.CapHandles(i))
                    obj.CapHandles(i) = fill(caps{i}(:,1),caps{i}(:,2),obj.FaceColor);
                end
                for j=1:length(props)
                    obj.CapHandles(i).(props{j}) = obj.(props{j});
                end
            end

            if obj.Label~=""
                obj = obj.drawLabel();
            end

        end

        function obj = uniformColor(obj)
            obj.FaceColor = obj.Color;
            obj.EdgeColor = obj.Color;
        end

        function obj = drawLabel(obj)
            xx = obj.LineHandle.XData;
            yy = obj.LineHandle.YData;
            if numel(xx)==2
                xx = linspace(xx(1),xx(end),1000);
                yy = linspace(yy(1),yy(end),1000);
            end
            ix = round(obj.LabelLoc*numel(xx));
            x = xx(ix);
            y = yy(ix);

            PP = [xx(ix-1:ix); yy(ix-1:ix)];
            angle = obj.angleFromPoints(PP(:,1),PP(:,2));

            if obj.LabelPos==""                
                alignment = textAlignment(rad2deg(angle-pi/2));
                xoffset = alignment.xoffset*obj.pixelsToAxesUnits(10,obj.LineHandle.Parent,'x');
                yoffset = alignment.yoffset*obj.pixelsToAxesUnits(10,obj.LineHandle.Parent,'y');

            else                
                alignment = stTextAlign([x y],obj.LabelPos);
                warning('off','MATLAB:structOnObject');
                alignment = struct(alignment);
                alignment.horizontal = alignment.HorizontalAlignment;
                alignment.vertical = alignment.VerticalAlignment;

                %al = textAlignment(rad2deg(angle-pi/2));
                xoffset = 0; %-al.xoffset*obj.pixelsToAxesUnits(10,obj.LineHandle.Parent,'x');
                yoffset = 0; % -al.yoffset*obj.pixelsToAxesUnits(10,obj.LineHandle.Parent,'y');
            end

            if ~isnumeric(obj.LabelRotation)
                switch(obj.LabelRotation)
                    case "match"
                        obj.LabelRotation = rad2deg(angle);
                        if obj.LabelRotation < -90
                            obj.LabelRotation = obj.LabelRotation+180;
                        elseif obj.LabelRotation > 90
                            obj.LabelRotation = obj.LabelRotation-180;                            
                        end
                    otherwise

                end
            end
            
            obj.LabelHandle = text(x+xoffset,y+yoffset,strsplit(char(obj.Label),'\\n'),...
                'FontSize',obj.LabelFontSize,...
                'FontAngle',obj.FontAngle,...
                'HorizontalAlignment',alignment.horizontal,...
                'VerticalAlignment',alignment.vertical,...
                'Rotation',obj.LabelRotation,...
                'Interpreter',obj.Interpreter);
        end

        function [angle] = getAngle(obj)
            %angle = atan2(obj.TargetXY(2)-obj.SourceXY(2),obj.TargetXY(1)-obj.SourceXY(1));
            angle = obj.angleFromPoints(obj.SourceXY,obj.TargetXY);
        end

        function [obj] = shorten(obj,beginp,endp)
            XY = [obj.SourceXY; obj.TargetXY];
            dx = diff(XY(:,1));
            dy = diff(XY(:,2));
            if beginp~=0
                XY(1,1) = XY(1,1) + beginp*dx;
                XY(1,2) = XY(1,2) + beginp*dy;
            end
            if endp~=0
                XY(2,1) = XY(2,1) - endp*dx;
                XY(2,2) = XY(2,2) - endp*dy;
            end
            obj.SourceXY = XY(1,:);
            obj.TargetXY = XY(2,:);
            obj.LineHandle.XData = XY(:,1)';
            obj.LineHandle.YData = XY(:,2)';
            obj.CapHandles.XData = obj.CapHandles.XData - endp*dx;
            obj.CapHandles.YData = obj.CapHandles.YData - endp*dy;
        end
    end

    methods (Static)

        function [angle] = angleFromPoints(p1,p2)
            angle = atan2(p2(2)-p1(2),p2(1)-p1(1));
        end

        function [arcX, arcY] = arcThrough3Points(P1, P2, P3, numPoints)
            % arcThrough3Points - Generates arc points through 3 points on a circle
            %
            % Syntax:
            % [arcX, arcY] = arcThrough3Points(P1, P2, P3, numPoints)
            %
            % Inputs:
            % P1, P2, P3 : [x, y] coordinates of 3 points
            % numPoints  : Number of points to generate along the arc
            %
            % Outputs:
            % arcX, arcY : Vectors containing X and Y coordinates of arc points

            if nargin < 4
                numPoints = 100; % Default number of points
            end

            % Extract coordinates
            x1 = P1(1); y1 = P1(2);
            x2 = P2(1); y2 = P2(2);
            x3 = P3(1); y3 = P3(2);

            % Calculate circle center (h, k) and radius r
            A = 2 * (x2 - x1);
            B = 2 * (y2 - y1);
            C = x2^2 + y2^2 - x1^2 - y1^2;
            D = 2 * (x3 - x2);
            E = 2 * (y3 - y2);
            F = x3^2 + y3^2 - x2^2 - y2^2;

            % Solve for circle center
            centerX = (C*E - F*B) / (A*E - B*D);
            centerY = (A*F - D*C) / (A*E - B*D);

            % Radius
            r = sqrt((x1 - centerX)^2 + (y1 - centerY)^2);

            % Angles for each point
            theta1 = atan2(y1 - centerY, x1 - centerX);
            theta2 = atan2(y2 - centerY, x2 - centerX);
            theta3 = atan2(y3 - centerY, x3 - centerX);

            % Ensure angles are in [0, 2*pi]
            theta1 = mod(theta1, 2*pi);
            theta2 = mod(theta2, 2*pi);
            theta3 = mod(theta3, 2*pi);

            % Check direction: determine if we should go clockwise or counterclockwise
            % We'll check if theta2 lies between theta1 and theta3 when going CCW
            if stEdge.isAngleBetween(theta2, theta1, theta3)
                % Counter-clockwise
                if theta1 > theta3
                    theta3 = theta3 + 2*pi;
                end
                theta = linspace(theta1, theta3, numPoints);
            else
                % Clockwise
                if theta3 > theta1
                    theta1 = theta1 + 2*pi;
                end
                theta = linspace(theta1, theta3, numPoints);
            end

            % Arc points
            arcX = centerX + r * cos(theta);
            arcY = centerY + r * sin(theta);
        end

        function units = pixelsToAxesUnits(pixels, ax, dim)
            if nargin==2, dim = 'x'; end

            original_units = ax.Units;
            ax.Units = 'pixels';
            ax_position = ax.Position;
            ax.Units = original_units; % Restore original units

            switch(dim)
                case 'x'
                    lims = ax.XLim;
                     axes_width_pixels = ax_position(3);
                case 'y'
                    lims = ax.YLim;
                     axes_width_pixels = ax_position(4);
            end            
            data_units = diff(lims); % Total width of x-axis in data units           
            units_per_pixel = data_units / axes_width_pixels; % Conversion factor: data units per pixel            
            units = pixels * units_per_pixel;% Convert desired width from pixels to data units
        end

        function [x, y] = equilateralTriangleFromTip(base_length, tip, base_angle)
            % equilateralTriangleFromTip Generates coordinates for an equilateral triangle.
            %
            % [x, y] = equilateralTriangleFromTip(base_length, tip, base_angle)
            %
            % Inputs:
            %   base_length - length of the triangle's base
            %   tip - [x, y] coordinates of the triangle tip (apex)
            %   base_angle - angle of the base (in degrees), measured counterclockwise from x-axis
            %
            % Outputs:
            %   x - x coordinates of the triangle vertices
            %   y - y coordinates of the triangle vertices

            % Half base length
            half_base = base_length / 2;

            % Vertical height from tip to base (property of equilateral triangle)
            height = sqrt(3) / 2 * base_length;

            % Base midpoint (straight down from tip in unrotated triangle)
            base_mid_x = tip(1);
            base_mid_y = tip(2) - height;

            % Base corners (before rotation)
            base_x = [base_mid_x - half_base, base_mid_x + half_base];
            base_y = [base_mid_y, base_mid_y];

            % Full set of vertices (tip first)
            x = [tip(1), base_x];
            y = [tip(2), base_y];

            % Rotate triangle around the tip
            angle_rad = base_angle;
            R = [cos(angle_rad), -sin(angle_rad);
                sin(angle_rad),  cos(angle_rad)];

            % Shift all vertices so tip is at the origin, apply rotation, then shift back
            x_shifted = x - tip(1);
            y_shifted = y - tip(2);

            rotated = R * [x_shifted; y_shifted];

            x = rotated(1, :) + tip(1);
            y = rotated(2, :) + tip(2);
        end

        function [x, y] = equilateralTriangle(base_length, base_center, base_angle)
            % equilateralTriangle Generates coordinates for an equilateral triangle.
            %
            % [x, y] = equilateralTriangle(base_length, base_center, base_angle)
            %
            % Inputs:
            %   base_length - length of the triangle's base
            %   base_center - [x, y] coordinates of the base center
            %   base_angle - angle of the base (in degrees), measured counterclockwise from x-axis
            %
            % Outputs:
            %   x - x coordinates of the triangle vertices
            %   y - y coordinates of the triangle vertices

            % Half the base length
            half_base = base_length / 2;

            % Coordinates of base endpoints (before rotation)
            base_x = [-half_base, half_base];
            base_y = [0, 0]; % Base is initially horizontal

            % Coordinates of top vertex (equilateral triangle property)
            height = sqrt(3) / 2 * base_length;
            top_x = 0;
            top_y = height;

            % Combine all vertices into arrays
            x = [base_x, top_x];
            y = [base_y, top_y];

            % Rotate all vertices by base_angle
            angle_rad = base_angle;
            R = [cos(angle_rad), -sin(angle_rad);
                sin(angle_rad),  cos(angle_rad)];
            coords = R * [x; y];

            % Shift to base center
            x = coords(1, :) + base_center(1);
            y = coords(2, :) + base_center(2);
        end

        function arc = arcPoints(p1, p2, theta, n)

            % arcPoints Returns coordinates of a circular arc between p1 and p2
            %           with given subtended angle theta (radians)
            %
            % Inputs:
            %   p1    : 1x2 start point
            %   p2    : 1x2 end point
            %   theta : subtended angle at the circle center (positive = CCW)
            %   n     : number of points along the arc (default 100)
            %
            % Output:
            %   arc   : n x 2 array of arc points

            if nargin < 4
                n = 100;
            end

            p1 = p1(:);
            p2 = p2(:);

            % Chord vector and length
            chord = p2 - p1;
            L = norm(chord);
            if L == 0
                error('p1 and p2 must be distinct.');
            end

            % Radius of circle from chord and theta
            R = L / (2 * sin(theta / 2));

            % Midpoint of the chord
            mid = (p1 + p2) / 2;

            % Unit vector along chord
            u = chord / L;

            % Perpendicular vector (rotate CCW)
            v = [-u(2); u(1)];

            % Height from chord midpoint to center
            h = sqrt(R^2 - (L/2)^2);

            % Choose center such that arc subtends angle theta
            center = mid + h * v * sign(theta);  % sign determines direction

            % Angles of p1 and p2 relative to center
            a1 = atan2(p1(2) - center(2), p1(1) - center(1));
            a2 = atan2(p2(2) - center(2), p2(1) - center(1));

            % Unwrap and ensure direction follows sign(theta)
            if sign(theta) > 0 && a2 < a1
                a2 = a2 + 2*pi;
            elseif sign(theta) < 0 && a2 > a1
                a2 = a2 - 2*pi;
            end

            % Generate points along arc
            angles = linspace(a1, a2, n);
            chord = R * [cos(angles') sin(angles')];
            arc = center' + chord;
        end
   
        function result = isAngleBetween(theta2, theta1, theta3)
            %ISANGLEBETWEEN Check if theta2 lies between theta1 and theta3 in CCW direction
            %
            % All angles should be in radians. The result is true if moving
            % counter-clockwise from theta1 to theta3 passes through theta2.

            % Normalize all angles to [0, 2*pi)
            theta1 = mod(theta1, 2*pi);
            theta2 = mod(theta2, 2*pi);
            theta3 = mod(theta3, 2*pi);

            if theta1 < theta3
                result = (theta1 < theta2) && (theta2 < theta3);
            else
                result = (theta1 < theta2) || (theta2 < theta3);
            end
        end

    end

end
