function [fname] = fileparts_filename(str,opts)
arguments
    str
    opts.includeExt = false    
end

[~,fname,ext] = fileparts(char(str));

if opts.includeExt
    fname = [fname, ext];
end

if isstring(str)
    fname = string(fname);
end

end
