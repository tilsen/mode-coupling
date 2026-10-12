function dotStr = dotInchesToPoints(dotStr,scale)

    pattern = 'pos="([\-0-9\.]+),([\-0-9\.]+)!"';

    for i = 1:numel(dotStr)
        tokens = regexp(dotStr(i), pattern, 'tokens');
        if ~isempty(tokens)
            x = str2double(tokens{1}{1});
            y = str2double(tokens{1}{2});
            xPts = x * scale;
            yPts = y * scale;
            newPos = sprintf('pos="%.5f,%.5f!"', xPts, yPts);
            dotStr(i) = regexprep(dotStr(i), pattern, newPos);
        end
    end

end
