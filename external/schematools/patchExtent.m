function [XY] = patchExtent(obj)

XY = [minmax(obj.XData(:)'); minmax(obj.YData(:)')]';
XY = [XY(1,:); XY(2,1) XY(1,2); XY(2,1) XY(2,2); XY(1,1) XY(2,2)];

end