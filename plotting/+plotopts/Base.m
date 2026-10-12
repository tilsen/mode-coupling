classdef Base
% Common conversion for plot option schemas. No graphics state belongs here.
    methods
        function values = toStruct(obj)
            names = properties(obj);
            values = struct();
            for k = 1:numel(names)
                values.(names{k}) = obj.(names{k});
            end
        end
        function values = args(obj)
            values = namedargs2cell(obj.toStruct());
        end
    end
    methods (Static)
        function values = resolve(supplied,defaults)
            values = defaults.toStruct();
            names = fieldnames(supplied);
            for k = 1:numel(names)
                values.(names{k}) = supplied.(names{k});
            end
        end
        function values = select(supplied,schema)
            % Explicit partition at the constructor/drawing boundary.
            names = intersect(fieldnames(supplied),properties(schema),'stable');
            values = struct();
            for k = 1:numel(names)
                values.(names{k}) = supplied.(names{k});
            end
        end
    end
end
