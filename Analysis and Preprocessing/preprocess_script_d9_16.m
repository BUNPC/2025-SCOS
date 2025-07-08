clear all;
close all;
clc;

drive_loc{1} = 'D:';
drive_loc{2} = 'D:';
drive_loc{3} = 'E:';
drive_loc{4} = 'E:';
drive_loc{5} = 'F:';
drive_loc{6} = 'F:';
drive_loc{7} = 'G:';
drive_loc{8} = 'G:';
drive_loc{9} = 'D:';
drive_loc{10} = 'D:';
drive_loc{11} = 'E:';
drive_loc{12} = 'E:';
drive_loc{13} = 'F:';
drive_loc{14} = 'F:';
drive_loc{15} = 'G:';
drive_loc{16} = 'G:';
drive_loc{17} = 'F:';

bingus = {'run1','run2','run3'};

for camera = 16
    for run = 1:2
        disp(num2str(camera));
        super_folder = [drive_loc{camera} '\20241120 stroop'];

        img_files = dir(fullfile(super_folder,[bingus{run} '\camera' num2str(camera)],'*file*.h5'));
        img_files = natsortfiles(img_files);
        % img_files(end) = [];

        ts_file = dir(fullfile(super_folder,[bingus{run} '\camera' num2str(camera)],'*timestamps.h5'));
        ts_file = fullfile(ts_file(1).folder,ts_file(1).name);
        % ts_file = [];
        dark_files = dir(fullfile(super_folder,['dark\camera' num2str(camera)],'*file*.h5'));
        window_y = 7; window_x = 7;
        % mean 5x greater than read noise std; var 10x read noise + quantization
        hot_pix_fcn = @(mu,var) (mu >= 24.4 + (0.375*2.2)*5) | (var >= ((0.375*2.2*10)^2 + 1/12));
        cycle_frame_num = 7;

        save_folder = fullfile(super_folder,['preprocessed\run' num2str(run) '\camera' num2str(camera)]);
        dark_save_folder = fullfile(super_folder,['preprocessed\run' num2str(run) '\camera' num2str(camera) '\dark']);

        tic;
        preprocessH5(img_files,dark_files,ts_file,window_y,window_x,hot_pix_fcn,cycle_frame_num,save_folder,dark_save_folder,'sectionFrameNum',500)
        toc
    end
end