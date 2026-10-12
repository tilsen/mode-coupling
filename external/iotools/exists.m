function [out] = exists(names, searchType)
arguments
    names
    searchType = 'file'
end

if isstring(names)
    out = arrayfun(@(c)exist(c,searchType)~=0,names);
elseif iscell(names)
    out = cellfun(@(c)exist(c,searchType)~=0,names);
end


end