function lh = clickThroughAxes(ax, state)
%CLICKTHROUGHAXES  Route every click inside an axes to its ButtonDownFcn.
%
%   CLICKTHROUGHAXES(AX) makes every descendant of AX (lines, patches,
%   images, surfaces, text, ...) transparent to the mouse by setting
%   HitTest to 'off', so a click on any of them is forwarded up to AX and
%   fires AX.ButtonDownFcn. AX itself is set to PickableParts = 'all' so
%   that clicks on empty background register too, even when the axes Color
%   is 'none'. An ObjectChildAdded listener keeps new children transparent
%   as they appear, so you only need to call this once per axes.
%
%   CLICKTHROUGHAXES(AX,'off') undoes it: the listener is deleted, HitTest
%   is set back to 'on' everywhere, and PickableParts returns to 'visible'.
%
%   LH = CLICKTHROUGHAXES(...) returns the listener(s), for the rare case
%   where you want to delete or disable them yourself.
%
%   AX may be an array of axes. Defaults to GCA if omitted.
%
%   Example:
%       ax = axes; hold on
%       plot(rand(1,20)); imagesc(rand(5)); text(2, 2, 'hello')
%       ax.ButtonDownFcn = @(s,e) disp(e.IntersectionPoint(1:2));
%       clickThroughAxes(ax)
%
%   Notes:
%     * HitTest = 'off' forwards the pick to the ancestor. The alternative,
%       PickableParts = 'none', makes an object invisible to the mouse
%       entirely, so whatever sits behind it gets picked instead. For a
%       flat 2-D axes both end up at the axes; with stacked or 3-D objects
%       they differ, so swap the property below if you want that behavior.
%     * If clicks still do nothing, check that no figure interaction mode
%       is active (zoom/pan/datacursor/brush all swallow ButtonDownFcn),
%       and on R2018b+ consider disableDefaultInteractivity(ax).
%     * Children added to a nested hggroup/transform after the group is
%       already parented won't fire the axes' ObjectChildAdded event; call
%       clickThroughAxes again if you build hierarchies that way.

if nargin < 1 || isempty(ax),    ax = gca;      end
if nargin < 2 || isempty(state), state = 'on';  end
state = validatestring(state, {'on','off'});

lh = event.listener.empty;

for k = 1:numel(ax)
    a = ax(k);
    if ~isgraphics(a, 'axes')
        error('clickThroughAxes:notAxes', ...
              'Input %d is not an axes handle.', k);
    end

    % Drop any listener left over from a previous call on this axes.
    if isappdata(a, 'ClickThroughListener')
        old = getappdata(a, 'ClickThroughListener');
        if isa(old, 'event.listener') && isvalid(old)
            delete(old);
        end
        rmappdata(a, 'ClickThroughListener');
    end

    switch state
        case 'on'
            a.PickableParts = 'all';
            setHit(a, 'off');
            l = addlistener(a, 'ObjectChildAdded', ...
                            @(~, evt) setHit(evt.Child, 'off'));
            setappdata(a, 'ClickThroughListener', l);
            lh(end+1) = l; %#ok<AGROW>

        case 'off'
            a.PickableParts = 'visible';
            setHit(a, 'on');
    end
end
end

% -------------------------------------------------------------------------
function setHit(root, val)
% Set HitTest on ROOT and all of its descendants, skipping any axes.
objs = findall(root, '-property', 'HitTest');
objs(isgraphics(objs, 'axes')) = [];
if isempty(objs), return; end

try
    set(objs, 'HitTest', val);
catch
    % A few objects expose HitTest read-only; fall back to one at a time.
    for i = 1:numel(objs)
        try %#ok<TRYNC>
            objs(i).HitTest = val;
        end
    end
end
end
