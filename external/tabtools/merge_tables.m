function [C] = merge_tables(A,B,opts)
arguments
    A
    B
    opts.verbose = false
    opts.removeA = false
    opts.removeB = false
    opts.autoFix = true
    opts.allowNumericToString = false
end

if isempty(A)    
    C = B; return;
end

if isempty(B)
    C = A; return;
end

if opts.verbose
    [ab,ba] = tabdiff(A,B,true);
else
    [ab,ba] = tabdiff(A,B);
end

if isempty(ab) && isempty(ba)
    C = [A; B];
    return;
end

if ~isempty(ab)
    if opts.removeA
        A = A(:,setdiff(tabcols(A),ab));
    else
        for i=1:length(ab)
            B.(ab{i}) = repmat(repvar(A.(ab{i})),height(B),1);
        end
    end
end

if ~isempty(ba)
    if opts.removeB
        B = B(:,setdiff(tabcols(B),ba));
    else
        for i=1:length(ba)
            A.(ba{i}) = repmat(repvar(B.(ba{i})),height(A),1);
        end
    end
end  

%check types
I.colname = string(tabcols(A))';
I = struct2table(I);
I.aclass = string(arrayfun(@(c){class(A.(c))},I.colname));
I.bclass = string(arrayfun(@(c){class(B.(c))},I.colname));
I.match = I.aclass==I.bclass;
I.fixable = ~I.match & any([I.aclass I.bclass]=="cell",2);

if opts.allowNumericToString
    I.fixable = I.fixable | all(~I.match & I.aclass=="string" & I.bclass=="double",2);
end

for i=1:height(I)
    if I.match(i), continue; end
    if opts.verbose
        fprintf('mismatched types in %s, a: %s, b: %s\n',I.colname(i),I.aclass(i),I.bclass(i));
    end
    
    if opts.autoFix && I.fixable(i)
        if I.aclass(i)=="cell"
            ix = cellfun('isempty',A.(I.colname(i)));
            A.(I.colname(i))(ix) = repvar(B.(I.colname(i)));
            A.(I.colname(i)) = cell2mat(A.(I.colname(i)));
        elseif I.bclass(i)=="cell"
            ix = cellfun('isempty',B.(I.colname(i)));
            B.(I.colname(i))(ix) = repvar(A.(I.colname(i)));
            B.(I.colname(i)) = cell2mat(B.(I.colname(i)));
        elseif I.bclass(i)=="double"
            B.(I.colname(i)) = string(B.(I.colname(i)));
        else
            error('table merge failed');
        end

    else
        error('table merge failed');
    end
end

C = [A; B];

end

%%
function [ro] = repvar(x)

if all(isnumeric(x))
    ro = nan;
else
    if iscell(x), x = x{1}; end
    switch(class(x))
        case 'char'
            ro = {''};
        case 'double'
            ro = {nan};
        case 'string'
            ro = {""};
        case 'datetime'
            ro = {NaT};
        case 'logical'
            ro = {false};
        otherwise
            ro = {[]};
    end
end

end
