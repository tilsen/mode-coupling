function [] = axrescalex(varargin)

if nargin==0
    rsvals = [-0.01 0.01];
    ax = gca;
elseif nargin==1
    ax = gca;
    rsvals = varargin{1};
else
    if ishandle(varargin{1})
        ax = varargin{1};
        rsvals = varargin{2};
    else
        rsvals = varargin{1};
        ax = varargin{2};
    end
end

if numel(ax)>1

    ax = ax(:);
    for j=1:length(ax)
        axrescalex(rsvals,ax(j));
    end
    return;
end

if isscalar(rsvals), rsvals=rsvals*[-1 1]; end


xlims = get(ax,'xlim');
set(ax,'xlim',xlims+diff(xlims)*rsvals);

end

