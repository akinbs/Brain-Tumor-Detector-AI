classdef app1 < matlab.apps.AppBase

    properties (Access = public)
        UIFigure             matlab.ui.Figure
        UIAxes               matlab.ui.control.UIAxes
        LoadImageButton      matlab.ui.control.Button
        SnflandrButton       matlab.ui.control.Button
        ADropDown            matlab.ui.control.DropDown
        ADropDownLabel       matlab.ui.control.Label
        BEYNTMRTEHSLabel     matlab.ui.control.Label
        DETECTORLampLabel    matlab.ui.control.Label
        DETECTORLamp         matlab.ui.control.Lamp
        SelectedImagePath    % Seçilen görüntü yolu
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

            % "Görsel Yükle" butonu
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
            app.ADropDown.Items                   = {'yolov2','googlenet','alexnet','xception'};
            app.ADropDown.Value                   = 'yolov2';

            % Detector lamp
            app.DETECTORLampLabel = uilabel(app.UIFigure);
            app.DETECTORLampLabel.Position           = [38 78 71 22];
            app.DETECTORLampLabel.Text               = 'DETECTOR';
            app.DETECTORLampLabel.HorizontalAlignment= 'right';
            app.DETECTORLamp = uilamp(app.UIFigure);
            app.DETECTORLamp.Position                = [124 79 20 20];
            % Başlangıçta yeşil renk (tümör algılanmadı)
            app.DETECTORLamp.Color                  = [0 1 0];

            % Başlangıçta resim yok
            app.SelectedImagePath = '';

            app.UIFigure.Visible = 'on';
        end

        function onLoadImage(app)
            % Yeni görsel yüklendiğinde öncesi temizle
            [f,p] = uigetfile({'*.jpg;*.png;*.bmp'},'Görsel Seçin');
            if isequal(f,0), return; end
            app.SelectedImagePath = fullfile(p,f);
            img = imread(app.SelectedImagePath);
            imshow(img,'Parent',app.UIAxes);

            % Önceki sonuçları temizle
            app.BEYNTMRTEHSLabel.Text      = 'BEYİN TÜMÖRÜ TEHŞİSİ';
            app.BEYNTMRTEHSLabel.FontColor = [0.302 0.7451 0.9333];
            app.DETECTORLamp.Color         = [0 1 0];
        end

        function SnflandrButtonPushed(app)
            % Model seçimi
            switch app.ADropDown.Value
                case 'yolov2'
                    modelFile = 'yolov2.mat';
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
                mdlData = load(modelFullPath);
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
            if size(img,3) == 1
                img = cat(3,img,img,img);
            end

            % Hedef boyut ve başlangıç
            inpSz       = [224 224];
            imgR        = imresize(img, inpSz);
            annotatedImg= imgR;
            isTumor     = false;
            mmPerPixel  = 0.5;  % ölçek bilgisi mm/piksel

            % YOLOv2 tespiti
            if strcmp(app.ADropDown.Value,'yolov2')
                detector = mdlData.detector;
                [bboxes,scores] = detect(detector, imgR);
                if ~isempty(bboxes)
                    isTumor = true;
                    [~,idx] = max(scores);
                    bb = bboxes(idx,:);
                    annotatedImg = insertShape(imgR,'Rectangle',bb,'LineWidth',3,'Color','yellow');
                end
            end

            % SAM segmentasyonu + çap hesaplama
            if isTumor
                samObj     = segmentAnythingModel;
                embeddings = extractEmbeddings(samObj, imgR);
                for i = 1:size(bboxes,1)
                    box  = bboxes(i,:);
                    mask = segmentObjectsFromEmbeddings(samObj, embeddings, size(imgR), 'BoundingBox', box);
                    annotatedImg = insertObjectMask(annotatedImg, mask);
                    stats        = regionprops(mask, 'MajorAxisLength');
                    diameterPx   = stats.MajorAxisLength;
                    diameterMM   = diameterPx * mmPerPixel;
                    textPos      = [box(1), box(2)-20];
                    annotatedImg = insertText(annotatedImg, textPos, ...
                        sprintf('Çap: %.1f mm', diameterMM), ...
                        'FontSize',14, 'BoxColor','yellow','TextColor','black');
                end
            end

            % Sonucu göster
            imshow(annotatedImg,'Parent',app.UIAxes);
            if isTumor
                app.DETECTORLamp.Color         = [1 0 0];
                app.BEYNTMRTEHSLabel.Text      = 'TÜMÖR ALGILANDI';
                app.BEYNTMRTEHSLabel.FontColor = [1 0 0];
            else
                app.DETECTORLamp.Color         = [0 1 0];
                app.BEYNTMRTEHSLabel.Text      = 'TÜMÖR ALGILANMADI';
                app.BEYNTMRTEHSLabel.FontColor = [0 1 0];
            end
        end
    end

    methods (Access = public)
        function app = app1
            createComponents(app)
            registerApp(app, app.UIFigure)
            if nargout == 0, clear app; end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end