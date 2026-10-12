classdef stNode

    properties
        Name = "none"
        Label = ""
        Shape = "circle"
        x = nan
        y = nan
        Pos = [nan nan]
        Radius = 1
        Width = 1
        Height = 1
        FontSize = 16
        FontName = 'Calibri'
        FontWeight = 'normal'
        FontAngle = 'normal'
        LineStyle = "-"
        LineWidth = 1
        Color = [1 1 1]
        LabelBackgroundColor = 'none'
        LabelColor = [0 0 0];
        Interpreter = 'tex'
        Rotation = 0
        FaceAlpha = 1
        EdgeColor = [0 0 0]
        LabelPos = "center"
        Visible = "on"
        NodeVisible = "on"
        LabelVisible = "on"
        ConnectObj = "fill"
        FillHandle
        LabelHandle
        EdgePoints = {}
    end

    methods
        function obj = stNode(N)
            props = N.Properties.VariableNames;
            metaObj = metaclass(obj);
            classProps = {metaObj.PropertyList.Name};
            for i=1:length(props)
                if ismember(props(i),classProps)
                    obj.(props{i}) = N.(props{i});
                end
            end
            if isnan(obj.x), obj.x = obj.Pos(1); end
            if isnan(obj.y), obj.y = obj.Pos(2); end
            obj.FillHandle = gobjects(0);
            obj.LabelHandle = gobjects(0);
        end

        function [obj] = setProp(obj,prop,val)            
            obj.(prop) = val;
            switch(prop)
                case 'Pos'
                    obj.x = obj.Pos(1);
                    obj.y = obj.Pos(2);
                case 'x'
                    obj.Pos(1) = obj.x;
                case 'y'
                    obj.Pos(2) = obj.y;
            end
        end

        function [obj] = draw(obj)
            obj = getPoints(obj);
            obj.FillHandle = fill(obj.EdgePoints{1}(:,1),obj.EdgePoints{1}(:,2),obj.Color,...
                'facealpha',obj.FaceAlpha, ...
                'edgecolor',obj.EdgeColor, ...
                'linewidth',obj.LineWidth, ...
                'linestyle',obj.LineStyle(1));
            hold(obj.FillHandle.Parent,'on');
            obj = obj.labelNode();
            switch(obj.NodeVisible)
                case 'off'
                    obj.FillHandle.Visible = 'off';
            end
            switch(obj.LabelVisible)
                case 'off'
                    obj.LabelHandle.Visible = 'off';
            end
            
        end

        function [obj] = getPoints(obj)
            switch(lower(obj.Shape))
                case "circle"
                    th = linspace(0,2*pi,1000)';
                    obj.EdgePoints = {obj.Radius.*[cos(th) sin(th)] + [obj.x obj.y]};
                case {"rect" "square" "box" "rectangle"}
                    switch(obj.Shape)
                        case "square"
                            obj.Height = obj.Width;
                    end
                    xx = obj.x + linspace(-obj.Width/2,obj.Width/2,1000);
                    yy = obj.y + linspace(-obj.Height/2,obj.Height/2,1000);
                    zh = ones(size(xx));
                    boxx = [xx xx(end)*zh fliplr(xx) xx(1)*zh];
                    boxy = [yy(end)*zh fliplr(yy) yy(1)*zh yy];
                    obj.EdgePoints = {[boxx' boxy']};
                otherwise
                    error('unknown shape: %s\nvalid shapes: circle|rect|rectangle|square|box|',lower(obj.Shape));
            end
        end

        function [obj] = labelNode(obj)
            obj.LabelHandle = gobjects(1);
            
            %{
            % !! commented for generality but will break some functions,
            % should address upstream of this function
            obj.Label = strrep(obj.Label,'{','\{');
            obj.Label = strrep(obj.Label,'}','\}');
            %}
            if obj.Label~=""          
                align = stTextAlign.align(obj.FillHandle,obj.LabelPos);                
                obj.LabelHandle = text(align.Position(1),align.Position(2), ...
                    strsplit(char(obj.Label),'\\n'), ...
                    'fontsize',obj.FontSize,...
                    'fontname',obj.FontName,...
                    'fontangle',obj.FontAngle,...
                    'hori',align.HorizontalAlignment,'verti',align.VerticalAlignment,...
                    'Color',obj.LabelColor,...
                    'FontWeight',obj.FontWeight,...
                    'BackGroundColor',obj.LabelBackgroundColor,...
                    'Rotation',obj.Rotation,...
                    'Interpreter',obj.Interpreter);
            end
        end

        function [pos] = getEdgePoint(obj,angle)             
            pos = [obj.x obj.y] + obj.Radius*[cos(angle) sin(angle)];
        end
    end

    methods(Static)
        
    end

end
