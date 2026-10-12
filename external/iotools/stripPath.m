function [pathStripped] = stripPath(path,nStrip,includeFinalSep,opts)
arguments
    path
    nStrip = 1
    includeFinalSep = true
    opts.output = "start"
end

fileSep = regexp(path,'[\\/]','match','once');
parts = regexp(path,fileSep,'split');

if isempty(parts{end}), parts = parts(1:end-1); end

switch(opts.output)
    case "end"
        pathStripped = strjoin(parts(end-nStrip+1:end),fileSep);
        includeFinalSep = false;
    otherwise
        pathStripped = strjoin(parts(1:end-nStrip),fileSep);
end

if includeFinalSep
    if isstring(pathStripped)
        pathStripped = pathStripped + fileSep;
    else
        pathStripped = [pathStripped fileSep];
    end
end

end