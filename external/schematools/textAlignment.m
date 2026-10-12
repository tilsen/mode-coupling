function [alignment] = textAlignment(textAngleDegrees)

alignment.octant = octant(textAngleDegrees);
alignment.xoffset = 0;
alignment.yoffset = 0;
switch(alignment.octant)
    case 0
        alignment.horizontal = 'left';
        alignment.vertical = 'mid';
        alignment.xoffset = 1;
    case 1
        alignment.horizontal = 'left';
        alignment.vertical = 'bot';
    case 2
        alignment.horizontal = 'center';
        alignment.vertical = 'bot';
        alignment.yoffset = 1;
    case 3
        alignment.horizontal = 'right';
        alignment.vertical = 'bot';        
    case 4
        alignment.horizontal = 'right';
        alignment.vertical = 'mid';
        alignment.xoffset = -1;
    case 5
        alignment.horizontal = 'right';
        alignment.vertical = 'top';
    case 6
        alignment.horizontal = 'center';
        alignment.vertical = 'top';
        alignment.yoffset = -1;
    case 7
        alignment.horizontal = 'left';
        alignment.vertical = 'top';    
end 

alignment.offsets = [alignment.xoffset alignment.yoffset];

end