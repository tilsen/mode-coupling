function [data] = configLabels(data,opts)
arguments
    data
    opts.orth = true
    opts.trans = true
    opts.phonemes = false
end

%aspiration
data.trans = regexprep(data.trans,'(?<=\w+)h','^{h}');

data.label = "[" + strrep(articulae.toIPA(data.trans), ' ','') + "]";
data.label = "{\it{" + data.word + "}} " + "\rm" + data.label;

end