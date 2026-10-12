function [out] = mDir(pathSpec,opts)
arguments
    pathSpec
    opts.output = 'table'
    opts.type = 'files'
    opts.details = false
    opts.fullPath = true
    opts.folder = false
    opts.fname = true
    opts.baseName = false
    opts.stringArrays = true
    opts.endPathsep = true
    opts.extension = false
end

switch(opts.type)
    case {'dirs','direc'}        
        method = "dir";
        out = dir(pathSpec);
        out = out([out.isdir]);
        out = out(~ismember({out.name},{'.','..'}));

    otherwise
        method = "rdir";
        out = rdir(char(pathSpec));
end

switch(opts.output)
    case 'struct'
        return;
end

out = struct2table(out);

if height(out)==0, return; end

if opts.fname && method=="rdir"
    if height(out)==1
        [~,f] = fileparts(out.name);
    else
        [~,f,e] = cellfun(@(c)fileparts(c),out.name,'UniformOutput',false);        
    end
    out.fname = f;
    if opts.extension
        out.ext = e;
    end
end

if ~opts.details
    rmcols = {'date' 'bytes' 'isdir' 'datenum'};
    out = out(:,setdiff(tabcols(out),rmcols,'stable'));
end

if opts.endPathsep
    if height(out)==1
        out.folder = [out.folder filesep];
    else
        out.folder = cellfun(@(c){[c filesep]},out.folder); 
    end
end

if method=="dir" && opts.fullPath
    out.path = string(out.folder)+out.name;
end

if ~opts.folder, out.folder = []; end

if opts.stringArrays
    out = tabcell2str(out);
    if height(out)==1
        if opts.folder
            out.folder = string(out.folder);
        end
        out.name = string(out.name);
        if ismember('fname',out.Properties.VariableNames)
            out.fname = string(out.fname);
        end
    end
end



end


