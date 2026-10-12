function makeFigures(opts)
% MAKEFIGURES  Render every figure and code output used by README.md.
%
%   makeFigures()                 % write figs/ at the repo root
%   makeFigures(Resolution=200)   % higher-DPI PNGs
%   makeFigures(Seed=7)           % a different stochastic run
%
% Run it headless, which is how the committed figures were made:
%
%   matlab -noFigureWindows -batch "addpath('tools'); makeFigures"
%
% Figures go through exportgraphics() rather than the Live Editor's
% offscreen capture, which mis-scales wide figures unpredictably when
% running under -noFigureWindows.

arguments
    opts.OutDir (1,1) string = ""
    opts.Resolution (1,1) double = 150
    opts.Seed (1,1) double = 0
end

root = string(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(root));

if opts.OutDir == "", opts.OutDir = fullfile(root,"figs"); end
if ~isfolder(opts.OutDir), mkdir(opts.OutDir); end

% gmConfigurator's default method is bonding_stochastic, so pin the stream
% to keep the committed figures reproducible
rng(opts.Seed);

% stFig sizes figures from the screen only when it thinks it is in a Live
% Script; force that on so headless runs get the same geometry (and hence
% the same fitted font sizes) as an interactive session. Restored on exit
% so it cannot leak into the calling session.
prevOverride = getenv('STFIG_LIVESCRIPT_OVERRIDE');
setenv('STFIG_LIVESCRIPT_OVERRIDE','1');
restoreOverride = onCleanup(@() setenv('STFIG_LIVESCRIPT_OVERRIDE',prevOverride)); %#ok<NASGU>

shot = @(fig,name,pad) writeFigure(fig,opts.OutDir,name,opts.Resolution,pad);

A = articulae('English');

%% ---- mode configuration -------------------------------------------------
mc = modeConfig("s p a ~i t");
gm = gmConfigurator(mc).genModeConfig();

section('gm.FinalConfig.ToString()');
disp(gm.FinalConfig.ToString());

% A small figure with explicit font sizes: the ratio-based defaults scale
% with the figure, which makes a single configuration enormous. exportgraphics
% crops to the drawn content, so the blank border is added as export padding.
finalFig = stFig(1,[0.08 0.08 0.08 0.14],Aspect=2);
set(finalFig.Handle,'Units','inches','Position',[1 1 6 4.5]); drawnow;
gm.plotFinal(Parent=finalFig.Axes,SystemSymbolFontSize=28,ModeLabelFontSize=28, ...
    PanelLabelFontSize=30,HorizontalSpacing=0.5);
shot(finalFig.Handle,"final-config",50);
iterFig = stFig(1,[0.01 0.03 0.01 0.07]);
gm.plotIters(Parent=iterFig.Axes,PanelLabelFontSize=34,intMargins=[0.04 0.12]); shot(iterFig.Handle,"iterations",100);

%% ---- articulae ----------------------------------------------------------
section('head(A.Gestures)');
disp(head(A.Gestures));
fprintf('  ... %d gestures total (data/gestures.csv)\n',height(A.Gestures));

section('head(A.Phones)');
disp(head(A.Phones));
fprintf('  ... %d phones total (data/phones.csv)\n',height(A.Phones));

mapFig = stFig(1,[0.05 0.02 0.01 0.20]);
set(mapFig.Handle,'Units','inches'); mapPos = mapFig.Handle.Position;
set(mapFig.Handle,'Position',[mapPos(1:3) 13]); drawnow;   % taller than the screen-derived default
A.plotPhoneGestureMap(Parent=mapFig.Axes);
set(mapFig.Axes,'FontSize',16);
shot(mapFig.Handle,"phone-gesture-map","tight");

section('A.phonesToGests("p ih t")');
cellfun(@(c)disp(strjoin(c,', ')),A.phonesToGests("p ih t"));

%% ---- testing ------------------------------------------------------------
section('evalConfigs');
evalConfigs(overwrite=true);

%% ---- mode-selection dynamics --------------------------------------------
ms = modeSelection(gm.FinalConfig).initSim().simulate();
selectionFig = stFig(1,Aspect=1.8);
ms.plot(Parent=selectionFig.Handle,panelLabelFontSize=22,fieldLabelFontSize=22,tickFontSizeDelta=2);
shot(selectionFig.Handle,"mode-selection",70);

fprintf('\nFigures written to %s\n',opts.OutDir);

end

% -------------------------------------------------------------------------
function writeFigure(f,outDir,name,res,pad)
drawnow;
file = fullfile(outDir,name+".png");
exportgraphics(f,file,'Resolution',res,'Padding',pad);
close(f);
d = dir(file);
fprintf('  wrote %-22s %6.0f KB\n',name+".png",d.bytes/1024);
end

function section(str)
fprintf('\n===== %s =====\n',str);
end
