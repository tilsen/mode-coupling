function [y] = trimarray(x,trimbegin,trimend,dim)

if nargin==2
    trimend = trimbegin;
    trimbegin = 0;
    dim = nan;
elseif nargin<=3
    dim = nan;
end

switch(isnan(dim))
    case true
        y=x((1+trimbegin):(end-trimend));

    case false
        switch(dim)
            case 1
                y=x((1+trimbegin):(end-trimend),:);
            case 2
                y=x(:,(1+trimbegin):(end-trimend));
            case 3
                y=x(:,:,(1+trimbegin):(end-trimend));
        end        
end

end