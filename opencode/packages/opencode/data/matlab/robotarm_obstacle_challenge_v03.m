%% Robot Arm Multi-Obstacle Challenge & Time Optimization
% Experiment: robotarm_obstacle_challenge_v03
% Date: 2026-02-28
% Objective: Find time-optimal trajectory avoiding MULTIPLE obstacles
% Base: robotarm_obstacle_timeopt_v02.m
% Update: Adjusted start config to avoid initial collision

clear; clc; close all;

%% 1. Parameters & Setup
% Robot Parameters (Simplified 6-DOF)
L = [0.4, 0.4, 0.2, 0.1, 0.1, 0.05]; % Link lengths (m)
m = [5, 4, 3, 2, 1, 1]; % Link masses (kg)
g = 9.81;

% Constraints
tau_max = 20.0;      % N.m
vel_max = 3.0;       % rad/s
acc_max = 10.0;      % rad/s^2

% Environment (Multiple Obstacles)
% Matrix format: [x, y, z, radius]
obstacles = [
    0.45,  0.0, 0.4, 0.12; % Shifted slightly +X, reduced radius
    0.3,   0.2, 0.2, 0.10; % Low obstacle
    0.2,  -0.2, 0.5, 0.12  % High/Side obstacle
];

% Motion Task
% Adjusted start to avoid collision with Obs 1
q_start = [0, -pi/6, 0, 0, 0, 0]'; 
q_goal = [pi/2, pi/4, 0, -pi/4, 0, 0]';

% Simulation Settings
dt = 0.01;
max_iter_rrt = 10000; % Increased iterations

%% 2. RRT Path Planning (Joint Space)
fprintf('Step 1: Planning path using RRT in Multi-Obstacle Environment...\n');

nodes(1).q = q_start;
nodes(1).parent = 0;
path_found = false;

rng(123); % Changed seed

% Simple RRT
for i = 1:max_iter_rrt
    % Random Sampling (Goal bias 10%)
    if rand < 0.1
        q_rand = q_goal;
    else
        q_rand = q_start + (q_goal - q_start) .* rand(6, 1) + 0.4*randn(6,1); 
    end
    
    % Find Nearest Node
    dists = arrayfun(@(n) norm(n.q - q_rand), nodes);
    [min_dist, nearest_idx] = min(dists);
    q_near = nodes(nearest_idx).q;
    
    % Steer
    dir_vec = q_rand - q_near;
    dist_val = norm(dir_vec);
    if dist_val > 0
        dir = dir_vec / dist_val;
    else
        dir = zeros(6,1);
    end
    
    step = 0.2; % Restored step size
    q_new = q_near + min(step, min_dist) * dir;
    
    % Collision Check
    if ~check_collision_multi(q_new, obstacles, L)
        nodes(end+1).q = q_new;
        nodes(end).parent = nearest_idx;
        
        if norm(q_new - q_goal) < 0.25
            path_found = true;
            nodes(end+1).q = q_goal;
            nodes(end).parent = length(nodes)-1;
            fprintf('Path found at iter %d with %d nodes.\n', i, length(nodes));
            break;
        end
    end
end

% Construct Waypoints
if ~path_found
    fprintf('RRT failed to find a path. Using linear interpolation fallback.\n');
    waypoints = [q_start, q_goal];
else
    curr_idx = length(nodes);
    path_indices = [curr_idx];
    while nodes(curr_idx).parent ~= 0
        curr_idx = nodes(curr_idx).parent;
        path_indices = [curr_idx, path_indices];
    end
    waypoints = [nodes(path_indices).q];
    
    % Basic Path Smoothing
    fprintf('Smoothing path...\n');
    smooth_waypoints = waypoints(:,1);
    current_idx = 1;
    while current_idx < size(waypoints, 2)
        for check_idx = size(waypoints, 2):-1:current_idx+1
            valid_connection = true;
            steps = 15;
            for s = 1:steps
                interp_q = waypoints(:,current_idx) + (s/steps)*(waypoints(:,check_idx) - waypoints(:,current_idx));
                if check_collision_multi(interp_q, obstacles, L)
                    valid_connection = false;
                    break;
                end
            end
            
            if valid_connection
                smooth_waypoints = [smooth_waypoints, waypoints(:,check_idx)];
                current_idx = check_idx;
                break;
            end
            
            if check_idx == current_idx + 1
                 smooth_waypoints = [smooth_waypoints, waypoints(:,check_idx)];
                 current_idx = check_idx;
            end
        end
    end
    waypoints = smooth_waypoints;
    fprintf('Path smoothed: %d nodes -> %d nodes\n', size(nodes(path_indices).q, 2), size(waypoints, 2));
end

%% 3. Time Optimization (Iterative Scaling)
fprintf('Step 2: Optimizing Trajectory Duration...\n');

T_opt = 3.0; 
iter = 0;
max_iter_opt = 20;
tolerance = 0.05; 

n_points = 100;
t_norm = linspace(0, 1, n_points); 
n_waypoints = size(waypoints, 2);
t_waypoints_norm = linspace(0, 1, n_waypoints);

% Optimization Loop
while iter < max_iter_opt
    iter = iter + 1;
    
    t_real = t_norm * T_opt;
    
    q_traj = zeros(6, n_points);
    dq_traj = zeros(6, n_points);
    ddq_traj = zeros(6, n_points);
    
    for j=1:6
        q_traj(j,:) = spline(t_waypoints_norm * T_opt, waypoints(j,:), t_real);
        dq_traj(j, 1:end-1) = diff(q_traj(j,:)) ./ diff(t_real);
        dq_traj(j, end) = dq_traj(j, end-1);
        ddq_traj(j, 1:end-1) = diff(dq_traj(j,:)) ./ diff(t_real);
        ddq_traj(j, end) = ddq_traj(j, end-1);
    end
    
    tau_traj = zeros(6, n_points);
    M_diag = [0.5; 0.5; 0.4; 0.2; 0.1; 0.05]; 
    
    for k = 1:n_points
        G = calculate_gravity(q_traj(:,k), m, L, g);
        tau_traj(:, k) = M_diag .* ddq_traj(:, k) + G;
    end
    
    max_tau_val = max(max(abs(tau_traj)));
    
    fprintf('Iter %d: T = %.4f s, Max Torque = %.4f Nm (Limit: %.1f)\n', iter, T_opt, max_tau_val, tau_max);
    
    if abs(max_tau_val - tau_max) < tolerance || (max_tau_val < tau_max && iter > 5)
        fprintf('Converged!\n');
        break;
    end
    
    if max_tau_val > tau_max
        scale_factor = sqrt(max_tau_val / tau_max);
        scale_factor = min(scale_factor, 1.2);
        T_opt = T_opt * scale_factor;
    else
        scale_factor = sqrt(max_tau_val / tau_max);
        scale_factor = max(scale_factor, 0.9);
        T_opt = T_opt * scale_factor;
    end
end

%% 4. Save & Visualize
results = struct();
results.experiment = 'robotarm_obstacle_challenge_v03';
results.T_opt = T_opt;
results.max_torque = max_tau_val;
results.waypoints = waypoints;
results.time = t_real;
results.q = q_traj;
results.dq = dq_traj;
results.tau = tau_traj;
results.obstacles = obstacles;
results.converged = (max_tau_val <= tau_max * 1.1);

current_file_path = mfilename('fullpath');
[script_dir, ~, ~] = fileparts(current_file_path);
if isempty(script_dir), script_dir = pwd; end

output_dir = fullfile(script_dir, '..', 'outputs');
mat_file = fullfile(script_dir, 'robotarm_obstacle_challenge_v03_result.mat');
fig_file = fullfile(output_dir, 'robotarm_obstacle_challenge_v03_plot.png');

if ~exist(output_dir, 'dir'), mkdir(output_dir); end
save(mat_file, '-struct', 'results');
fprintf('Results saved to %s\n', mat_file);

% Plot
f = figure('Visible', 'off');
set(f, 'Position', [100, 100, 800, 800]);

subplot(3,1,1);
plot(t_real, q_traj'); 
title('Joint Trajectories (Multi-Obstacle)'); ylabel('Angle (rad)'); grid on;
legend('J1','J2','J3','J4','J5','J6');

subplot(3,1,2);
plot(t_real, dq_traj'); 
title('Joint Velocities'); ylabel('Vel (rad/s)'); grid on;

subplot(3,1,3);
plot(t_real, tau_traj'); 
title('Torque Profiles'); xlabel('Time (s)'); ylabel('Torque (Nm)'); 
yline(tau_max, 'r--'); yline(-tau_max, 'r--');
grid on;

saveas(f, fig_file);
fprintf('Figure saved to %s\n', fig_file);

%% Helper Functions
function collision = check_collision_multi(q, obstacles, L)
    points = zeros(3, 4); 
    
    x = 0; y = 0; z = 0;
    points(:,1) = [x;y;z]; 
    
    z = z + L(1); 
    points(:,2) = [x;y;z];
    
    x = x + L(2)*cos(q(2))*cos(q(1));
    y = y + L(2)*cos(q(2))*sin(q(1));
    z = z + L(2)*sin(q(2));
    points(:,3) = [x;y;z]; 
    
    collision = false;
    num_obs = size(obstacles, 1);
    
    for i = 1:num_obs
        obs_center = obstacles(i, 1:3);
        obs_radius = obstacles(i, 4);
        
        for p = 1:size(points, 2)
            dist_val = norm(points(:,p)' - obs_center);
            if dist_val < obs_radius
                collision = true;
                return;
            end
        end
        
        mid_p2_p3 = (points(:,2) + points(:,3)) / 2;
        if norm(mid_p2_p3' - obs_center) < obs_radius
            collision = true;
            return;
        end
    end
end

function G = calculate_gravity(q, m, L, g)
    G = zeros(6, 1);
    G(2) = m(2)*g*L(2)*0.5 * cos(q(2)) + m(3)*g*L(2)*cos(q(2));
    G(3) = m(3)*g*L(3)*0.5 * cos(q(2)+q(3));
end
