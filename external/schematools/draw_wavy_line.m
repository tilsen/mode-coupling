function [] = draw_wavy_line(lineObj,ampfac,opts)
% draw_wavy_line  Replace a straight line object's data with a wavy path
% between its first and last points (see wavyPath).
arguments
    lineObj
    ampfac = 0.1
    opts.freq = 4
    opts.phase = 0
    opts.nPoints = 100
end

endpoints = [lineObj.XData([1 end])' lineObj.YData([1 end])'];
XY = wavyPath(endpoints,ampfac,freq=opts.freq,phase=opts.phase,nPoints=opts.nPoints);

set(lineObj,'XData',XY(:,1),'YData',XY(:,2));

end
