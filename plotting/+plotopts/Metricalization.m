classdef Metricalization < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent=[]
        style = "bars"
        normalize = true
        showLabels = true
        fontSize = 16
        stressThresh = 0.0
        stressColors = flipud(pastelize(hsv(2),0.25));
        unstressedColor = 0.75*[1 1 1];
        showBaseLine = 'on'
    end
    methods
        function obj = Metricalization(opts)
            arguments
                opts.?plotopts.Metricalization
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
