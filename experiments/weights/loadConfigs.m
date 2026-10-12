function [C] = loadConfigs(opts)
arguments
    opts struct = struct()
end

d = struct('form',[],'word',[],'group',[],'excludeGroup',[],'requireTarget',true,'configsFile',[]);
f = fieldnames(d);
for k = 1:numel(f)
    if ~isfield(opts,f{k}), opts.(f{k}) = d.(f{k}); end
end

if isempty(opts.configsFile)
    % experiments/weights -> repo root, where data/ lives
    fpath = string(stripPath(fileparts(mfilename("fullpath")),2));
    opts.configsFile = fpath+"data"+filesep+"configs.mat";
end

if ~exist(opts.configsFile,'file'), error('configurations file %s not found\n',opts.configsFile); end

load(opts.configsFile,'C');
if ~isempty(opts.form),  C = C(ismember(C.form,opts.form),:);   end
if ~isempty(opts.word),  C = C(ismember(C.word,opts.word),:);   end
if ~isempty(opts.group), C = C(ismember(C.group,opts.group),:); end
if ~isempty(opts.excludeGroup)
    C = C(~ismember(C.group,opts.excludeGroup),:);
end
if opts.requireTarget
    C = C(C.target~="",:);
end
end