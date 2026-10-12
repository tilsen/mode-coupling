function runAllTests()
% Run every test*.m in this folder; each prints PASS or throws. Errors at
% the end if any test failed.
d = dir(fullfile(fileparts(mfilename('fullpath')),'test*.m'));
failed = strings(0,1);
for k = 1:numel(d)
    name = erase(string(d(k).name),".m");
    try
        feval(name);
    catch err
        fprintf('FAIL: %s -- %s\n',name,err.message);
        failed(end+1) = name; %#ok<AGROW>
    end
end
fprintf('%d of %d tests passed\n',numel(d)-numel(failed),numel(d));
if ~isempty(failed)
    error('runAllTests:failed','failed: %s',strjoin(failed,', '));
end
end
