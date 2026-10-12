function [T] = tabfix(T)

ff = T.Properties.VariableNames;
for i=1:length(ff)
    col = T.(ff{i});
    if iscell(col) 
        %numeric with none empty
        if all(cellfun(@(c)isnumeric(c),col)) && ...
           numel(unique(cellfun(@(c)size(c,2),col)))==1 && ... 
           sum(isemptyc(col))==0 && ... 
           all(cellfun(@(c)size(c,1),col)==1) %#ok<ISCL>
            T.(ff{i}) = cell2mat(col);
        end
        %cell of character vectors
        if any(cellfun(@(c)ischar(c),col))
            col(~cellfun(@(c)ischar(c),col)) = {''};
            T.(ff{i}) = col;
        end
        %cell of string vectors
        if any(cellfun(@(c)isstring(c),col))
            col(~cellfun(@(c)isstring(c),col)) = {""};
            col(cellfun(@(c)isempty(c),col)) = {""};
            T.(ff{i}) = vertcat(col);
        end
    end
end


end