function [pos] = objPosition(obj)

if isfield(obj,'Position')
    pos = obj.Position;
else
    bb = objbounds(obj);
    pos = bb([1 3]);
    pos = [pos bb(2)-bb(1) bb(4)-bb(3)];
end


end