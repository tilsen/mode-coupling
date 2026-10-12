classdef Iterations < plotopts.Configuration
% Shared name-value schema and reusable preset.
    properties
        NumRows = [];
        autoMaxCols = 5
        intMargins = [0.06 0.12];
    end
    methods
        function obj = Iterations(opts)
            arguments
                opts.?plotopts.Iterations
            end
            obj.ShowUncoupled = true;
            obj.ShowBox = true;
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
