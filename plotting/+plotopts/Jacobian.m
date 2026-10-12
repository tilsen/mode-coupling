classdef Jacobian < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        inverse = true
        parent = [];
    end
    methods
        function obj = Jacobian(opts)
            arguments
                opts.?plotopts.Jacobian
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
