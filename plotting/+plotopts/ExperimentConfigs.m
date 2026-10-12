classdef ExperimentConfigs < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        ncols = 5
    end
    methods
        function obj = ExperimentConfigs(opts)
            arguments
                opts.?plotopts.ExperimentConfigs
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
