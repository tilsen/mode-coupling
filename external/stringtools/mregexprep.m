function [s] = mregexprep(strs,varargin)

patterns = varargin(1:2:end);
reps = varargin(2:2:end);

s = strs;
for i=1:length(patterns)
    s = regexprep(s,patterns{i},reps{i});
end

end