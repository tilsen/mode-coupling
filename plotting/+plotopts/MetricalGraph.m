classdef MetricalGraph < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        FontSize = 16
    end
    methods
        function obj = MetricalGraph(opts)
            arguments
                opts.?plotopts.MetricalGraph
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
