classdef TractSystems < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        parent =[]

        LineWidth = 2
        state = 'pos'
        plotInactive = false
    end
    methods
        function obj = TractSystems(opts)
            arguments
                opts.?plotopts.TractSystems
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
