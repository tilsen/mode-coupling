function [cmap] = stColormap(points,nColors,opts)
arguments
    points
    nColors = []
    opts.trim = [nan nan]
    opts.flip = false;
end

if isempty(nColors), nColors = 256; end

if isstring(points) || ischar(points)
    cmap = eval([points '(' num2str(nColors) ');']);
    cmap = trimMap(cmap,opts.trim);
    if opts.flip, cmap = flipud(cmap); end
    return;
end

cmap = [];
for i=1:size(points,1)-1
    c = [];
    for j=1:3
        c(:,j) = linspace(points(i,j),points(i+1,j),nColors);
    end
    cmap = [cmap(1:end-1,:); c];
end
cmap = trimMap(cmap,opts.trim);
if opts.flip, cmap = flipud(cmap); end

end

function [cmap] = trimMap(cmap,trim)

if ~isnan(trim(1))
    cmap = cmap(trim(1):end,:);
end
if ~isnan(trim(2))
    cmap = cmap(1:end-trim(1),:);
end

end

