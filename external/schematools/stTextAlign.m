classdef stTextAlign
    %methods for aligning text to objects
    properties
        Position
        HorizontalAlignment
        VerticalAlignment
    end

    methods
        function [obj] = stTextAlign(varargin)
            if nargin>0
                obj = stTextAlign.align(varargin{1},varargin{2});
            end
        end
    end

    methods (Static)
        function [obj] = align(refObj,labelPos,opts)
            arguments
                refObj
                labelPos
                opts.Position
                opts.HorizontalAlignment
                opts.VerticalAlignment
                opts.usePlotBox = true;
            end

            if ~ishandle(refObj)
                center = refObj(1);
                middle = refObj(2);
                left = refObj(1);
                right = refObj(1);
                top = refObj(2);
                bottom = refObj(2);
            else

                switch(refObj.Type)
                    case 'axes'
                        pos = refObj.Position;
                        if opts.usePlotBox, pos = plotboxpos(refObj); end
                        center = pos*[1 0 0.5 0]';
                        middle = pos*[0 1 0 0.5]';
                        left = pos(1);
                        right = pos*[1 0 1 0]';
                        top = pos*[0 1 0 1]';
                        bottom = pos(2);
                    otherwise
                        center = mean(refObj.XData);
                        middle = mean(refObj.YData);
                        left = min(refObj.XData);
                        right = max(refObj.XData);
                        top = max(refObj.YData);
                        bottom = min(refObj.YData);
                end
            end

            switch(lower(labelPos))
                case {'center','c'}
                    pos = [center middle];
                    halign = 'center';
                    valign = 'middle';
                case {'northwest','nw'}
                    pos = [left top];
                    halign = 'left';
                    valign = 'top';
                case {'west','w'}
                    pos = [left middle];
                    halign = 'left';
                    valign = 'middle';
                case {'westoutside','wo'}
                    pos = [left middle];
                    halign = 'right';
                    valign = 'middle';
                case {'east','e'}
                    pos = [right middle];
                    halign = 'right';
                    valign = 'middle';                    
                case {'eastoutside','eo'}
                    pos = [right middle];
                    halign = 'left';
                    valign = 'middle';
                case {'northwestoutside','nwo'}
                    pos = [left top];
                    halign = 'left';
                    valign = 'bottom';  
                case {'westnorthoutside','wno'}
                    pos = [left top];
                    halign = 'right';
                    valign = 'top';                     
                case {'northeastoutside','neo'}
                    pos = [right top];
                    halign = 'left';
                    valign = 'bottom';
                case {'northeast','ne'}
                    pos = [right top];
                    halign = 'right';
                    valign = 'top';                    
                case {'north','n'}
                    pos = [center top];
                    halign = 'center';
                    valign = 'top';
                case {'northoutside','no'}
                    pos = [center top];
                    halign = 'center';
                    valign = 'bottom';
                case {'south','s'}
                    pos = [center top];
                    halign = 'center';
                    valign = 'top';
                case {'southoutside','so'}
                    pos = [center bottom];
                    halign = 'center';
                    valign = 'top';
                case {'southeast','se'}
                    pos = [right bottom];
                    halign = 'right';
                    valign = 'bot';
                case {'southeastoutside','seo'}
                    pos = [right bottom];
                    halign = 'right';
                    valign = 'top';
                case {'southwest','sw'}
                    pos = [left bottom];
                    halign = 'left';
                    valign = 'bot';                      
                case {'southwestoutside','swo'}
                    pos = [left bottom];
                    halign = 'right';
                    valign = 'top';                    
                otherwise
                    fprintf('unknown label position: %s\n',labelPos);
                    pos = [center middle];
                    halign = 'center';
                    valign = 'middle';
            end

            obj = stTextAlign();
            obj.Position = pos;
            obj.HorizontalAlignment = halign;
            obj.VerticalAlignment = valign;
        end    

        function [obj] = setAlignProps(obj,align)
            obj.Position(1) = align.Position(1);
            obj.Position(2) = align.Position(2);
            obj.HorizontalAlignment = align.HorizontalAlignment;
            obj.VerticalAlignment = align.VerticalAlignment;
        end

        function [props] = spec(spec)
            props = {};
            if contains(spec,'t'), props{end+1} = 'Verti'; props{end+1} = 'top'; end
            if contains(spec,'b'), props{end+1} = 'Verti'; props{end+1} = 'bottom'; end
            if contains(spec,'m'), props{end+1} = 'Verti'; props{end+1} = 'middle';end
            if contains(spec,'r'), props{end+1} = 'Hori'; props{end+1} = 'right';end
            if contains(spec,'c'), props{end+1} = 'Hori'; props{end+1} = 'center'; end
            if contains(spec,'l'), props{end+1} = 'Hori'; props{end+1} = 'left'; end            
        end
    end
end
