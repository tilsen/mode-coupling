function [terminate] = handleOverwrite(overwrite,target,opts)

arguments
    overwrite
    target
    opts.terminate = true
    opts.verbose = true
    opts.type = 'file'
end

targetExists = false;
terminate = false;
if isstruct(overwrite)
    if isfield(overwrite,'overwrite')
        overwrite = overwrite.overwrite;
    end
elseif islogical(overwrite)

else
    dbstop if error
    error('Invalid input');
end

switch(opts.type)
    case 'empty'
        files = mDir(fullfile(target,'*'));
        if height(files)>0, targetExists = true; end
    otherwise
        switch(isnumeric(target)|islogical(target))
            case true
                targetExists = logical(target);
                target = "file";
            otherwise
                if exist(target,opts.type), targetExists = true; end
        end
end

if opts.verbose
    if targetExists
        switch(opts.type)
            case 'empty'
                str = target + " not empty";
            otherwise
                str = target + " exists";
        end

        if opts.terminate && ~overwrite
            str = str + ", aborting...";
        end        
        fprintf('%s\n',str);
    end
end

if ~overwrite && opts.terminate && targetExists
    terminate = true;
end

end