classdef Graphs < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        separateFigures = true
        FontSize = 12;
    end
    methods
        function obj = Graphs(opts)
            arguments
                opts.?plotopts.Graphs
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
