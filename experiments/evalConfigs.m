function [C] = evalConfigs(opts)
arguments
    opts.overwrite = false
    opts.regenerate = false
    opts.form = []
    opts.word = []
    opts.group = []
    opts.excludeGroup = []
    opts.requireTarget = true;
    opts.outputMode = 'table'
    opts.maxRows = 10
    opts.params = []
end

if opts.overwrite || opts.regenerate
    clear articulae gmConfigurator
end

if opts.overwrite
    f = mDir(which("configs.csv"),folder=true);
    if height(f)==0, error('configs.csv not found'); end
    data = tabread(f.name,'Delimiter',',');
    data = configLabels(data);
    data.id = data.group+"_"+data.form;
    data.config = arrayfun(@(c)gmConfigurator(),(1:height(data))');

    % rows outside the requested subset keep their previously generated
    % config rather than being regenerated (generation is stochastic)
    subsetIx = true(height(data),1);
    if ~isempty(opts.form),         subsetIx = subsetIx & ismember(data.form,opts.form);          end
    if ~isempty(opts.word),         subsetIx = subsetIx & ismember(data.word,opts.word);          end
    if ~isempty(opts.group),        subsetIx = subsetIx & ismember(data.group,opts.group);        end
    if ~isempty(opts.excludeGroup), subsetIx = subsetIx & ~ismember(data.group,opts.excludeGroup); end

    matFile = f.folder + "configs.mat";
    inOld = false(height(data),1);
    if exist(matFile,'file')
        old = load(matFile,'C');
        Cold = old.C(ismember(old.C.id,data.id),:);
        [inOld,ia] = ismember(data.id,Cold.id);
        data.config(inOld) = Cold.config(ia(inOld));
    end

    toGen = find(~inOld | subsetIx);
    pm = progressMonitor(numel(toGen));
    for j=1:numel(toGen)
        pm.update(j);
        i = toGen(j);
        mc = modeConfig(data.form(i)); %#ok<*AGROW>
        c = gmConfigurator(mc);
        c = c.setParams(data.params(i));
        data.config(i) = c.genModeConfig();
    end
    pm.reset();

    C = data;
    msave(matFile,'C');

    if ~isempty(opts.form),  C = C(ismember(C.form,opts.form),:);   end
    if ~isempty(opts.word),  C = C(ismember(C.word,opts.word),:);   end
    if ~isempty(opts.group), C = C(ismember(C.group,opts.group),:); end
    if ~isempty(opts.excludeGroup)
        C = C(~ismember(C.group,opts.excludeGroup),:);
    end
    if opts.requireTarget
        C = C(C.target~="",:);
    end
else
    C = loadConfigs(opts);
end
if isempty(C), fprintf('no configurations to evaluate\n'); return; end

%%
pm = progressMonitor(height(C),parallel=true);
forms   = C.form;
params  = C.params;
optPar  = opts.params;
regen   = opts.regenerate && ~opts.overwrite;
configs = C.config;
results = strings(height(C),1);

for i = 1:numel(forms)
    pm.update(i);
    if regen || isempty(configs(i).FinalConfig)
        mc = modeConfig(forms(i));
        c  = gmConfigurator(mc);
        c  = c.setParams(params(i));
        c  = c.setParams(optPar);
        configs(i) = c.genModeConfig();
    end
    results(i) = configs(i).FinalConfig.ToString();
end
C.config = configs;
C.result = results(:);
pm.reset();

C.match = C.target==C.result;

nLevels = max(arrayfun(@(c)max(abs(c.FinalConfig.Modes.Id)),C.config));

%%
switch(lower(opts.outputMode))
    case 'table'
        disp(C(:,["group" "form" "word" "match" "target" "result"]));
        fprintf('%1.1f (%d/%d) configurations matched target.\n',100*mean(C.match),sum(C.match),height(C));

    case 'strings'
        nCols = ceil(height(C)/opts.maxRows);
        nRows = ceil(height(C)/nCols);
        fig = stFig([nRows nCols],[0.01 0.01 0.01 0.035],[0.015 0.005]);
        for i=1:height(C)
            str = C.word(i)+":"+newline+C.target(i)+newline+C.result(i);
            th(i) = text(0,0,str,Interpreter='none');
            clickThroughAxes(fig.currentAxes,'on');
            set(fig.currentAxes,'ButtonDownFcn',@(~,~)C.config(i).inspect());
            fig.next();
        end
        set(th(~C.match),'Color','r');
        set(fig.Axes,'YLim',[-1 1],'Visible','off')
        set(th,'FontSize',14);


    otherwise
        fig = stFig(height(C),[0.01 0.01 0.01 0.035],[0.015 0.015]);

        for i=1:height(C)
            C.config(i).plotFinal(Height=nLevels);
            fig.next();
        end
        fig.labelAxes(fig.Axes,C.target,"nw",Interpreter="none",usePlotBox=false,FontSize=12);
        set(fig.AxesLabels(~C.match),'Color','r');
        set(fig.Axes,'Box','on','XColor','k','YColor','k');

end

end
