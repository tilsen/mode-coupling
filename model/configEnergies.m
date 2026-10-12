function [cE] = configEnergies(config,weights,opts)
arguments
    config
    weights
    opts.antiphaseCost = 2/3
    opts.metricalEnergyWeight = 1/2
    opts.halt = false
    opts.dbstop = false    
end

if opts.dbstop, dbstop if error; end

E = config.Excitations;
M = config.Modes;
nM = height(config.Modes);
nE = height(config.Excitations);

eId    = double(E.Id);
eMode  = E.ModeId;
ePhase = E.Phase;
eClass = E.Class;
eType  = E.Type;
eSign  = E.Sign;
eAct   = E.Activation;
eQ     = E.qState;
mId    = M.Id;
mSign  = M.Sign;
mAct   = M.metricalAct;
%coupled = ~isnan(eMode);

firstMode = [true; false(nM-1,1)];
%lastMode = [false(nM-1,1); true];

%phonotatics:

pKey = config.Articulae.PhonotacticKeys;
gKey = double(eId)*256 + double(eId.');

%coupling matrix:
[em,modeRow] = ismember(eMode,mId);
cm = sparse(modeRow(em),find(em),1,nM,nE);

%gestural relation matrices:
phi = sign(ePhase-ePhase'); %phasing
sameMode = eMode==eMode' & ~isnan(eMode);
sameMode(logical(eye(nE))) = 0;
sameState = phi==0 & sameMode;
zeroPlus = (sign(eMode)==1)&(sign(eMode')==1) & (ePhase==0)&(ePhase'==0);

%mode state vectors:
negM = (mSign==-1);
posM = (mSign==1);
modeE = abs(mId) + (mId<0)*opts.antiphaseCost;

%metrical effects
modeE = modeE - opts.metricalEnergyWeight*mAct;

%excitation state vectors:
rS = eMode*8 + eClass;

%excitation classes (only coupled excitations):
isV = eClass==articulae.V & ~isnan(eMode);
isC = eClass==articulae.C & ~isnan(eMode);
isVp = isV & eSign~=-1;
isVn = isV & eSign==-1;
isI = eType==1 & ~isnan(eMode); %i-type
isD = eType==0 & ~isnan(eMode); %d-type

%state comparison operators (self-excluding):
I = @(c)(c==c').*(1-eye(nE)); 

%% unbound gestural energy
    function [Y] = unbound_energy()
        Y = sum(eAct(~em | isnan(eMode)))*firstMode;
    end

%% bound gestural energy
    function [Y] = bound_energy()
        Y = full(sum(modeE.*cm.*isI',2));
    end

%% exclusion principle energy
    function [Y] = exclusion_energy()        
        Y = cm*(sum(I(eQ)&~zeroPlus))';        
    end

%% nucleus occupation energy
    function [Y] = nucleic_energy()        
        Y = (((cm*isVp)~=1) + (cm*isVn)) .* posM;        
    end

%% frequency adaptation energy
    function [Y] = adaptation_energy()
        
        modeA = full(cm).*eAct';
        modeA(modeA==0) = nan;

        modeV = full(cm).*(eAct.*isV)';
        modeV(modeV==0) = nan;
        
        modeFloor = min(modeV,[],2);
        modeFloor(2:2:end-1) = modeFloor(3:2:end);
        
        modeFloor(isnan(modeFloor)) = 0;
        modeFloor(end) = 0;
        viol = modeA<modeFloor;
        Y = sum(viol,2);
    end

%% energy of d-type in a state that is unoccupied by an i-type
    function [Y] = dependency_energy()        
        viol = isD & sum((isD & isI').*sameState,2)==0;
        Y = cm*viol;
    end

%% energy of phonotactic violation
    function [Y] = phonotactic_energy()
        viol = (I(rS) .* ismember(gKey,pKey)) .* phi>0;
        Y = cm*sum(viol,2);
    end

%% energy of coupling to {-} modes
    function [Y] = phasebias_energy()
        Y = full(cm*(isD|isC)) .* negM;
    end

%% 
energyTerms = { ...
    'nucleic'      , ...    
    'exclusion'    , ...
    'dependency'   , ...  
    'phasebias'    , ...
    'adaptation'   , ...
    'phonotactics' , ...  
    'bound'        , ...
    'unbound'};   % should be in same order as gmConfigurator.EnergyTerms()

%check that energy terms are in correct order
persistent checked
if isempty(checked)
    assert(isequal(string(energyTerms(:)), gmConfigurator.EnergyTerms(:)), ...
        'configEnergies:termOrder', ...
        'column order disagrees with gmConfigurator.EnergyTerms');
    checked = true;
end

X = [ ...    
    nucleic_energy()    , ...    
    exclusion_energy()  , ...
    dependency_energy() , ... 
    phasebias_energy()  , ...
    adaptation_energy() , ...
    phonotactic_energy(), ...    
    bound_energy()      , ...
    unbound_energy()];     % nM×K

cE.X = X;
cE.totalE = sum(X*weights');

if opts.halt
    cE.modeEnergies = X.*weights;
    cE.energyTerms = energyTerms;
    cE.weights = weights;    
    disp(config.Excitations);
    disp(gmConfigurator.energiesTable(cE));   
    keyboard; %#ok<KEYBOARDFUN>
end

end