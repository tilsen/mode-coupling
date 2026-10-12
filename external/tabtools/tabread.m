function [X] = tabread(name,varargin)

X = tabcell2str(readtable(name,varargin{:}));

end