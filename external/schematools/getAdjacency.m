function [Adjacency,T] = getAdjacency(T)

arguments
    T
end

T.Properties.VariableNames = regexprep(T.Properties.VariableNames,'^Name$','name');

names = unique(T.name,'stable');
Adjacency = false(numel(names),numel(names));

for a=1:length(names)
    for b=1:length(names)
        for i=1:height(T)
            if T.parent(i)==names(a) && T.name(i)==names(b)
                Adjacency(a,b) = true;
            end
        end
    end
end


end