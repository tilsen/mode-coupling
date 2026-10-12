function [out] = loadOut(filename,varname,msg)
arguments
    filename
    varname = []
    msg = []
end

if ~isempty(msg), fprintf(msg); end
if isempty(varname)    
    x = load(filename);
else
    x = load(filename,varname);    
end
if ~isempty(msg), fprintf('done.\n'); end

f = fieldnames(x);
out = x.(f{1});

end