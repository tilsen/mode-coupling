function [h] = drawBracePair(pos,opts)
arguments
    pos
    opts.direction = 'horizontal'
    opts.width = 0.05; %proportion of width
    opts.parent = []
    opts.curvature = 8*pi
    opts.color = [ 0 0 0]
    opts.lineWidth = 2
    opts.faceColor = []
    opts.faceAlpha = 0.5
    opts.edgeColor = []
end

if ishandle(pos)
    if isempty(opts.parent), opts.parent = pos.Parent; end
    pos = objPosition(pos);    
end

if isempty(opts.parent)
    opts.parent = gca;
end


switch(opts.direction)
    case 'vertical'

    otherwise
        w = opts.width*pos(3);
        h(1) = drawBrace([pos(1) pos(2) w pos(4)],direction='left', ...
            color=opts.color,curvature=opts.curvature,lineWidth=opts.lineWidth,parent=opts.parent);
        h(2) = drawBrace([sum(pos([1 3]))-w pos(2) w pos(4)],direction='right', ...
            color=opts.color,curvature=opts.curvature,lineWidth=opts.lineWidth,parent=opts.parent);        
end

if ~isempty(opts.faceColor)
    px = [h(1).XData(:); flipud(h(2).XData(:))];
    py = [h(1).YData(:); h(2).YData(:)];
    if isempty(opts.edgeColor)
        opts.edgeColor = opts.color;
    end
    h(end+1) = fill(px(:),py(:),opts.faceColor,'FaceAlpha',opts.faceAlpha,'EdgeColor',opts.edgeColor);
end

end