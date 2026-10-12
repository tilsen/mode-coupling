classdef progressMonitor < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    %{ 
        parfor usage:
            call before loop:
                afterEach(q,@(~)pm.updateParallel());
            call within loo:
                send(q,i);
    %}

    properties
        iter = 0
        numIters
        ticId
        status
        timePerIter = nan;
        elapsedTime = nan;
        timeRemaining = nan;        
        reportFreq = 0.01
        reportInterval
    end

    methods
        function obj = progressMonitor(numIters,opts)
            arguments
                numIters
                opts.reportFreq = 0.01
                opts.parallel = false;                
            end
            obj.reportFreq = opts.reportFreq;
            if opts.parallel, obj.ticId = tic; end
            obj.iter = 1;
            obj.numIters = numIters;
            obj.status = '';
            if nargin==2
                obj.reportFreq = reportFreq;
            end
            obj.reportInterval = max(round(obj.numIters*obj.reportFreq),1);
        end

        function [] = update(obj,iter,str)
            obj.iter = iter;
            if isempty(obj.ticId), obj.ticId = tic; end
            if obj.iter>1
                obj.elapsedTime = toc(obj.ticId);
                obj.timePerIter = obj.elapsedTime/(obj.iter-1);
                obj.timeRemaining = (obj.numIters-obj.iter+1)*obj.timePerIter;
            end
            if nargin==2, str = ''; end
            lenDelete = length(obj.status);
            obj.status = obj.constructStatus(str);
            fprintf([repmat('\b',1,lenDelete) '%s'],obj.status);            
            if obj.iter==obj.numIters
                fprintf('\n');
                obj.reset();
            end
        end

        function [] = message(obj,msg)
            fprintf('\n%s\n\n%s',msg,obj.status);
        end

        function [] = updateParallel(obj)
            obj.iter = obj.iter + 1;
            if obj.iter==1 || mod(obj.iter,obj.reportInterval)==1 || obj.iter==obj.numIters
                obj.update(obj.iter);
            end
        end

        function [] = reset(obj)            
            obj.iter = 0;
            obj.status = '';
        end

        function [str] = constructStatus(obj,extra)
            str = [extra ' iter: ' sprintf('%d/%d',obj.iter,obj.numIters) ...
                ' | time/iter: ' progressMonitor.timeStr(obj.timePerIter) ...
                ' | elapsed: ' progressMonitor.timeStr(obj.elapsedTime) ...
                ' | remaining: ' progressMonitor.timeStr(obj.timeRemaining) blanks(10)];
            str = char(str);
        end
    end

    methods (Static)
        function str = timeStr(s)

            if s>60
                s = s/60;
                str = sprintf('%1.1f min',s);
            else
                str = sprintf('%1.3f s',s);
            end

        end
    end
end