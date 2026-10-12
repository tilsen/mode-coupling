function [ok,issues] = validateData(opts)
%VALIDATEDATA  Cross-check the CSV files in data/ against each other.
%
%   validateData()                  print a report for the data/ on the path
%   ok = validateData()             true when nothing of severity "error" was found
%   [ok,issues] = validateData()    issues is a table of every finding
%   validateData(verbose=false)     stay quiet and just return
%   validateData(dataPath=d)        validate the CSV files in directory d
%
%   The CSV files in data/ are the source of truth for the phone, gesture,
%   tract-system and phonotactic inventories, and articulae is what reads
%   them. This checks the correspondences articulae depends on, and also
%   the ones it silently tolerates.
%
%   Severity "error" means articulae will throw, or will quietly drop data
%   on the floor. Severity "warning" means the files disagree in a way the
%   model currently survives but which is probably not intended.
%
%   See also ARTICULAE.

arguments
    opts.dataPath (1,1) string = ""
    opts.verbose (1,1) logical = true
end

if opts.dataPath==""
    f = which('phones.csv');
    if isempty(f)
        error('validateData:noData','phones.csv is not on the MATLAB path');
    end
    opts.dataPath = string(fileparts(f)) + filesep;
end
d = opts.dataPath;

rows = cell(0,4);

%% ----------------------------------------------------------------- load
G = tabread(d+"gestures.csv");
P = tabread(d+"phones.csv");
T = tabread(d+"tractSystems.csv");
W = tabread(d+"defaultWeights.csv");
C = tabread(d+"configs.csv");

% articulae falls back to Symb when Name is blank, and the map is keyed on
% the result, so validate against the same key articulae will use.
P.Name(P.Name=="") = P.Symb(P.Name=="");

M = readcell(d+"phoneGestureMap.csv");
mapGestures = string(M(1,2:end));
mapPhones = string(M(2:end,1));
mapVals = cellfun(@cellValue,M(2:end,2:end));

X = readcell(d+"phonotacticsEnglish.csv");
ptCols = string(X(1,2:end));
ptRows = string(X(2:end,1));
ptVals = cellfun(@cellValue,X(2:end,2:end));

gNames = string(G.Name);
pNames = string(P.Name);
pSymbs = string(P.Symb);
symbs  = string(G.Symb);
isEng  = P.English==1;
% articulae resolves an input token against Name first and then against
% the IPA Symb, so both spellings are legitimate input.
pKeys  = [pNames; pSymbs];
engKey = [pNames(isEng); pSymbs(isEng)];
hasTd  = filled(G.TractSystem);

%% -------------------------------------------------------- A. unique keys
rows = dupes(rows,gNames,"gestures.csv","gesture Name");
rows = dupes(rows,pNames,"phones.csv","phone Name");
rows = dupes(rows,mapGestures,"phoneGestureMap.csv","map column");
rows = dupes(rows,mapPhones,"phoneGestureMap.csv","map row");

rows = add(rows,"error","blank key","gestures.csv", ...
    gNames(gNames==""),"gesture row has no Name");
rows = add(rows,"error","blank key","phones.csv", ...
    pNames(pNames==""),"phone row has neither Name nor Symb");

fellBackToSymb = pNames==pSymbs;
rows = add(rows,"warning","non-ascii phone Name","phones.csv", ...
    pNames(isEng & fellBackToSymb & arrayfun(@(s)any(double(char(s))>127),pNames)), ...
    "English phone falls back to a non-ascii Symb; give it an ascii Name so it stays typeable");

%% ----------------------------------------------- B. gestures <-> columns
rows = add(rows,"error","gesture missing from map","gestures.csv", ...
    setdiff(gNames,mapGestures), ...
    "no column in phoneGestureMap.csv; articulae errors on this");

rows = add(rows,"error","orphan map column","phoneGestureMap.csv", ...
    setdiff(mapGestures,gNames), ...
    "no row in gestures.csv, so articulae drops the column silently");

%% -------------------------------------------------- C. phones <-> rows
rows = add(rows,"error","phone missing from map","phones.csv", ...
    setdiff(pNames,mapPhones), ...
    "no row in phoneGestureMap.csv; articulae errors on this");

rows = add(rows,"error","orphan map row","phoneGestureMap.csv", ...
    setdiff(mapPhones,pNames), ...
    "matches no phone in phones.csv");

%% ---------------------------------------------------------- D. map body
[r,c] = find(~ismember(mapVals,[0 1]));
for i=1:numel(r)
    rows = add(rows,"error","bad map value","phoneGestureMap.csv", ...
        mapPhones(r(i))+" / "+mapGestures(c(i)),"cell is neither 0 nor 1");
end

%% ----------------------------------------------------------- E. coverage
for nm = intersect(mapPhones,pNames)'
    if ~any(mapVals(mapPhones==nm,:)==1)
        if any(isEng & pNames==nm)
            rows = add(rows,"error","phone with no gestures", ...
                "phoneGestureMap.csv",nm, ...
                "maps to no gestures but is flagged English");
        else
            rows = add(rows,"warning","phone with no gestures", ...
                "phoneGestureMap.csv",nm,"maps to no gestures");
        end
    end
end

rows = add(rows,"warning","gesture used by no phone","gestures.csv", ...
    setdiff(intersect(gNames,mapGestures),mapGestures(any(mapVals==1,1))), ...
    "in the inventory but no phone maps to it");

%% ------------------------------------------------------ F. tract systems
tNames = string(T.Name);
usedTs = unique(string(G.TractSystem(hasTd)));

rows = dupes(rows,tNames,"tractSystems.csv","tract system Name");
rows = add(rows,"error","undeclared tract system","gestures.csv", ...
    setdiff(usedTs,tNames),"TractSystem is not a row of tractSystems.csv");
rows = add(rows,"warning","unused tract system","tractSystems.csv", ...
    setdiff(tNames,usedTs),"declared but no gesture uses it");

%% ------------------------------------------ G. task-dynamic completeness
for i = find(hasTd)'
    miss = strings(0,1);
    if ~filled(G.Target(i)),    miss(end+1) = "Target";    end %#ok<AGROW>
    if ~filled(G.Stiffness(i)), miss(end+1) = "Stiffness"; end %#ok<AGROW>
    if ~filled(G.TDName(i)),    miss(end+1) = "TDName";    end %#ok<AGROW>
    if ~isempty(miss)
        rows = add(rows,"error","incomplete task-dynamic block","gestures.csv", ...
            gNames(i),"has a TractSystem but no "+strjoin(miss,", "));
    end

    s = G.Stiffness(i);
    if filled(s) && ~isnumeric(s) && ~ismember(string(s),["C" "V"])
        rows = add(rows,"error","bad Stiffness","gestures.csv", ...
            gNames(i),"Stiffness is neither numeric nor C/V");
    end
end

tdNames = string(G.TDName(hasTd));
tdNames = tdNames(tdNames~="" & ~ismissing(tdNames));
rows = dupes(rows,tdNames,"gestures.csv","TDName");
rows = add(rows,"warning","non-ascii TDName","gestures.csv", ...
    tdNames(arrayfun(@(s)any(double(char(s))>127),tdNames)), ...
    "scores are written against TDName, so keep it typeable");

%% ------------------------------------------------- H. domains and symbols
rows = add(rows,"error","bad Class","gestures.csv", ...
    setdiff(string(G.Class),string(articulae.ClassLevels)), ...
    "not one of "+strjoin(string(articulae.ClassLevels),"/"));

rows = dupes(rows,symbs(symbs~=""),"gestures.csv","gesture Symb", ...
    "warning","symbol is shared, so configuration strings are ambiguous");

%% --------------------------------------------------------- I. phonotactics
rows = add(rows,"error","unknown phonotactic label","phonotacticsEnglish.csv", ...
    setdiff(ptCols,gNames),"column is not a gesture in gestures.csv");
rows = add(rows,"error","unknown phonotactic label","phonotacticsEnglish.csv", ...
    setdiff(ptRows,gNames),"row is not a gesture in gestures.csv");
if ~isequal(ptCols(:),ptRows(:))
    rows = add(rows,"error","phonotactics not square","phonotacticsEnglish.csv", ...
        "matrix","row labels and column labels differ");
end
if any(~ismember(ptVals(:),[0 1]))
    rows = add(rows,"warning","bad phonotactic value","phonotacticsEnglish.csv", ...
        "matrix","cells should be blank or 1");
end

%% ---------------------------------------------------------- J. configs.csv
toks = string.empty(0,1);
for i=1:height(C)
    t = split(strtrim(string(C.form(i))));
    toks = [toks; t(t~="")]; %#ok<AGROW>
end
% modeConfig strips "^" (accentuation) before lookup, and PhonesToGests
% strips a leading "~" (nasalization); mirror both here.
toks = unique(regexprep(erase(toks,"^"),'~(.+)','$1'));
rows = add(rows,"error","unknown phone in configs","configs.csv", ...
    setdiff(toks,pKeys),"token is neither a Name nor a Symb in phones.csv");
rows = add(rows,"warning","non-English phone in configs","configs.csv", ...
    intersect(setdiff(toks,engKey),pKeys), ...
    "is a phone but is not flagged English");

%% ------------------------------------------------------ K. defaultWeights
wTerms = string(W.term);
rows = dupes(rows,wTerms,"defaultWeights.csv","weight term");
rows = add(rows,"error","weight term mismatch","defaultWeights.csv", ...
    setdiff(gmConfigurator.EnergyTerms,wTerms), ...
    "energy term of gmConfigurator has no row");
rows = add(rows,"error","weight term mismatch","defaultWeights.csv", ...
    setdiff(wTerms,gmConfigurator.EnergyTerms), ...
    "row is not an energy term of gmConfigurator");
rows = add(rows,"error","bad weight","defaultWeights.csv", ...
    wTerms(~isfinite(W.value)),"value is not a finite number");

%% -------------------------------------------------------- L. text damage
% A CSV round-tripped through a spreadsheet in the wrong encoding comes
% back with U+FFFD where the IPA used to be.
fields = [gNames; symbs; pNames; string(P.Symb); mapGestures(:); mapPhones(:)];
rows = add(rows,"error","encoding damage","data/", ...
    unique(fields(contains(fields,char(65533)))), ...
    "contains U+FFFD, so a file was saved in the wrong encoding");

%% -------------------------------------------------------------- report
issues = buildTable(rows);
ok = ~any(issues.Severity=="error");

if opts.verbose
    printReport(issues,ok,d);
end

if nargout==0
    clear ok
end

end

% =========================================================================

function rows = add(rows,sev,check,file,subjects,note)
subjects = string(subjects);
subjects = subjects(subjects~="" & ~ismissing(subjects));
for i=1:numel(subjects)
    rows(end+1,:) = {string(sev),string(check),string(file), ...
        legible(subjects(i))+" -- "+string(note)}; %#ok<AGROW>
end
end

function s = legible(s)
% These tables are full of IPA, and the report is often read through a
% console or log that cannot render it. Spell out the code points so a
% finding stays identifiable even when the glyphs do not survive.
c = double(char(s));
if any(c>127)
    s = s + " [" + strjoin("U+"+string(dec2hex(c,4)),' ') + "]";
end
end

function rows = dupes(rows,names,file,what,sev,note)
if nargin<5, sev = "error"; end
if nargin<6, note = "occurs more than once"; end
names = names(:);
[u,~,ix] = unique(names);
rows = add(rows,sev,"duplicate "+what,file,u(accumarray(ix,1)>1),note);
end

function t = buildTable(rows)
names = {'Severity','Check','File','Detail'};
if isempty(rows)
    t = table(strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
        'VariableNames',names);
    return
end
t = cell2table(rows,'VariableNames',names);
for i=1:numel(names)
    t.(names{i}) = string(t.(names{i}));
end
[~,ord] = sortrows([double(t.Severity=="warning") (1:height(t))']);
t = t(ord,:);
end

function v = cellValue(c)
% readcell leaves blanks as missing; treat those as 0 and anything
% unparseable as -1 so the domain check catches it.
if isnumeric(c) && isscalar(c)
    v = double(c);
elseif all(ismissing(c))
    v = 0;
else
    n = str2double(string(c));
    if isnan(n), v = -1; else, v = n; end
end
end

function tf = filled(v)
% true where a table value is present and non-empty, for numeric or text
if isnumeric(v)
    tf = ~isnan(v);
else
    tf = ~ismissing(v) & string(v)~="";
end
end

function printReport(issues,ok,d)
fprintf('\nvalidateData: %s\n',d);
if isempty(issues)
    fprintf('  no issues found\n\n');
    return
end
lastCheck = "";
for i=1:height(issues)
    if issues.Check(i)~=lastCheck
        fprintf('\n  [%s] %s (%s)\n',upper(issues.Severity(i)), ...
            issues.Check(i),issues.File(i));
        lastCheck = issues.Check(i);
    end
    fprintf('      %s\n',issues.Detail(i));
end
if ok, verdict = "PASS"; else, verdict = "FAIL"; end
fprintf('\n  %d error(s), %d warning(s) -- %s\n\n', ...
    sum(issues.Severity=="error"),sum(issues.Severity=="warning"),verdict);
end
