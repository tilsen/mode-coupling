classdef ConfigurationGeometry < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Radius = []
        ExcitationRadiusRatio = []   % excitation circle radius / mode radius (default 0.1)
        StackCoincident = false      % stack excitations that share a position within a mode vertically
        ModeIds = []
        VerticalSpacing = []
        HorizontalSpacing = []
    end
    methods
        function obj = ConfigurationGeometry(opts)
            arguments
                opts.?plotopts.ConfigurationGeometry
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
