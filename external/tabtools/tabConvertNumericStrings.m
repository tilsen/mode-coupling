function T = tabConvertNumericStrings(T)
    % Iterate over each column of the table
    for col = 1:width(T)
        colData = T{:, col}; % Extract column data
        
        % Check if column is a cell array of character vectors
        if iscell(colData) && all(cellfun(@(x) ischar(x) || isstring(x), colData))
            % Attempt conversion to numeric
            numData = str2double(colData);
            if all(~isnan(numData) | cellfun(@isempty, colData))  % Ensure all valid numbers
                T.(T.Properties.VariableNames{col}) = numData;  % Convert column to numeric
            end
        
        % Check if column is a string array
        elseif isstring(colData)
            numData = str2double(colData);
            if all(~isnan(numData))  % Ensure all valid numbers
                T.(T.Properties.VariableNames{col}) = numData;  % Convert column to numeric
            end
        end
    end
end
