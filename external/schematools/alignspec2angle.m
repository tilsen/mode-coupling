function [angleRad] = alignspec2angle(alignspec)

switch(alignspec)
    case 'n'
        angleRad = pi/2;
    case 'nw'
        angleRad = 3*pi/4;
    case 'ne'
        angleRad = pi/4;
    case 's'
        angleRad = 6*pi/4;
    case 'sw'
        angleRad = 5*pi/4;
    case 'se'
        angleRad = 7*pi/4;
    case 'e'
        angleRad = 0;
    case 'w'
        angleRad = pi;
    otherwise
        fprintf('unknown alignment specification: %s\n',alignspec);
        angleRad = 0;
end

end