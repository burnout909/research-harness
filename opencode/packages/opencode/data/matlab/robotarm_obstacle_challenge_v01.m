%% Robot Arm Obstacle Challenge
% Experiment: robotarm_obstacle_challenge_v01
% Date: 2026-02-28
% Objective: Test RRT path planning with obstacle placed directly in the path center.
%            Analyze time delay caused by detour.

clear; clc; close all;

%% 1. Parameters & Setup
% Robot Parameters (Simplified 6-DOF)
L = [0.4, 0.4, 0.2, 0.1, 0.1, 0.05]; % Link lengths (m)
m = [5, 4, 3, 2, 1, 1]; % Link masses (kg)
g = 9.81;

% Constraints
tau_max = 20.0;      % N.m (Torque Limit)
vel_max = 3.0;       % rad/s
acc_max = 10.0;      % rad/s^2

% Environment (Obstacle Challenge - Centered)
% Original was [0.4, 0.0, 0.4], shifting to obstruct direct path
obs_center = [0.3, 0.2, 0.3]; % (x, y, z) - Harder position
obs_radius = 0.15;            % m

% Motion Task
q_start = [0, 0, 0, 0, 0, 0]';
q_goal = [pi/2, pi/4, 0, -pi/4, 0, 0]';

% Simulation Settings
dt = 0.01;
max_iter_rrt = 10000; % Increased iterations for harder obstacle

%% 2. RRT Path Planning (Joint Space)
fprintf('Step 1: Planning path using RRT (Obstacle at [%.1f, %.1f, %.1f])...\n', ...
    obs_center(1), obs_center(2), obs_center(3));

nodes(1).q = q_start;
nodes(1).parent = 0;
path_found = false;

% Simple RRT
rng(42); % Fix seed for reproducibility in this challenge
for i = 1:max_iter_rrt
    % Random Sampling
    if rand < 0.1
        q_rand = q_goal;
    else
        q_rand = q_start + (q_goal - q_start) .* rand(6, 1) + 0.3*randn(6,1); 
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
    
    step = 0.15; % Smaller step size for precision navigating obstacle
    q_new = q_near + min(step, min_dist) * dir;
    
    % Collision Check
    if ~check_collision(q_new, obs_center, obs_radius, L)
        nodes(end+1).q = q_new;
        nodes(end).parent = nearest_idx;
        
        if norm(q_new - q_goal) < 0.2
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
    fprintf('RRT failed to find a path. Using linear interpolation fallback (Collision likely).\n');
    waypoints = [q_start, q_goal];
else
    curr_idx = length(nodes);
    path_indices = [curr_idx];
    while nodes(curr_idx).parent ~= 0
        curr_idx = nodes(curr_idx).parent;
        path_indices = [curr_idx, path_indices];
    end
    waypoints = [nodes(path_indices).q];
end

%% 3. Time Optimization (Iterative Scaling)
fprintf('Step 2: Optimizing Trajectory Duration...\n');

T_opt = 4.0; % Initial guess (seconds) - start slower
iter = 0;
max_iter_opt = 30;
tolerance = 0.05; % Torque tolerance

% Prepare dense time vector for smooth trajectory
n_points = 150; % More points for smoother curve
t_norm = linspace(0, 1, n_points); % Normalized time 0 to 1
n_waypoints = size(waypoints, 2);
t_waypoints_norm = linspace(0, 1, n_waypoints);

% Optimization Loop
while iter < max_iter_opt
    iter = iter + 1;
    
    % Real time vector
    t_real = t_norm * T_opt;
    
    % Cubic Spline Interpolation
    q_traj = zeros(6, n_points);
    dq_traj = zeros(6, n_points);
    ddq_traj = zeros(6, n_points);
    
    for j=1:6
        % Position
        q_traj(j,:) = spline(t_waypoints_norm * T_opt, waypoints(j,:), t_real);
        
        % Finite difference for derivatives
        dq_traj(j, 1:end-1) = diff(q_traj(j,:)) ./ diff(t_real);
        dq_traj(j, end) = dq_traj(j, end-1);
        
        ddq_traj(j, 1:end-1) = diff(dq_traj(j,:)) ./ diff(t_real);
        ddq_traj(j, end) = ddq_traj(j, end-1);
    end
    
    % Inverse Dynamics
    tau_traj = zeros(6, n_points);
    M_diag = [0.5; 0.5; 0.4; 0.2; 0.1; 0.05]; % Diagonal inertia
    
    for k = 1:n_points
        % Gravity compensation approximation
        G = calculate_gravity(q_traj(:,k), m, L, g);
        % Dynamics: tau = M*q_dd + G
        tau_traj(:, k) = M_diag .* ddq_traj(:, k) + G;
    end
    
    max_tau_val = max(max(abs(tau_traj)));
    
    fprintf('Iter %d: T = %.4f s, Max Torque = %.4f Nm (Limit: %.1f)\n', iter, T_opt, max_tau_val, tau_max);
    
    if abs(max_tau_val - tau_max) < tolerance || (max_tau_val < tau_max && iter > 10)
        fprintf('Converged!\n');
        break;
    end
    
    % Update Rule
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
results.experiment = 'robotarm_obstacle_challenge_v01';
results.obs_center = obs_center;
results.T_opt = T_opt;
results.max_torque = max_tau_val;
results.waypoints = waypoints;
results.time = t_real;
results.q = q_traj;
results.dq = dq_traj;
results.tau = tau_traj;
results.converged = (max_tau_val <= tau_max * 1.1);

% Define paths
current_file_path = mfilename('fullpath');
[script_dir, ~, ~] = fileparts(current_file_path);
if isempty(script_dir), script_dir = pwd; end

output_dir = fullfile(script_dir, '..', 'outputs');
mat_file = fullfile(script_dir, 'robotarm_obstacle_challenge_v01_result.mat');
fig_file = fullfile(output_dir, 'robotarm_obstacle_challenge_v01_plot.png');

if ~exist(output_dir, 'dir'), mkdir(output_dir); end
save(mat_file, '-struct', 'results');
fprintf('Results saved to %s\n', mat_file);

% Plot
f = figure('Visible', 'off', 'Position', [100, 100, 1000, 800]);

subplot(2,2,1);
plot3(waypoints(1,:), waypoints(2,:), waypoints(3,:), 'b-o', 'LineWidth', 1.5);
hold on;
% Draw obstacle (approximate sphere)
[X,Y,Z] = sphere(20);
surf(X*obs_radius + obs_center(1), Y*obs_radius + obs_center(2), Z*obs_radius + obs_center(3), ...
    'FaceColor', 'r', 'FaceAlpha', 0.5, 'EdgeColor', 'none');
grid on;
title(sprintf('RRT Path (3D Joint Space Projection)\nObstacle at [%.1f, %.1f, %.1f]', obs_center));
xlabel('q1'); ylabel('q2'); zlabel('q3');
view(3);

subplot(2,2,2);
plot(t_real, q_traj'); 
title('Joint Trajectories'); ylabel('Angle (rad)'); grid on;
legend('q1','q2','q3','q4','q5','q6', 'Location', 'best');

subplot(2,2,3);
plot(t_real, tau_traj'); 
title('Torque Profiles'); xlabel('Time (s)'); ylabel('Torque (Nm)'); 
yline(tau_max, 'r--'); yline(-tau_max, 'r--');
grid on;

subplot(2,2,4);
bar([T_opt]);
title(sprintf('Optimal Time: %.2f s', T_opt));
xticklabels({'Time'});
grid on;

saveas(f, fig_file);
fprintf('Figure saved to %s\n', fig_file);
disp('Simulation complete.');

%% Helper Functions
function collision = check_collision(q, obs_center, obs_radius, L)
    % Simplified FK logic for collision check
    % Checking end-effector and elbow points roughly
    
    % Base (0,0,0)
    p0 = [0;0;0];
    
    % Joint 2 (after Link 1) - Z axis
    p1 = [0; 0; L(1)];
    
    % Joint 3
    p2 = p1 + [L(2)*cos(q(2))*cos(q(1)); L(2)*cos(q(2))*sin(q(1)); L(2)*sin(q(2))];
    
    % End-Effector (approximate)
    % Simplified for check: just checking if p2 or midpoints are in obstacle
    
    % Check p2 (Elbow)
    dist_p2 = norm(p2' - obs_center);
    
    % Check midpoint of Link 2
    pmid = (p1 + p2) / 2;
    dist_pmid = norm(pmid' - obs_center);
    
    if dist_p2 < obs_radius || dist_pmid < obs_radius
        collision = true;
    else
        collision = false;
    end
end

function G = calculate_gravity(q, m, L, g)
    G = zeros(6, 1);
    % Simplified gravity model focusing on main lifting joints
    G(2) = m(2)*g*L(2)*0.5 * cos(q(2)) + m(3)*g*L(2)*cos(q(2));
    G(3) = m(3)*g*L(3)*0.5 * cos(q(2)+q(3));
end
