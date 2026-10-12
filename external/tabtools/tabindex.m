function [T,ixs] = tabindex(T,varargin)

%second input is table row
if istable(varargin{1}) && height(varargin{1})==1
    
    t = varargin{1};
    f = varargin{2};
    v = cell(1,length(f));
    for i=1:length(f)
        v{i} = t.(f{i});
    end

else
    f = varargin(1:2:end);
    v = varargin(2:2:end);
end


ixs = (1:height(T))';

for i=1:length(f)

    if f{i}(1)=='~'
        f{i} = f{i}(2:end);
        negate = true;
    else
        negate = false;
    end

    switch(iscell(T.(f{i})))
        case 1
            ix_keep = ismember(T.(f{i}),v{i});

        case 0
            v{i} = v{i}(:)';
            ix_keep = any(T.(f{i})==v{i},2);

    end

    if negate, ix_keep = ~ix_keep; end

    ixs = ixs(ix_keep);
    T = T(ix_keep,:);

end

end