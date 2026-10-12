function [handles,centers] = randomNodes(obj,numNodes,opts)

arguments
    obj
    numNodes = 100
    opts.Diameter = 0.01
    opts.NodeMargin = '10%'
    opts.ObjMargin = '5%';
    opts.FaceColor = [0 0 0]
    opts.EdgeColor = 'none'
    opts.Method = 'grid'
    opts.Jitter = '5%';
    opts.ColorByX = []
    opts.ColorByY = []
end

BB = [obj.XData(:) obj.YData(:)];
lims = minmax(BB');

if isempty(opts.Diameter), opts.Diameter = min(diff(lims,[],2))/numNodes; end
if isscalar(opts.Diameter), opts.Diameter = repmat(opts.Diameter,1,2); end

opts.ObjMargin = interpretPropParam(opts.ObjMargin,diff(lims,[],2));
opts.NodeMargin = interpretPropParam(opts.NodeMargin,opts.Diameter);
opts.Jitter = interpretPropParam(opts.Jitter,opts.Diameter);

if ~isempty(opts.ObjMargin)

    %recalculate lims
    xy = [obj.XData(:) obj.YData(:)];
    cc = nanmean(xy); %#ok<NANMEAN>
    xy = xy - cc;
    xy = xy.*(1-opts.ObjMargin);
    BB = xy + cc;
    lims = minmax(BB');
end

ixFcn = @(x,n,lims)min(1+floor(n*(x-lims(1))/diff(lims)),n);
if ~isempty(opts.ColorByX)
    nColors = size(opts.ColorByX,1);
    colorFcn = @(x)opts.ColorByX(ixFcn(x,nColors,lims(1,:)),:);
elseif ~isempty(opts.ColorByY)
    nColors = size(opts.ColorByY,1);
    colorFcn = @(x)opts.ColorByY(ixFcn(x,nColors,lims(2,:)),:);
else
    colorFcn = @(x)opts.FaceColor;
end


switch(opts.Method)
    case 'grid'
        xp = lims(1,1):(opts.Diameter(1) + opts.NodeMargin(1)):lims(1,2);
        yp = lims(2,1):(opts.Diameter(2) + opts.NodeMargin(2)):lims(2,2);
        [xx,yy] = meshgrid(xp,yp);
        xx = xx(:); yy =yy(:);
        in = inpolygon(xx,yy,BB(:,1),BB(:,2));

        if sum(in)<numNodes
            fprintf('WARNING: fewer node positions available than requested nodes\n');
        end

        xx = xx(in);
        yy = yy(in);
        ixs = randperm(length(xx),numNodes);
        xx = xx(ixs);
        yy = yy(ixs);
        xx = xx + (rand(size(xx))-1/2)*opts.Jitter(1);
        yy = yy + (rand(size(yy))-1/2)*opts.Jitter(2);
        xx = min(max(xx,lims(1,1)),lims(1,2));
        yy = min(max(yy,lims(2,1)),lims(2,2));

        th = linspace(0,2*pi,100)';
        PP = opts.Diameter.*[cos(th) sin(th)];
        for i=1:length(xx)
            colorInput = i;
            if ~isempty(opts.ColorByX)
                colorInput = xx(i);
            elseif ~isempty(opts.ColorByY)
                colorInput = yy(i);
            end
            handles(i) = fill(xx(i)+PP(:,1),yy(i)+PP(:,2),colorFcn(colorInput),'EdgeColor',opts.EdgeColor);
        end
        centers = [xx yy];

    otherwise

end

end

function [values] = interpretPropParam(valIn,lims)
if ischar(valIn), value = string(valIn); end
if isscalar(value), value = repmat(value,1,2); end
if isstring(value)
    values = zeros(1,2);
    for i=1:2
        perc = str2double(regexp(value(i),refp,'match','once'))/100;
        values(i) = lims(i)*perc;
    end    
end
end