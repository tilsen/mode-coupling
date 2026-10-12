function [colnames] = tabcols(D)

if ~istable(D), colnames=[]; return; end
colnames = D.Properties.VariableNames;

end
