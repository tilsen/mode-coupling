function [result] = colExists(T,col)
result = istable(T) & ismember(col,tabcols(T));        
end