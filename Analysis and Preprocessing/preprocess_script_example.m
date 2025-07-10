clear all;
close all;
clc;

run_cell_array = {'run1','run2','run3'};

for camera = 2
    for run = 1
        disp(num2str(camera));
        super_folder = pwd;

        img_files = dir(fullfile(super_folder,[run_cell_array{run} '\camera' num2str(camera)],'*file*.h5'));
        img_files = natsortfiles(img_files);


        dark_files = dir(fullfile(super_folder,['dark\camera' num2str(camera)],'*file*.h5'));
        window_y = 7; window_x = 7;
        % mean 5x greater than read noise std; var 10x read noise + quantization
        hot_pix_fcn = @(mu,var) (mu >= 24.4 + (0.375*2.2)*5) | (var >= ((0.375*2.2*10)^2 + 1/12));
        cycle_frame_num = 6;

        save_folder = fullfile(super_folder,['preprocessed\run' num2str(run) '\camera' num2str(camera)]);
        dark_save_folder = fullfile(super_folder,['preprocessed\run' num2str(run) '\camera' num2str(camera) '\dark']);

        tic;
        preprocessH5(img_files,dark_files,[],window_y,window_x,hot_pix_fcn,cycle_frame_num,save_folder,dark_save_folder,'sectionFrameNum',500)
        toc
    end
end

%% Plot
load('preprocessed\run1\camera2\section1_preprocessed.mat')
ind = 1:500;
slice = 10:6:500;
t = ind/100;

mean_w_avg = squeeze(mean(mean_windowed));
var_w_avg = squeeze(mean(var_windowed));

% Create tiled layout: 4 rows, 1 column
figure;
tiledlayout(4,1);

% Plot 1
nexttile;
plot(t, mean(mean_windowed));
xlabel('time [s]');
ylabel('Intensity [ADU]');
title('Intensity Window Average');

% Plot 2
nexttile;
plot(t(slice), mean_w_avg(slice));
xlabel('time [s]');
ylabel('Intensity [ADU]');
title('Intensity Window Average One Source');

% Plot 3
nexttile;
plot(t, mean(var_windowed));
xlabel('time [s]');
ylabel('Variance [ADU]');
title('Variance Window Average');

% Plot 4
nexttile;
plot(t(slice), var_w_avg(slice));
xlabel('time [s]');
ylabel('Variance [ADU]');
title('Variance Window Average One Source');
