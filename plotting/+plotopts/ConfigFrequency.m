classdef ConfigFrequency < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        ncols = []
        minStates = 6
        cutoff = 0
        plotConfigs = []
        orientation = 'horizontal'
        barColors = [.5 .5 .5; 1 .5 .5];
        allowInspection = true
        fontSize = 12;
        fontWeight = 'normal'
        tickFontSize = []
        panelFontSize = []
    end
    methods
        function obj = ConfigFrequency(opts)
            arguments
                opts.?plotopts.ConfigFrequency
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
