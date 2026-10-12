classdef EnergyPanels < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        maxAlt (1,1) double {mustBeInteger,mustBePositive} = 10
        rowHeight (1,1) double {mustBePositive} = 0.045
        energyCols (1,1) double {mustBeInteger,mustBePositive} = 2
        energyColGap (1,1) double {mustBeNonnegative} = 0.05
        energyRowGap (1,1) double {mustBeNonnegative,mustBeFinite} = 0.005
        energiesFontSize = []
        ColumnLabelFontSize double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []
        selectedColor = [0.4800 0.2330 0.0800]
        selectedLineWidth = 3
    end
    methods
        function obj = EnergyPanels(opts)
            arguments
                opts.?plotopts.EnergyPanels
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
