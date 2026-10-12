function [ix] = isemptyc(x)

ix = cellfun(@(c)isempty(c),x);

end