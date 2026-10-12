function [] = apgp(path,nstrip,opts)
arguments
    path = []
    nstrip = []
    opts.ignoreGit = true
end

if isempty(path), path = '.'; end
if isempty(nstrip), nstrip = 0; end

if nstrip>0, path = stripPath(path,nstrip); end

paths = genpath(path);

switch(opts.ignoreGit)
    case true
        paths = string(regexp(paths,';','split'));
        paths = paths(~contains(paths,'.git'));
        paths = strjoin(paths,';');
end


addpath(paths);

end