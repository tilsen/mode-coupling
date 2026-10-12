function testPhoneSeqMarkers()
% Input-string markers: ^ (accentuation) and + (length).
%
% "+" adds a non-nucleic copy of the phone after it, and the ^ count must
% stay aligned with the expanded phone list (it used to be counted on the
% unexpanded string, so any "+" made repelem fail).

% length: "a+" -> a, ~a
mc = modeConfig("b a+ n a");
v = mc.Excitations(mc.Excitations.Class==articulae.V,:);
assert(height(v)==3, 'a+ should give two excitations of a, plus the final a');
assert(sum(v.Sign==-1)==1, 'the lengthened copy should be non-nucleic (Sign -1)');

% accentuation stays on the nucleic half of a lengthened phone,
% whichever order the markers are written in
for form = ["p a^+ t" "p a+^ t"]
    mc = modeConfig(form);
    v = mc.Excitations(mc.Excitations.Class==articulae.V,:);
    assert(isequal(sort(v.Accentuation(v.Sign==1)),1) && all(v.Accentuation(v.Sign==-1)==0), ...
        '%s: ^ should accent only the nucleic a',form);
end

% "+" works on tokens that are not plain ASCII word characters
mc = modeConfig("p ɪ+ t");
assert(sum(mc.Excitations.Class==articulae.V)==2, 'ɪ+ should expand like a+');

% and on two lengthened phones in one string
mc = modeConfig("b a+ n a+");
assert(sum(mc.Excitations.Sign==-1)==2, 'each + adds one non-nucleic copy');

disp('PASS: length (+) expansion and accentuation (^) alignment');
end
