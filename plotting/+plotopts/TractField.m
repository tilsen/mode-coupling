classdef TractField < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        parent =[]

        LineWidth = 2
        state = 'pos'
        colormap = 'hot'
        Color = 'g';
        showTractState = true
        showLabel = true
    end
    methods
        function obj = TractField(opts)
            arguments
                opts.?plotopts.TractField
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
