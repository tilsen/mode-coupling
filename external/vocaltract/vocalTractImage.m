classdef vocalTractImage


    properties
        imDataOrig
        imData
        imHandle
        tractVars
        articulators         
        landmarks
        contours
        palate
        pharynx
        sourcePath
    end

    methods

        function [obj] = vocalTractImage(opts)
            arguments
                opts.showTractVars
                opts.showArticulators
                opts.dataSource = "default"
            end

            opts.sourcePath = string(fileparts(mfilename("fullpath")))+filesep+opts.dataSource+filesep;

            obj.imDataOrig = loadOut(opts.sourcePath+"manual_contour.mat",'im');
            obj.contours = loadOut(opts.sourcePath+"manual_contour.mat",'contours');
            obj.landmarks = loadOut(opts.sourcePath+"anatomical_landmarks.mat",'ALM');
            
            obj = obj.genPalate();
            obj = obj.genPharynx();
            obj = obj.genImage();
            
            obj.articulators = tabread(opts.sourcePath+"articulators.csv");
            obj.tractVars = tabread(opts.sourcePath+"tractVariables.csv");
            obj = obj.calcTractVarProps();

        end

        function [obj] = calcTractVarProps(obj)
            obj.tractVars.xpos = [obj.tractVars.x0 obj.tractVars.x1];
            obj.tractVars.ypos = [obj.tractVars.y0 obj.tractVars.y1];
            obj.tractVars.xy0 = [obj.tractVars.x0 obj.tractVars.y0];
            obj.tractVars.xy1 = [obj.tractVars.x1 obj.tractVars.y1];
            obj.tractVars.labpos = [mean(obj.tractVars.xpos,2) mean(obj.tractVars.ypos,2)];

            a = obj.tractVars.xy0; a(:,3)=0;
            b = obj.tractVars.xy1; b(:,3)=0;
            ixflip = a(:,2)<b(:,2);
            a = a-b;
            a(ixflip,:) = abs(a(ixflip,:));

            rot = arrayfun(@(c)atan2(norm(cross(a(c,:),[1 0 0])),dot(a(c,:),[1 0 0])),(1:size(a,1))');
            
            rot(rot>pi/2) = rot(rot>pi/2)-pi;
            rot(rot<=-pi) = rot(rot<=-pi)+pi;

            obj.tractVars.rot = rad2deg(rot);
        end

        function [obj] = genPalate(obj,opts)
            arguments
                obj
                opts.yshift = 15
                opts.xshift = 3
            end
            im = obj.imDataOrig;
            pal = round(obj.landmarks.palate.pntsi);
            pal(:,2) = pal(:,2)+opts.yshift;
            pal(:,1) = pal(:,1)+opts.xshift;
            pp = pal(1,:);
            pal = pal-repmat(pp,size(pal,1),1);
            aa = -0.15;
            pal = pal*[cos(aa) -sin(aa); sin(aa) cos(aa)];
            pal = pal+repmat(pp,size(pal,1),1);
            fo = fit(pal(:,1),pal(:,2),'smoothingspline');
            yf = feval(fo,pal(end,1):0.25:pal(1,1));
            pal = ([(pal(end,1):0.25:pal(1,1))' yf]);
            pal = [linspace(pal(1,1)-7,pal(1,1),10)' linspace(pal(1,2)-7,pal(1,2),10)'; ...
                pal; (pal(end,1):size(im,2))' linspace(pal(end,2),40,length(pal(end,1):size(im,2)))'];
            obj.palate = round(pal);
        end

        function [obj] = genPharynx(obj,opts)
            arguments
                obj 
                opts.yshift = -5
            end
            phar = round(obj.landmarks.pharynx.pntsi);
            phar(:,2) = phar(:,2)+opts.yshift;
            obj.pharynx = phar;
        end

        function [obj] = genImage(obj,opts)
            arguments
                obj
                opts.trimrows = 25
                opts.imthresh = 75
            end
            trimrows = opts.trimrows;
            imthresh = opts.imthresh;
            im = obj.imDataOrig;
            im(im>imthresh) = imthresh;
            for i=1:size(obj.pharynx,1)
                origrow = im(obj.pharynx(i,2),obj.pharynx(i,1):end);
                newrow = [linspace(double(origrow(1)),imthresh,6) imthresh*ones(1,size(im,2)-obj.pharynx(i,1)-5)];
                im(obj.pharynx(i,2),obj.pharynx(i,1):end) = max([origrow; newrow]);
            end
            for i=1:size(obj.palate,1)
                origcol = im(1:obj.palate(i,2),obj.palate(i,1));
                newcol = [imthresh*ones(1,obj.palate(i,2)-5) round(linspace(imthresh,double(origcol(end)),5))];
                im(1:obj.palate(i,2),obj.palate(i,1)) = max([origcol'; newcol]);
            end
            im = im(trimrows:end,:);
            im(1:15,:) = 0;
            hh = fspecial('gaussian',[5 5],1);
            im = filter2(hh,im,'same');
            obj.imData = im;
        end

        function [obj] = plot(obj,opts)
            arguments
                obj
                opts.parent = []
                opts.colormap = []
                opts.tractVars = true
                opts.articulators = false
                opts.articulatorLabels = true
                opts.fontSize = 14
                opts.tractVarLineWidth = 2
            end
            if isempty(opts.parent), opts.parent = gca; end

            if isempty(opts.colormap)
                opts.colormap = flip(gray(256));
                opts.colormap = opts.colormap(1:128,:);
            end

            obj.imHandle = image(flipud(obj.imData),Parent=opts.parent); 
            hold(opts.parent,'on');
            colormap(opts.parent,opts.colormap);
            set(opts.parent,'YDir','normal'); axis(opts.parent,'equal');
            axis(opts.parent,'tight');

            if opts.tractVars
                if ~colExists(obj.tractVars,'color')
                    obj.tractVars.color = repmat([ 0 0 0],height(obj.tractVars),1);
                end

                % line width: the tractVars table's lineWidth column (per
                % variable) if it has one, else tractVarLineWidth
                if colExists(obj.tractVars,'lineWidth')
                    tractVarLW = obj.tractVars.lineWidth;
                else
                    tractVarLW = repmat(opts.tractVarLineWidth,height(obj.tractVars),1);
                end
                for i=1:height(obj.tractVars)
                    obj.tractVars.lh(i) = plot(obj.tractVars.xpos(i,:),obj.tractVars.ypos(i,:), ...
                        'Color',obj.tractVars.color(i,:),'LineWidth',tractVarLW(i));
                    obj.tractVars.th(i) = text(obj.tractVars.labpos(i,1),obj.tractVars.labpos(i,2), ...
                        obj.tractVars.name(i),'Rotation',obj.tractVars.rot(i),...
                        'HorizontalAlignment',obj.tractVars.halign(i),'VerticalAlignment',obj.tractVars.valign(i),...
                        'FontSize',opts.fontSize);
                end
            end

            if opts.articulators
                if ~colExists(obj.articulators,'color')
                    obj.articulators.color = repmat([ 0 0 0],height(obj.articulators),1);
                end

                for i=1:height(obj.articulators)
                    obj.articulators.lh(i) = plot(obj.articulators.x(i),obj.articulators.y(i), ...
                        'Color',obj.articulators.color(i,:),...
                        'MarkerFaceColor',obj.articulators.color(i,:),'LineWidth',1, ...
                        'Marker','o','markerSize',4);

                    if opts.articulatorLabels
                        obj.articulators.th(i) = text(obj.articulators.x(i),obj.articulators.y(i), ...
                            " " + obj.articulators.name(i) + " ",...
                            'HorizontalAlignment',obj.articulators.halign(i),'VerticalAlignment',obj.articulators.valign(i),...
                            'FontSize',opts.fontSize);
                    end
                end
            end            

            set(opts.parent,'Visible','off');
        end

    end

end
