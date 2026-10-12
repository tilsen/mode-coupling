function [octant] = octant(angleDeg)

normalizedAngle = mod(angleDeg+(180/8),360);
if normalizedAngle<0, normalizedAngle=normalizedAngle+360; end
octant = floor(normalizedAngle/(360/8));

end

