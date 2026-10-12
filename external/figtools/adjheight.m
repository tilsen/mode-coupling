function [] = adjheight(obj,adj,opts)
%ADJHEIGHT  Add ADJ to the height of each object (Position(4))
%   adjheight(ax,0.1)                 grows upward, bottom edge fixed
%   adjheight(ax,0.1,centered=true)   grows both ways, center fixed
% ADJ is a scalar or one value per object.
arguments
    obj
    adj
    opts.centered (1,1) logical = false
end

if numel(adj)<numel(obj)
    adj = adj*ones(size(obj));
end

for i=1:numel(obj)
    if ~ishandle(obj(i)),continue; end
    if opts.centered
        obj(i).Position(2) = obj(i).Position(2) - adj(i)/2;
    end
    obj(i).Position(4) =  obj(i).Position(4) + adj(i);
end
end
