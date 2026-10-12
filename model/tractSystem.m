classdef tractSystem

    properties
        Name
        Dims = [0 1]        
        Type = 'scalar'
        InitState
        FieldPoints = 101
        Field
        Neutr = 0.5
        NeutrGain = 0.1
        NeutrSigma = 0.25
        Stiffness = 1        
    end

    methods
        function obj = tractSystem(Name,opts)
            arguments
                Name
                opts.Type = []
                opts.FieldPoints = []
            end
            if ~isempty(opts.Type), obj.Type = opts.Type; end
            if ~isempty(opts.FieldPoints), obj.FieldPoints = opts.FieldPoints; end
            obj.Name = Name;            
            switch(obj.Type)
                case 'field'
                    obj.Field = linspace(obj.Dims(1),obj.Dims(2),obj.FieldPoints);
                    obj.InitState = zeros(size(obj.Field));
                otherwise
                    obj.InitState = [0.5 0];
            end
        end        
    end
end