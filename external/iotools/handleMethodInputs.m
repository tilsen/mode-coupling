function [opts] = handleMethodInputs(obj,opts)

ff = fieldnames(opts);

for i=1:numel(ff)
    if isempty(opts.(ff{i}))
        if isprop(obj,ff{i}) && ~isempty(obj.(ff{i}))
            opts.(ff{i}) = obj.(ff{i});
        end
    end
end

end