function [lines] = align_header_value(HDR,VAL)

HDR = HDR(:);
VAL = VAL(:);

if iscell(HDR)
    hdrs = strjust(cell2mat(pad(HDR)),'right');
else
    hdrs = strjust(pad(HDR),'right');
end

if iscell(VAL)
    vals = strjust(cell2mat(pad(VAL)),'left');
    lines = cellstr([hdrs repmat(' ',size(hdrs,1),1) vals]);
else
    vals = strjust(VAL,'left');
    lines = hdrs+" "+vals+newline;
end



end