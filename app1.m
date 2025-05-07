classdef app1 < matlab.apps.AppBase

    
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        UIAxes               matlab.ui.control.UIAxes
        LoadImageButton      matlab.ui.control.Button   % Yeni eklenen buton
        SnflandrButton       matlab.ui.control.Button
        ADropDown            matlab.ui.control.DropDown
        ADropDownLabel       matlab.ui.control.Label
        BEYNTMRTEHSLabel     matlab.ui.control.Label
        DETECTORLampLabel    matlab.ui.control.Label
        DETECTORLamp         matlab.ui.control.Lamp
        SelectedImagePath                      % Seçilen görüntü yolu
    end

    methods (Access = private)

        function createComponents(app)
            % Ana pencere
            app.UIFigure = uifigure('Visible','off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name     = 'MATLAB App';

            % Görüntü göstermek için axes
            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.Position = [24 160 290 275];
            axis(app.UIAxes,'off');

            % "Görsel Yükle" butonu (dropdown’un hemen altı)
            app.LoadImageButton = uibutton(app.UIFigure,'push');
            app.LoadImageButton.Position = [517 315 106 22];
            app.LoadImageButton.Text     = 'Görsel Yükle';
            app.LoadImageButton.ButtonPushedFcn = @(~,~) onLoadImage(app);

            % Sınıflandır butonu
            app.SnflandrButton = uibutton(app.UIFigure,'push');
            app.SnflandrButton.Position        = [330 160 285 73];
            app.SnflandrButton.Text            = 'Sınıflandır';
            app.SnflandrButton.FontSize        = 36;
            app.SnflandrButton.BackgroundColor = [0.302 0.7451 0.9333];
            app.SnflandrButton.FontColor       = [1 1 1];
            app.SnflandrButton.ButtonPushedFcn = @(~,~) SnflandrButtonPushed(app);

            % Başlık
            app.BEYNTMRTEHSLabel = uilabel(app.UIFigure);
            app.BEYNTMRTEHSLabel.Position           = [24 443 574 38];
            app.BEYNTMRTEHSLabel.Text               = 'BEYİN TÜMÖRÜ TEHŞİSİ';
            app.BEYNTMRTEHSLabel.FontSize           = 24;
            app.BEYNTMRTEHSLabel.FontWeight         = 'bold';
            app.BEYNTMRTEHSLabel.FontColor          = [0.302 0.7451 0.9333];
            app.BEYNTMRTEHSLabel.HorizontalAlignment= 'center';

            % Ağ seçimi
            app.ADropDownLabel = uilabel(app.UIFigure);
            app.ADropDownLabel.Position           = [322 350 25 22];
            app.ADropDownLabel.Text               = 'Ağ';
            app.ADropDownLabel.HorizontalAlignment= 'right';
            app.ADropDown = uidropdown(app.UIFigure);
            app.ADropDown.Position                = [517 350 106 22];
            app.ADropDown.Items                   = {'resnet18','googlenet','alexnet','xception'};
            app.ADropDown.Value                   = 'resnet18';

            % Detector lamp
            app.DETECTORLampLabel = uilabel(app.UIFigure);
            app.DETECTORLampLabel.Position           = [38 78 71 22];
            app.DETECTORLampLabel.Text               = 'DETECTOR';
            app.DETECTORLampLabel.HorizontalAlignment= 'right';
            app.DETECTORLamp = uilamp(app.UIFigure);
            app.DETECTORLamp.Position                = [124 79 20 20];

            % Başlangıçta resim yok
            app.SelectedImagePath = '';

            app.UIFigure.Visible = 'on';
        end

        function onLoadImage(app)
            % Butona tıklanınca çalışır
            [f,p] = uigetfile({'*.jpg;*.png;*.bmp'},'Görsel Seçin');
            if isequal(f,0), return; end
            app.SelectedImagePath = fullfile(p,f);
            img = imread(app.SelectedImagePath);
            imshow(img,'Parent',app.UIAxes);
        end

        function SnflandrButtonPushed(app)
            % Model seçimi
            switch app.ADropDown.Value
                case 'resnet18'
                    modelFile = 'bestModel.mat';
                case 'googlenet'
                    modelFile = 'brain_tumor_googlenet_model.mat';
                case 'alexnet'
                    modelFile = 'brain_tumor_alexnet_model.mat';
                case 'xception'
                    modelFile = 'brain_tumor_xception_model.mat';
                otherwise
                    uialert(app.UIFigure,'Geçersiz model!','Hata');
                    return;
            end

            % Model yükleme
            modelFolder   = fileparts(mfilename('fullpath'));
            modelFullPath = fullfile(modelFolder,modelFile);
            try
                data   = load(modelFullPath);
                fnames = fieldnames(data);
                trainedNet = [];
                for i = 1:numel(fnames)
                    v = data.(fnames{i});
                    if isa(v,'DAGNetwork')||isa(v,'SeriesNetwork')||isa(v,'dlnetwork')
                        trainedNet = v; break;
                    end
                end
                if isempty(trainedNet), error('Ağ bulunamadı.'); end
            catch ME
                app.BEYNTMRTEHSLabel.Text      = 'Model Yüklenemedi';
                app.BEYNTMRTEHSLabel.FontColor = [1 0 0];
                disp(['Model yüklenemedi: ', ME.message]);
                return;
            end

            % Görsel kontrolü
            if isempty(app.SelectedImagePath)
                uialert(app.UIFigure,'Önce bir görsel yükleyin.','Bilgi');
                return;
            end

            % Görseli oku & 3 kanala çıkar
            img = imread(app.SelectedImagePath);
            if size(img,3)==1
                img = cat(3,img,img,img);
            end

            % Ölçek ve normalize
            inpSz = trainedNet.Layers(1).InputSize(1:2);
            imgR  = imresize(img,inpSz);
            imgS  = im2single(imgR);

            % Sınıflandır
            YP      = classify(trainedNet,imgS);
            isTumor = strcmpi(string(YP),'yes');

            % Annotasyon
            annotatedImg = imgR;
            if isTumor
                gray   = rgb2gray(imgR);
                grayF  = medfilt2(gray,[5 5]);
                T      = adaptthresh(grayF,0.4,'ForegroundPolarity','bright');
                bw     = imbinarize(grayF,T);
                bw     = imopen(bw,strel('disk',5));
                bw     = imfill(bw,'holes');
                bw     = bwareaopen(bw,1000);
                bw2    = imclearborder(bw);
                stats  = regionprops(bw2,'Area','BoundingBox');
                [~,idx] = max([stats.Area]);
                bb = stats(idx).BoundingBox;
                annotatedImg = insertShape(imgR,'Rectangle',bb,...
                                           'LineWidth',3,'Color','red');
            end
            imshow(annotatedImg,'Parent',app.UIAxes);

            % Sonuç güncelle
            if isTumor
                app.DETECTORLamp.Color        = [1 0 0];
                app.BEYNTMRTEHSLabel.Text     = 'TÜMÖR ALGILANDI';
                app.BEYNTMRTEHSLabel.FontColor= [1 0 0];
            else
                app.DETECTORLamp.Color        = [0 1 0];
                app.BEYNTMRTEHSLabel.Text     = 'TÜMÖR ALGILANMADI';
                app.BEYNTMRTEHSLabel.FontColor= [0 1 0];
            end
        end
    end

    methods (Access = public)
        function app = app1
            createComponents(app)
            registerApp(app,app.UIFigure)
            if nargout==0, clear app; end
        end
        function delete(app)
            delete(app.UIFigure)
        end
    end
end
