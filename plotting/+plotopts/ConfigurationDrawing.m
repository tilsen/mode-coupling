classdef ConfigurationDrawing < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        SimplifyLabels = true
        ShowUncoupled = false
        UncoupledLoc = "top"
        Margins = [0.1 0.1];
        Height = nan
        Interactive = true
        ShowPanelLabel = true
        ShowBox (1,1) logical = false
        LabelPrefix = ""
        SystemSymbolFontSize double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []
        ModeLabelFontSize double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []
        PanelLabelFontSize double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []
        SystemSymbolHeightRatio double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = 0.75
        SystemSymbolWidthRatio double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []
        PanelLabelWidthRatio double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = 0.85
        UncoupledSymbolHeightRatio double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []
        UncoupledSymbolFontSize double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = []   % points; fixes the symbol size in the uncoupled row
        ModeLabelHeightRatio double {mustBeScalarOrEmpty,mustBePositive,mustBeFinite} = 0.75
        ModeLabelType (1,1) string {mustBeMember(ModeLabelType,["default","sign","num","mu"])} = "default"
        ModeFillAlpha (1,1) double {mustBeNonnegative,mustBeLessThanOrEqual(ModeFillAlpha,1)} = 0   % shade each mode circle with its color at this alpha
        ExcitationSubscripts (1,1) logical = false   % subscript each excitation symbol with its index among its gestural's excitations (system labels and panel label)
    end
    methods
        function obj = ConfigurationDrawing(opts)
            arguments
                opts.?plotopts.ConfigurationDrawing
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
