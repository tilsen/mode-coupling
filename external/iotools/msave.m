function [] = msave(savefilepath,savevars,opts)
arguments
    savefilepath
    savevars = {}
    opts.details = false
    opts.verbose = true
    opts.style = "line"
end

savefilepath = string(savefilepath);

if ~iscell(savevars)
    savevars = {savevars};
end

fileExists = exist(savefilepath,'file')==2;

vars_str = cellfun(@(c){['''' char(c) '''']},savevars);
vars_str = strjoin(vars_str,',');

tic
evalin("caller",['save(''' char(savefilepath) ''',' vars_str ');']);
elapsed_time = toc;

if ~opts.verbose, return; end

finfo = dir(savefilepath);

hdrs = ["saved file:" "variables:" "elapsed time:"];
if fileExists, hdrs(1) = "updated file:"; end

if finfo.bytes>1e9
    hdrs(end+1) = "size (GB):";
    divfac = 1e9;
elseif finfo.bytes>1e6
    hdrs(end+1) = "size (MB):";    
    divfac = 1e6;
else
    hdrs(end+1) = "size (kB):";    
    divfac = 1e3;
end

vals = savefilepath;
vals(end+1) = string(strjoin(savevars,', '));
vals(end+1) = string(sprintf('%1.1f',elapsed_time));
vals(end+1) = string(sprintf('%1.1f',finfo.bytes/divfac));

switch(opts.style)
    case "line"
        result = hdrs+" "+vals;
        result = strjoin(result,', ');
    case "table"
        result = align_header_value(hdrs+" ",vals);
end

fprintf('\n%s\n',result);

end