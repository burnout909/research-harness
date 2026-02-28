% RRT_basic_exploring_v01.m
% 2D RRT Simulation with Obstacle Avoidance

clear; clc; close all;

%% Parameters
% Use script location to determine paths reliably
[script_dir, ~, ~] = fileparts(mfilename('fullpath'));
% script_dir is ".../data/matlab"

% Construct absolute paths
% Go up one level from data/matlab to data, then into outputs
output_dir = fullfile(script_dir, '..', 'outputs');
matlab_data_dir = script_dir; % save .mat files in data/matlab

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

map_size = [100, 100];
start_pos = [5, 5];
goal_pos = [95, 95];
step_size = 0.5;       % User defined
goal_threshold = 0.1;  % User defined
max_iter = 5000;
obs_list = [           % [x, y, radius]
    30, 30, 10;
    70, 70, 15;
    40, 80, 10;
    80, 40, 10;
    50, 50, 15
];

gif_filename = fullfile(output_dir, 'RRT_basic_exploring_v01.gif');
final_img_filename = fullfile(output_dir, 'RRT_basic_exploring_v01_final.png');
result_mat_filename = fullfile(matlab_data_dir, 'RRT_basic_exploring_v01_result.mat');

%% Initialize RRT
nodes(1).coord = start_pos;
nodes(1).parent = 0;
num_nodes = 1;
path_found = false;

% Create figure (invisible for batch processing)
f = figure('Visible', 'off'); 
hold on;
axis([0 map_size(1) 0 map_size(2)]);
grid on;
title('RRT Exploration');
xlabel('X'); ylabel('Y');

% Draw Obstacles
for i = 1:size(obs_list, 1)
    rectangle('Position', [obs_list(i,1)-obs_list(i,3), obs_list(i,2)-obs_list(i,3), ...
        2*obs_list(i,3), 2*obs_list(i,3)], 'Curvature', [1 1], 'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'k');
end

% Plot Start and Goal
plot(start_pos(1), start_pos(2), 'go', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Start');
plot(goal_pos(1), goal_pos(2), 'rx', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Goal');
% legend('show', 'Location', 'northeastoutside'); % Removed to avoid warning

%% Main Loop
disp(['Starting RRT simulation... Output: ', gif_filename]);
first_frame = true;

for iter = 1:max_iter
    % Sample Random Point
    if rand < 0.1
        q_rand = goal_pos; % Bias towards goal
    else
        q_rand = [rand*map_size(1), rand*map_size(2)];
    end
    
    % Find Nearest Node
    min_dist = inf;
    nearest_idx = -1;
    for i = 1:num_nodes
        dist = norm(nodes(i).coord - q_rand);
        if dist < min_dist
            min_dist = dist;
            nearest_idx = i;
        end
    end
    q_nearest = nodes(nearest_idx).coord;
    
    % Steer towards q_rand
    direction = (q_rand - q_nearest);
    dist_to_rand = norm(direction);
    if dist_to_rand > 0
        direction = direction / dist_to_rand;
    else
        direction = [0, 0];
    end
    
    % Move step_size (or less if closer)
    actual_step = min(step_size, dist_to_rand); 
    q_new = q_nearest + actual_step * direction;
    
    % Collision Check
    collision = false;
    % Boundary check
    if q_new(1) < 0 || q_new(1) > map_size(1) || q_new(2) < 0 || q_new(2) > map_size(2)
        collision = true;
    else
        % Obstacle check
        for i = 1:size(obs_list, 1)
            if norm(q_new - obs_list(i, 1:2)) <= obs_list(i, 3)
                collision = true;
                break;
            end
        end
    end
    
    if ~collision
        % Add Node
        num_nodes = num_nodes + 1;
        nodes(num_nodes).coord = q_new;
        nodes(num_nodes).parent = nearest_idx;
        
        % Plot new edge
        plot([q_nearest(1), q_new(1)], [q_nearest(2), q_new(2)], 'b-', 'LineWidth', 0.5);
        
        % Check Goal
        if norm(q_new - goal_pos) <= goal_threshold
            path_found = true;
            disp(['Path found at iteration: ', num2str(iter)]);
            break;
        end
        
        % Animation: Save Frame every 50 iterations
        if mod(iter, 50) == 0
            drawnow;
            frame = getframe(f);
            im = frame2im(frame);
            [imind, cm] = rgb2ind(im, 256);
            if first_frame
                imwrite(imind, cm, gif_filename, 'gif', 'Loopcount', inf, 'DelayTime', 0.1);
                first_frame = false;
            else
                imwrite(imind, cm, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.1);
            end
        end
    end
    
    if mod(iter, 1000) == 0
        disp(['Iteration: ', num2str(iter)]);
    end
end

%% Final Path Processing
if path_found
    curr_idx = num_nodes;
    path_x = [];
    path_y = [];
    path_len = 0;
    
    % Backtrack path
    while curr_idx > 0
        p_curr = nodes(curr_idx).coord;
        path_x = [p_curr(1), path_x];
        path_y = [p_curr(2), path_y];
        
        parent_idx = nodes(curr_idx).parent;
        if parent_idx > 0
            p_parent = nodes(parent_idx).coord;
            path_len = path_len + norm(p_curr - p_parent);
        end
        curr_idx = parent_idx;
    end
    
    plot(path_x, path_y, 'r-', 'LineWidth', 2);
    title(['RRT Path Found (Length: ', num2str(path_len, '%.2f'), ')']);
    
    % Save Final Frame for GIF
    drawnow;
    frame = getframe(f);
    im = frame2im(frame);
    [imind, cm] = rgb2ind(im, 256);
    if first_frame
        imwrite(imind, cm, gif_filename, 'gif', 'Loopcount', inf, 'DelayTime', 2);
    else
        imwrite(imind, cm, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', 2);
    end
    
    % Save Result Data
    save(result_mat_filename, 'nodes', 'path_x', 'path_y', 'path_len', 'iter', 'path_found');
else
    disp('Failed to find path within max iterations');
    title('RRT Path Not Found');
    save(result_mat_filename, 'nodes', 'iter', 'path_found');
end

% Save Final Image
saveas(f, final_img_filename);
close(f);
disp('Simulation complete.');
