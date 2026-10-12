classdef Energy < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        FontSize = 16;
        ColumnLabelFontSize double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []
        RowHeight = []
    end
    methods
        function obj = Energy(opts)
            arguments
                opts.?plotopts.Energy
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
