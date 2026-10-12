function [X] = tabcell2str(X)

varnames = tabcols(X);
for i=1:length(varnames)
    x = X.(varnames{i});
    if iscell(x)
        charcells = cellfun(@(c)ischar(c),x);        
        stringcells = cellfun(@(c)isstring(c),x); 
        if all(charcells)
            X.(varnames{i}) = string(x);
        elseif all(stringcells)    
            stringempty = cellfun(@(c)isempty(c),x);
            x(stringempty) = repmat({""},sum(stringempty),1);
            X.(varnames{i}) = vertcat(x{:});
        end
    end
end

end