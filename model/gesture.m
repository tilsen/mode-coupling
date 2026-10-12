classdef gesture

    properties
        Name
        TractSystem
        Target
        Stiffness = 10
        Ramp
        RampType = "sigmoid"
        FieldSigma = 0.1
        FieldGain = 1
        ActivationFcn = []
    end

    methods
        function obj = gesture(Name,varargin)
            obj.Name = Name;
            for i=1:2:length(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end            
        end        
    end
end