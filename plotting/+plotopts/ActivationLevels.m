classdef ActivationLevels < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
    end
    methods
        function obj = ActivationLevels(opts)
            arguments
                opts.?plotopts.ActivationLevels
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
