classdef Inspector < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        maxAlt = 10;           % hard cap, whatever the figure size
        rowHeight = 0.045;     % height of one energy-matrix row,
        energyCols = 1;        % columns of alternative matrices
        energyColGap = 0.05;   % horizontal gap between those columns,
        energyRowGap (1,1) double {mustBeNonnegative,mustBeFinite} = 0.005
        interactive = true
        energiesFontSize = [];  % [] -> derived from rowHeight
        ColumnLabelFontSize double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []
        maxIterFontSize double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = 12
        parent = []
        selectedColor = [0.4800 0.2330 0.0800];
        selectedLineWidth = 3;
        showIterations = true
    end
    methods
        function obj = Inspector(opts)
            arguments
                opts.?plotopts.Inspector
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
