function [data] = loadConfigData(source,opts)
arguments
    source
    opts.config = [];
end

data = tabcell2str(readtable(source,'Delimiter',','));
data = configLabels(data);
if ~isempty(opts.config)
    if isnumeric(opts.config)
        data = data(opts.config,:);
    else
        if ismember('name',tabcols(data))
            data = data(ismember(data.name,opts.config),:);
        elseif ismember('word',tabcols(data))
            data = data(ismember(data.word,opts.config),:);
        end
    end
end

end