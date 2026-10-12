function [ch] = randomConnections(nh1,nh2,opts)

arguments
    nh1
    nh2
    opts.connProb    
    opts.output = 'vector'
    opts.Color = [0 0 0];
    opts.LineWidth = 1
end

conn = rand([numel(nh1) numel(nh2)])<opts.connProb;
ch = gobjects(size(conn));

for a=1:size(ch,1)
    for b=1:size(ch,2)
        if conn(a,b)
            try
                xx = mean([nh1(a).XData(:) nh2(b).XData(:)]);
                yy = mean([nh1(a).YData(:) nh2(b).YData(:)]);
            catch
                xx = [mean(nh1(a).XData) mean(nh2(b).XData)];
                yy = [mean(nh1(a).YData) mean(nh2(b).YData)];
            end
            ch(a,b) = plot(xx,yy,'Color',opts.Color,'LineWidth',opts.LineWidth);
        end
    end
end

switch(opts.output)
    case 'vector'
        ch = ch(conn);
end

end