function [obj] = handleObjectContructorInputs(obj,opts)

ff = fieldnames(opts);

for i=1:numel(ff)
    if isprop(obj,ff{i}) && ~isempty(opts.(ff{i}))
        obj.(ff{i}) = opts.(ff{i});
    end    
end

end