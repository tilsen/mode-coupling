function [T1o,T2o] = tabdiff(T1,T2,verbose)
arguments
    T1 {table}
    T2 {table}
    verbose = false
end
T1o = setdiff(tabcols(T1),tabcols(T2));
T2o = setdiff(tabcols(T2),tabcols(T1));

if verbose
    fprintf('only in T1: %s\n', strjoin(T1o,', '));
    fprintf('only in T2: %s\n', strjoin(T2o,', '));
end

end