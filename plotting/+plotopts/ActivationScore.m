classdef ActivationScore < plotopts.Score
% Shared name-value schema and reusable preset.
    properties
        LineWidth = 2
        ShowActivation = true       % draw the activation time series inside each interval
    end
    methods
        function obj = ActivationScore(opts)
            arguments
                opts.?plotopts.ActivationScore
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
