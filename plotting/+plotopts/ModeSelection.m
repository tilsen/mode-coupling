classdef ModeSelection < plotopts.Base
% Shared name-value schema and reusable preset.
    properties
        Parent = []
        panels = []
        activeGesturesOnly = true
        activeTractSysOnly = true
        modeColors = []
        gestureColors = []
        tractColors = []
        excludePanels = ["A"]
        theme = []
        lineWidth = 2
        aspect = 1.8   % figure width / height
        showThreshold = false          % mark the selection/suppression threshold (1) on M and fbM
        thresholdColor = 0.4*[1 1 1]
        thresholdLineStyle = '--'
        thresholdLineWidth = 0.5
        thresholdLabel (1,1) string = ""   % text label on the threshold line
        thresholdLabelFontSize = 14
        thresholdLabelAlignment (1,1) string {mustBeMember(thresholdLabelAlignment,["left","center","right"])} = "left"
        shadeSelection = false         % shade, with alpha, each mode's activation above the threshold (M panel)
        shadeAlpha = 0.25
        showModeLabels = false        % label each mode in its color where its activation starts (M panel)
        modeLabelFontSize = 18
        fieldLabelFontSize = 14        % font size of the tract-system labels in the F axes
        fieldBoxLineWidth = []         % box the F axes with this line width
        fieldTickLength = []           % tick length (fraction of axis) of the F axes
        timeLabel (1,1) string = ""    % x label under the bottom F axes
        timeLabelFontSize = 16
        timeTickFontSizeDelta = 0      % change in tick label size of the bottom F axes
        tickFontSizeDelta = 0          % change in tick label size of every axes
        showPanelLabels = true        % state-variable label (e.g. x_mu) at the upper left of scalar panels
        panelLabelFontSize = 14
        timeLim = []                   % x limits of the time axes (default: zoom to where the dynamics settle)
        fieldGamma = 1                 % F colormap nonlinearity: intensity ~ density^gamma (<1 lifts small densities)
        fieldMinIntensity = 0          % intensity of the lowest color (at fieldClimLow); 0 is white
        fieldClimLow = 0               % F value at the low end of the colormap (densities below it are clipped there)
        centroidColor = [0.75 0.55 0]  % tract-system position (field centroid) on the F panels
        centroidLineWidth = 3.5
        showNeutralTarget = false      % dotted line at each tract system's neutral attractor target (F panels)
        neutralColor = 0.2*[1 1 1]
        neutralLineStyle = ':'
        neutralLineWidth = 0.5
    end
    methods
        function obj = ModeSelection(opts)
            arguments
                opts.?plotopts.ModeSelection
            end
            names = fieldnames(opts);
            for k = 1:numel(names)
                obj.(names{k}) = opts.(names{k});
            end
        end
    end
end
