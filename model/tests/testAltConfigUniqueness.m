function testAltConfigUniqueness()
% Candidate-state uniqueness, stable ordering, opt-out and current exclusion.
cfg = gmConfigurator(modeConfig("p i t"));
cfg = cfg.genModeConfig();
sawDuplicates = false;
for c = cfg.IterConfigs(:)'
    raw = gmConfigurator.getAltConfigs(c,unique=false);
    actual = gmConfigurator.getAltConfigs(c);
    rawKeys = keys(raw);
    expected = unique(rawKeys,'stable');
    assert(isequal(keys(actual),expected));
    sawDuplicates = sawDuplicates || numel(rawKeys)>numel(expected);
    assert(sum(keys(actual)==keys(c))==1);
    excluded = gmConfigurator.getAltConfigs(c,false);
    assert(~any(keys(excluded)==keys(c)));
    rawExcluded = gmConfigurator.getAltConfigs(c,false,unique=false);
    assert(isequal(keys(rawExcluded),rawKeys(rawKeys~=keys(c))));
end
assert(sawDuplicates,'Fixture must exercise duplicate candidate transitions.');
disp('PASS: unique default, stable ordering, duplicate opt-out, and current-state exclusion');
end
function result = keys(configs)
result = arrayfun(@(c)string(mat2str( ...
    [c.Excitations.ModeId(:),c.Excitations.Phase(:)],17)),configs);
result = result(:);
end
