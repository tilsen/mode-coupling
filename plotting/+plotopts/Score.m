classdef Score < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        plotTiers = []
        edgeColor = 'none'
        tierLabels = false
        tierHeight = 1
        intHeightProp = 0.90;
        intHeight = []
        faceAlpha = 0.5
        yOffset = 0;
        fontSize = [];
        yDir (1,1) string {mustBeMember(yDir,["up","reverse"])} = "up";
        parent = []
        fillByActivation = false;
        labelPos (1,1) string {mustBeMember(labelPos,["begin","center"])} = "begin";
    end
    methods
        function obj = Score(opts)
            arguments
                opts.?plotopts.Score
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
