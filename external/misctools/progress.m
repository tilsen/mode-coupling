function [status_str] = progress(varargin)

status_exists = evalin('caller','exist(''status_str'',''var'')');

%% no input: clear:
if nargin==0
    if status_exists
        len_status = evalin('caller','length(status_str)');
        fprintf(repmat('\b',1,len_status));
        evalin('caller','clear(''status_str'')');        
    end
    return;
end

%% determine input mode
if ischar(varargin{1})
    umode = varargin{1};

else

    if status_exists
        len_status = evalin('caller','length(status_str)');
        umode = 'update';
    else
        len_status = 0;
        umode = 'init';
    end    
    iter = varargin{1};
    total = varargin{2};
    descr_str = 'processing:';
    if numel(varargin)>=3
        descr_str = [varargin{3} ' '];
    end


end

%% progress updates
%start tic if necessary
tic_exists = evalin('caller','exist(''progress_tic'',''var'')');
time_hdr = 'time per iter:';  
elap_hdr = 'elapsed time:';
est_hdr = 'time remaining:';  
iter_hdr = 'iteration:';     

switch(umode)
    case 'init'
        evalin('caller','progress_tic=tic;');
        time_str = 'n/a';
        elap_str = sprintf('%1.1f',0);
        est_str = 'n/a';
        iter_str = sprintf('%i/%i',iter,total);

    case 'update'
        elapsed_t = evalin('caller','toc(progress_tic)');
        time_per_iter = elapsed_t/(iter-1);
        est_remaining = time_per_iter*(total-iter);
        time_str = sprintf('%1.2f',time_per_iter);
        elap_str = sprintf('%1.1f',elapsed_t);
        est_str = sprintf('%1.1f',est_remaining);
        iter_str = sprintf('%i/%i',iter,total);
end

%% output conditions
switch(umode)

    case 'summarize'
        fprintf('\nTotal time: %1.1f\n',elapsed_t);
        evalin('caller','clear(''status_str'')'); 
        
    case {'update','init'}
        hdrs = strjust(cell2mat(pad({iter_hdr;time_hdr;elap_hdr;est_hdr})),'right');
        vals = strjust(cell2mat(pad({iter_str; time_str; elap_str; est_str})),'left');
        lines = cellstr([hdrs repmat(' ',size(hdrs,1),1) vals]);
        lines = [{descr_str}; lines];
        status_str = strjoin(lines,'\n');
        fprintf([repmat('\b',1,len_status) '%s'],status_str);     

    case 'reset'
        if status_exists            
            fprintf('\n');
        end

    case 'clear'
        if status_exists
            len_status = evalin('caller','length(status_str)');
            fprintf(repmat('\b',1,len_status));
            evalin('caller','clear(''status_str'')');
        end
end

end


