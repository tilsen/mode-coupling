function [y] = nempt(x,varargin)

if nargin==1
    y = x(~cellfun('isempty',x));
    return;
end

if istable(x)
    y = x(~cellfun('isempty',x.(varargin{1})),:);
end

end