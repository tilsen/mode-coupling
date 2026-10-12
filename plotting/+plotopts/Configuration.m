classdef Configuration < plotopts.ConfigurationGeometry & plotopts.ConfigurationDrawing
% Shared name-value schema and reusable preset.
    methods
        function obj = Configuration(opts)
            arguments
                opts.?plotopts.Configuration
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
