classdef articulae

    properties
        Phones
        Gestures
        Map
        Interactions
        Graph
        Phonotactics
        PhonotacticKeys
        PhoneReplacements
        dataPath = "data"+filesep
    end

    properties (Constant)         
        ClassLevels = categorical(["C";"V";"G";"N";"L";"R"], ["C" "V" "G" "N" "L" "R"], 'Ordinal', true);
        V = find(articulae.ClassLevels=="V"); %vocalic gesturals
        C = find(articulae.ClassLevels=="C"); %consonantal gesturals
        N = find(articulae.ClassLevels=="N"); %nasal gesturals
        G = find(articulae.ClassLevels=="G"); %glottal aperature (d-type only)
        L = find(articulae.ClassLevels=="L"); %laryngeal elevation
        R = find(articulae.ClassLevels=="R"); %lip rounding
        iType = ["V"; "C"];
        dType = ["N"; "G"; "L"; "R"];
    end

    methods
        function obj = articulae(subset)
            if nargin==0, subset = 'all'; end

            persistent cache cacheKey
            if isa(cache,'articulae') && istable(cache.Phones) && isequal(cacheKey,subset)
                obj = cache;
                return;
            end

            % Symb, Name and English are what the model uses; colname,
            % rowname, type and place only describe the phone. The
            % gesturals of each phone come from phoneGestureMap.csv.
            obj.Phones = tabcell2str(readtable(obj.dataPath+"phones.csv"));
            obj.Phones.Name(obj.Phones.Name=="") = obj.Phones.Symb(obj.Phones.Name=="");
            switch(subset)
                case 'English'
                    obj.Phones = obj.Phones(obj.Phones.English==1,:);
            end

            obj.Phones = obj.Phones;
            % gestures.csv carries the phonological inventory and the
            % task-dynamic parameters in one table; the extra columns
            % (TractSystem/Target/Stiffness/TDName) are tdModel's and are
            % simply unused here
            obj.Gestures = tabcell2str(readtable(obj.dataPath+"gestures.csv"));
            [tfC,cc] = ismember(obj.Gestures.Class, string(articulae.ClassLevels));
            cc = double(cc);
            cc(~tfC) = NaN;
            obj.Gestures.ClassCode = cc;
                        
            M = readcell(obj.dataPath+"phoneGestureMap.csv");
            mapGestures = string(M(1,2:end));
            mapPhones = string(M(2:end,1));
            map = cell2mat(M(2:end,2:end));

            [ix,ia] = ismember(obj.Gestures.Name,mapGestures);
            if any(~ix), error('ERROR: gestures %s missing from phone-gesture map\n',strjoin(obj.Gestures.Name(~ix),',')); end
            map = map(:,ia);
            
            [ix,ia] = ismember(obj.Phones.Name,mapPhones);
            if any(~ix), error('ERROR: phones %s missing from phone-gesture map\n',strjoin(obj.Phones.Name(~ix),',')); end
            obj.Map = logical(map(ia,:));
            
            obj.Interactions = obj.Gestures.Class==obj.Gestures.Class';

            persistent cachedPhonotactics
            if isempty(cachedPhonotactics)
               cachedPhonotactics = obj.readPhonotactics("phonotacticsEnglish.csv");
            end
            obj.Phonotactics = cachedPhonotactics;
            
            obj.Gestures.Id = uint8(1:height(obj.Gestures))';
            obj.Phonotactics.Ids = arrayfun(@(c,d){...
                [obj.Gestures.Id(obj.Gestures.Name==c) obj.Gestures.Id(obj.Gestures.Name==d)]},...
                obj.Phonotactics.G1,obj.Phonotactics.G2);

            P = vertcat(obj.Phonotactics.Ids{:});
            obj.PhonotacticKeys = double(P(:,1))*256 + double(P(:,2));

            repSets = arrayfun(@(c){obj.Gestures.Symb(obj.Map(c,:))'},...
                (1:height(obj.Phones))');

            PhoneReplacements.gestures = repSets;
            PhoneReplacements.phone = obj.Phones.Symb;
            obj.PhoneReplacements = struct2table(PhoneReplacements);

            if istable(obj.Phones) && istable(obj.Gestures) && ~isempty(obj.Map)
                cacheKey = subset;
                cache = obj;
            end
        end

        function gests = PhonesToGests(obj,phoneSeq)
            
            phonesFull = string(strsplit(phoneSeq,' ')');
            % only a leading ~ is a marker; a trailing one belongs to
            % the name of a nasal vowel (ae~, ax~)
            phones = regexprep(phonesFull,'~(.+)','$1');
            % compare in decomposed form, so a precomposed vowel (U+00E3) matches
            % the diacritic spelling stored in Symb
            phones = articulae.nfd(phones);

            % A phone may be typed by its Name -- the ASCII input token,
            % which is also the key of phoneGestureMap -- or by its IPA
            % Symb. Name wins where the two collide: "r" is the name of
            % [ɹ] and also the symbol of the alveolar trill.
            [known,rowIx] = ismember(phones,articulae.nfd(obj.Phones.Name));
            [bySymb,symbIx] = ismember(phones,articulae.nfd(obj.Phones.Symb));
            takeSymb = ~known & bySymb;
            rowIx(takeSymb) = symbIx(takeSymb);
            known = known | bySymb;
            if any(~known)
                error('articulae:unknownPhone', ...
                    'ERROR: unknown phone: %s', strjoin(phones(~known),', '));
            end

            % A phone can sit in the inventory without having been
            % decomposed into gestures yet -- the clicks, for instance.
            % Asking for one in an input string is an error; validateData
            % reports the same condition as a warning.
            unspec = unique(phones(~any(obj.Map(rowIx,:),2)),'stable');
            if ~isempty(unspec)
                error('articulae:gesturesNotSpecified', ...
                    'ERROR: phone gesturals not specified in map: %s', ...
                    strjoin(unspec,', '));
            end

            gests = {};
            for i=1:length(phones)
                mapCols = find(obj.Map(rowIx(i),:));
                names = obj.Gestures.Name(mapCols)';
                if extractBetween(phonesFull(i),1,1)=="~"
                    isV = obj.Gestures.ClassCode(mapCols)' == articulae.V;
                    names(isV) = "~" + names(isV);
                end
                gests{i} = names;
            end
        end

        function p = plotter(obj)
            p = articulaePlot(obj);
        end

        function [m] = plotPhoneGestureMap(obj,varargin)
            m = obj.plotter().plotPhoneGestureMap(varargin{:});
        end
    end

    methods (Static)

        function gests = phonesToGests(phoneSeq)
            % static convenience form of PhonesToGests, over the full inventory
            gests = articulae().PhonesToGests(phoneSeq);
        end

        function s = nfd(s)
            % Unicode canonical decomposition, so a precomposed vowel and
            % a vowel plus combining diacritic compare equal.
            s = string(s);
            for k = 1:numel(s)
                if ismissing(s(k)), continue; end
                s(k) = string(char(javaMethod('normalize','java.text.Normalizer', ...
                    java.lang.String(char(s(k))), ...
                    javaMethod('valueOf','java.text.Normalizer$Form','NFD'))));
            end
        end

        function str = toIPA(str)
            Artic = articulae();
            % one lookup per space-separated token, so a symbol produced
            % for one token is never re-read as another token's name
            % ("tr" -> r, the trill, not on to ɹ via the token "r")
            wasChar = ischar(str);
            str = string(str);
            for k = 1:numel(str)
                if ismissing(str(k)), continue; end
                t = split(str(k)," ");
                [tf,ix] = ismember(t,Artic.Phones.Name);
                t(tf) = Artic.Phones.Symb(ix(tf));
                str(k) = join(t," ");
            end
            if wasChar, str = char(str); end
        end

        function [phonotactics] = readPhonotactics(file)
            opts = detectImportOptions(which(file));
            opts.VariableNamesLine = 0;
            opts.DataLines = [1 inf];
            opts = setvartype(opts,'char');
            P = tabread(which(file),opts);
            g = P{1,2:end};
            p = table2array(P(2:end,2:end));
            [r,c] = find(p~="");
            for i=1:numel(r)
                phonotactics(i).G1 = g(r(i));
                phonotactics(i).G2 = g(c(i));
            end
            phonotactics = struct2table(phonotactics(:));
        end
        
    end

end