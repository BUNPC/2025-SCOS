close all; 
clear all;

window_x = 7;
window_y = 7;
% gain = 0.3755; % ADU/e-
gain = [0.38153 0.38043 0.37882 0.37859 0.38140 0.37793 0.37746 0.38385 ...
    0.38362 0.38167 0.38193 0.38096 0.37917 0.37853 0.38052 0.38469 ...
    0.38313]; % ADU/e-
source_num = 7; % source

consider_spatial_heterogeneity = true;
use_intensity_weight = true;
use_lsq_fit = false;

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

sub_folder = '20241120 stroop\preprocessed';
run_name = {'run1' 'run2' 'run3'};
max_file_ind = 92;

save_folder = fullfile('.','analyzed');

for run = 1:2
     % get photodiode tc
    load([run_name{run} 'stim.mat']);

    pd = data.Dev1_ai2;
    pd_mean = photodiode2Timecourse(pd);
    for camera_ind = 9:16
        tic;
        disp(['Camera # ' num2str(camera_ind)]);
        img_folder = fullfile(drive_loc{camera_ind},sub_folder,run_name{run},['camera' num2str(camera_ind)]);
        img_files = dir(fullfile(img_folder,'*.mat'));
        img_files = natsortfiles(img_files);
        load(fullfile(drive_loc{camera_ind},sub_folder,run_name{run},['camera' num2str(camera_ind)],'dark','dark_preprocessed.mat'));

        % get mean image
        for file_ind = 1:max_file_ind
            m = matfile(fullfile(img_files(file_ind).folder,img_files(file_ind).name));

            file_frame_num = numel(m.save_frame_ind);

            img_mean_frame_num_file(1,1,:) = m.img_mean_frame_num;
            if file_ind == 1
                img_mean = m.img_mean.*repmat(img_mean_frame_num_file,size(m.img_mean,1),size(m.img_mean,2),1);
                img_mean_frame_num = img_mean_frame_num_file;
            else
                img_mean = img_mean + m.img_mean.*repmat(img_mean_frame_num_file,size(m.img_mean,1),size(m.img_mean,2),1);
                img_mean_frame_num = img_mean_frame_num + img_mean_frame_num_file;
            end
        end
        img_mean = img_mean./repmat(img_mean_frame_num,size(m.img_mean,1),size(m.img_mean,2),1);
        mean_cc = squeeze(mean(img_mean,[1 2]));

        % find dark windows
        dark_windows = nan(size(img_mean,2),size(img_mean,3));
        for source_ind = 1:size(img_mean,3)
            dark_windows(:,source_ind) = mean(img_mean(:,:,source_ind),1) < 0.5;
        end
        dark_windows_common = mean(dark_windows,2) == 1;

        % get time course
        tc = [];
        tc_dark = [];
        frame_source_ind = [];
        m = matfile(fullfile(img_files(1).folder,img_files(1).name));
        section_frame_num = size(m.mean_windowed,2);
        for file_ind = 1:max_file_ind
            m = matfile(fullfile(img_files(file_ind).folder,img_files(file_ind).name));
            mean_windowed_section = m.mean_windowed;
            source_ind_section = m.source_ind;
            tc = cat(1,tc,mean(mean_windowed_section,1)');
            tc_dark = cat(1,tc_dark,mean(mean_windowed_section(dark_windows_common,:),1)');
            frame_source_ind = cat(1,frame_source_ind,source_ind_section');
        end

        for source_ind = 1:source_num
            good_windows(:,source_ind) = squeeze(mean(img_mean(:,:,source_ind),1)) > 4 & ...
                squeeze(mean(img_mean(:,:,source_ind),1)) < 700;

            shift_counts{source_ind} = shiftCounts(tc_dark(frame_source_ind == source_ind));
        end

        % for each file
        frame_num_source = zeros(source_num,1);
        total_frame_ind = 0;
        for file_ind = 1:max_file_ind
            disp(['  File # ' num2str(file_ind)])
            m = matfile(fullfile(img_files(file_ind).folder,img_files(file_ind).name));
            file_frame_num = size(m.mean_windowed,2);
            for section_ind = 1:ceil(file_frame_num/section_frame_num)
                disp(['    Section # ' num2str(section_ind)]);
                frame_start = (section_ind - 1)*section_frame_num + 1;
                frame_end = min([section_ind*section_frame_num file_frame_num]);
                frame_source_ind_file = frame_source_ind(file_frame_num*(file_ind - 1) + (frame_start:frame_end));

                mean_windowed = m.mean_windowed(:,frame_start:frame_end);
                var_windowed = m.var_windowed(:,frame_start:frame_end);
                pd_mean_section = pd_mean(total_frame_ind+1:total_frame_ind+section_frame_num);

                for source_ind = 1:source_num
                    mean_windowed_source = mean_windowed(:,frame_source_ind_file == source_ind);
                    var_windowed_source = var_windowed(:,frame_source_ind_file == source_ind);
                    pd_mean_section_source = pd_mean_section(frame_source_ind_file == source_ind);

                    % shift camera counts
                    mean_windowed_source = mean_windowed_source ...
                        - repmat(shift_counts{source_ind}(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)))',size(mean_windowed_source,1),1);

                    % calculate Kf2
                    good_window_source = good_windows(:,source_ind);
                    if sum(good_window_source) > 0
                        [Kf2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind), ...
                            Kraw2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind), ...
                            Ks2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind), ...
                            Kr2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind), ...
                            Kq2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind), ...
                            Ksp2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind), ...
                            cc(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind)] = ...
                            processReducedData(mean_windowed_source(good_window_source,:), ...
                            var_windowed_source(good_window_source,:), ...
                            img_mean(:,good_window_source,source_ind),...
                            dark_var_windowed(good_window_source), ...
                            gain(camera_ind), ...
                            img_mean_frame_num(source_ind), ...
                            consider_spatial_heterogeneity, use_intensity_weight, use_lsq_fit);
                    else
                        Kf2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind) = nan(size(mean_windowed_source,2),1);
                        Kraw2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind) = nan(size(mean_windowed_source,2),1);
                        Ks2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind) = nan(size(mean_windowed_source,2),1);
                        Kr2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind) = nan(size(mean_windowed_source,2),1);
                        Kq2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind) = nan(size(mean_windowed_source,2),1);
                        Ksp2(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind) = nan(size(mean_windowed_source,2),1);
                        cc(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind) = nan(size(mean_windowed_source,2),1);
                    end
                    % photodiode correction
                    cc_corrected(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind) = cc(frame_num_source(source_ind)+(1:size(mean_windowed_source,2)),source_ind)./pd_mean_section_source;

                    frame_num_source(source_ind) = frame_num_source(source_ind) + size(mean_windowed_source,2);
                end
                total_frame_ind = total_frame_ind + size(mean_windowed,2);
            end
        end

        if ~exist(fullfile(save_folder,run_name{run}))
            mkdir(fullfile(save_folder,run_name{run}))
        end
        save(fullfile(save_folder,run_name{run},[run_name{run} 'camera' num2str(camera_ind) '.mat']),'Kf2','Kraw2','Ks2','Kr2','Ksp2','cc','cc_corrected','shift_counts','good_windows','tc','frame_source_ind');
        toc
    end
end

%% plot
close all;

ch = 6;
% figure; plot(cc(:,ch)./mean(cc(:,ch))); hold on; plot(cc_corrected(:,ch)./mean(cc_corrected(:,ch)))
figure; plot(Kf2);