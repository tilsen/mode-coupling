function [] = adjwidth(obj,adj,opts)
%ADJWIDTH  Add ADJ to the width of each object (Position(3))
%   adjwidth(ax,0.1)                 grows rightward, left edge fixed
%   adjwidth(ax,0.1,centered=true)   grows both ways, center fixed
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
        obj(i).Position(1) = obj(i).Position(1) - adj(i)/2;
    end
    obj(i).Position(3) =  obj(i).Position(3) + adj(i);
end
end
