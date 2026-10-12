function testDataIntegrity()
% The CSV files in data/ must agree with each other.
%
% validateData reports two severities. Errors mean articulae will throw or
% will silently drop data, and are never acceptable. Warnings record
% inventory decisions that are currently open, so they are listed but do
% not fail the test.

[ok,issues] = validateData(verbose=false);

errs = issues(issues.Severity=="error",:);
if ~isempty(errs)
    fprintf('\n%d data error(s):\n',height(errs));
    fprintf('  %s (%s)\n',[errs.Detail errs.File]');
end
assert(ok,'data/ CSV files are inconsistent; run validateData for the report');

warns = issues(issues.Severity=="warning",:);
if ~isempty(warns)
    fprintf('%d open warning(s); run validateData for detail\n',height(warns));
end

disp('PASS: phone, gesture, tract-system, phonotactic and weight tables agree');
end
