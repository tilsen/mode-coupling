classdef Graph < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        edgeWeights = 'cumulative'; %forward, cumulative, raw, prop
        propLineWidth = true
        showEdgeLabels = true
        stateLabels = "numbered"
        numLabelCols = 1;
        labelColProp = 0.15; %proportion of figure width
        nodeFontSize = 16;
        statesFontSize = 16;
        edgeFontSize = 8;
        highlightConfigs string = string.empty
        highlightColor = [1 0 0]
        highlightLineWidth = 2
    end
    methods
        function obj = Graph(opts)
            arguments
                opts.?plotopts.Graph
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
