function [strs] = wrap_text(str,line_width,varargin)

p = inputParser;

def_delimiters = {' '};

addRequired(p,'str');
addRequired(p,'line_width');
addParameter(p,'delimiters',def_delimiters);
addParameter(p,'minBreak',[]);
addParameter(p,'trimSpace',true);

parse(p,str,line_width,varargin{:});

if all(ishandle(str))
    for i=1:numel(str)
        strs = wrap_text(str(i).String,line_width,varargin{:});
        str(i).String = strs;
    end
    return;
end

r = p.Results;

if isempty(r.minBreak)
    r.minBreak = r.line_width;
end

if isstring(str)
    str = char(str);
end

strs = {str};

lastlen = @(c)length(c{end});
if ~isempty(r.delimiters)
    delims = strjoin(r.delimiters,'|');
else
    delims = '';
end

while (lastlen(strs)>line_width)
   
    if isempty(delims)
        ix = 1:length(strs{end});
    else
        ix = regexp(strs{end},delims);
    end
    if isempty(ix), break; end

    if any(ix>r.minBreak) 
        breakix = ix(abs(ix-line_width)==min(abs(ix-line_width)));
        %breakix = ix(find(ix>r.minBreak,1,'first'))-1; 
    else
        break;
    end

    strs{end+1} = strs{end}(breakix+1:end);
    strs{end-1} = strs{end-1}(1:breakix);
end

        
if r.trimSpace
    strs = strtrim(strs);
end

end