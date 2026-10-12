classdef effector

    properties
        Name
        InitState = [0.5 0]
        Dims = [0 1]
        Neutr = 0.5
    end

    methods
        function obj = effector(Name)
            obj.Name = Name;            
        end
    end
end