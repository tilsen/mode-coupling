classdef PhoneGestureMap < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        ShowKey (1,1) logical = true     % class color key, lower right over the matrix
        KeyFontSize = 16
        ClassColors = struct('V',[0.20 0.45 0.85],'C',[0.90 0.55 0.10], ...
            'N',[0.20 0.65 0.30],'G',[0.60 0.30 0.75], ...
            'L',[0.80 0.35 0.55],'R',[0.15 0.65 0.65])
    end
    methods
        function obj = PhoneGestureMap(opts)
            arguments
                opts.?plotopts.PhoneGestureMap
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
