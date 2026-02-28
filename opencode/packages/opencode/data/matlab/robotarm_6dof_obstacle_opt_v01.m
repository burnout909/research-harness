% robotarm_6dof_obstacle_opt_v01.m
% 6-DOF Robot Arm Path Planning with Obstacle Avoidance & Energy Optimization
% Algorithm: RRT* (Rapidly-exploring Random Tree Star) in Configuration Space
% Cost Function: Weighted sum of joint displacements (proxy for energy)
% Date: 2026-02-28

clear; clc; close all;

%% 1. Simulation Setup
% 6-DOF DH Parameters (Standard PUMA-like or Generic 6-DOF)
% [a, alpha, d, theta_offset]
L = [
    0,      pi/2,  0.5,  0;    % Joint 1
    0.5,    0,     0,    0;    % Joint 2
    0.1,    pi/2,  0,    0;    % Joint 3
    0,     -pi/2,  0.4,  0;    % Joint 4
    0,      pi/2,  0,    0;    % Joint 5
    0,      0,     0.1,  0     % Joint 6
];

% Environment: Spherical Obstacles [x, y, z, radius]
obstacles = [
    0.4, 0.2, 0.4, 0.25;   % Obstacle 1
    -0.3, 0.4, 0.6, 0.20   % Obstacle 2
];

% Joint Limits (rad)
q_min = [-pi, -pi/2, -pi, -pi, -pi, -pi];
q_max = [ pi,  pi/2,  pi,  pi,  pi,  pi];

% Task: Start and Goal Configuration (Joint Angles)
q_start = [0, 0, 0, 0, 0, 0];
q_goal  = [pi/2, pi/4, -pi/4, 0, pi/4, 0];

% Optimization Parameters
max_iter = 1000;         % Max iterations
step_size = 0.2;         % Max joint movement per step (rad)
search_radius = 0.8;     % RRT* rewiring radius
goal_bias = 0.1;         % 10% chance to sample goal directly

%% 2. RRT* Initialization
nodes(1).coord = q_start;
nodes(1).parent = 0;
nodes(1).cost = 0;

fprintf('Starting 6-DOF RRT* Optimization...\n');
tic;

%% 3. Main Loop
for i = 1:max_iter
    % 3.1 Sampling
    if rand < goal_bias
        q_rand = q_goal;
    else
        q_rand = q_min + (q_max - q_min) .* rand(1, 6);
    end
    
    % 3.2 Nearest Node
    dists = arrayfun(@(n) norm(n.coord - q_rand), nodes);
    [~, nearest_idx] = min(dists);
    q_near = nodes(nearest_idx).coord;
    
    % 3.3 Steer
    dir = q_rand - q_near;
    dist = norm(dir);
    if dist > step_size
        q_new = q_near + (dir / dist) * step_size;
    else
        q_new = q_rand;
    end
    
    % Check Joint Limits
    q_new = max(min(q_new, q_max), q_min);
    
    % 3.4 Collision Check
    if ~check_collision_6dof(q_new, q_near, L, obstacles)
        
        % 3.5 Choose Parent (Energy Cost: Sum of squared joint diffs)
        % Cost = Previous Cost + ||delta_q||^2 (Proxy for energy/torque)
        edge_cost = norm(q_new - q_near)^2; 
        min_cost = nodes(nearest_idx).cost + edge_cost;
        best_parent = nearest_idx;
        
        % Find neighbors for rewiring
        neighbor_idxs = find(dists <= search_radius);
        
        for idx = neighbor_idxs
            % Cost via neighbor
            pot_edge_cost = norm(q_new - nodes(idx).coord)^2;
            cost_via_neighbor = nodes(idx).cost + pot_edge_cost;
            
            if cost_via_neighbor < min_cost
                if ~check_collision_6dof(q_new, nodes(idx).coord, L, obstacles)
                    min_cost = cost_via_neighbor;
                    best_parent = idx;
                end
            end
        end
        
        % Add Node
        new_idx = length(nodes) + 1;
        nodes(new_idx).coord = q_new;
        nodes(new_idx).parent = best_parent;
        nodes(new_idx).cost = min_cost;
        
        % 3.6 Rewire (Optimize Tree)
        for idx = neighbor_idxs
            pot_edge_cost = norm(nodes(idx).coord - q_new)^2;
            cost_via_new = nodes(new_idx).cost + pot_edge_cost;
            
            if cost_via_new < nodes(idx).cost
                 if ~check_collision_6dof(q_new, nodes(idx).coord, L, obstacles)
                    nodes(idx).parent = new_idx;
                    nodes(idx).cost = cost_via_new;
                 end
            end
        end
        
        % Early Exit if Goal Reached close enough
        if norm(q_new - q_goal) < step_size
            % Add goal node explicitly to finish
            final_cost = nodes(new_idx).cost + norm(q_goal - q_new)^2;
            nodes(end+1).coord = q_goal;
            nodes(end).parent = new_idx;
            nodes(end).cost = final_cost;
            fprintf('Goal reached at iter %d!\n', i);
            break;
        end
    end
    
    if mod(i, 100) == 0
        fprintf('Iteration %d/%d, Nodes: %d\n', i, max_iter, length(nodes));
    end
end
sim_time = toc;

%% 4. Extract Path
dists_to_goal = arrayfun(@(n) norm(n.coord - q_goal), nodes);
[min_dist, goal_idx] = min(dists_to_goal);

path_found = false;
if min_dist < step_size * 2
    path_found = true;
    curr = goal_idx;
    path_idx = [];
    while curr ~= 0
        path_idx = [curr, path_idx];
        curr = nodes(curr).parent;
    end
    path_q = reshape([nodes(path_idx).coord], 6, [])';
    
    % Smooth Path (Simple Interpolation)
    t_original = 1:size(path_q, 1);
    t_smooth = linspace(1, size(path_q, 1), size(path_q, 1)*5);
    path_smooth = zeros(length(t_smooth), 6);
    for j=1:6
        path_smooth(:,j) = spline(t_original, path_q(:,j), t_smooth);
    end
    
else
    fprintf('Path NOT found.\n');
    path_q = [];
    path_smooth = [];
end

%% 5. Visualization & Saving
if path_found
    % Plot 3D Workspace
    fig = figure('Color', 'w', 'Position', [100, 100, 1000, 600], 'Visible', 'off');
    hold on; grid on; axis equal;
    view(3);
    xlabel('X'); ylabel('Y'); zlabel('Z');
    title('6-DOF Robot Path with Obstacle Avoidance');
    
    % Draw Obstacles
    [sx, sy, sz] = sphere(20);
    for k = 1:size(obstacles, 1)
        surf(sx*obstacles(k,4) + obstacles(k,1), ...
             sy*obstacles(k,4) + obstacles(k,2), ...
             sz*obstacles(k,4) + obstacles(k,3), ...
             'FaceColor', 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    end
    
    % Draw Start & Goal Robot
    draw_robot(q_start, L, 'g', 0.3); % Start (Green ghost)
    draw_robot(q_goal, L, 'b', 0.3);  % Goal (Blue ghost)
    
    % Draw Path Trace (End-effector only)
    ee_traj = [];
    for k = 1:size(path_smooth, 1)
        T_all = forward_kinematics_chain(path_smooth(k,:), L);
        ee_pos = T_all{end}(1:3, 4)';
        ee_traj = [ee_traj; ee_pos];
        
        % Draw intermediate robots sparsely
        if mod(k, 10) == 0
            draw_robot(path_smooth(k,:), L, 'k', 0.1);
        end
    end
    plot3(ee_traj(:,1), ee_traj(:,2), ee_traj(:,3), 'b-', 'LineWidth', 2);
    
    % Save Result
    output_dir = fullfile(pwd, '..', 'outputs');
    if ~exist(output_dir, 'dir'), mkdir(output_dir); end
    
    saveas(fig, fullfile(output_dir, 'robotarm_6dof_path.png'));
    save(fullfile(output_dir, 'robotarm_6dof_data.mat'), 'path_q', 'path_smooth', 'obstacles', 'sim_time');
    
    fprintf('Path optimized. Cost (Energy proxy): %.4f\n', nodes(goal_idx).cost);
    fprintf('Results saved to data/outputs/\n');
else
    fprintf('Optimization Failed.\n');
end

%% Helper Functions

function collision = check_collision_6dof(q1, q2, L, obstacles)
    % Check collision along the path segment (discretized)
    steps = 3; 
    collision = false;
    for s = 0:steps
        alpha = s/steps;
        q = q1 * (1-alpha) + q2 * alpha;
        
        % Check self or environment collision
        % Simplified: Check if any joint/link center is inside obstacle
        T_all = forward_kinematics_chain(q, L);
        
        for k = 1:size(obstacles, 1)
            ox=obstacles(k,1); oy=obstacles(k,2); oz=obstacles(k,3); r=obstacles(k,4);
            
            % Check each link end point
            for link = 1:6
                pos = T_all{link}(1:3, 4);
                if norm(pos - [ox;oy;oz]) < r + 0.05 % +0.05 safety margin
                    collision = true; return;
                end
            end
        end
    end
end

function draw_robot(q, L, color, alpha)
    T_all = forward_kinematics_chain(q, L);
    positions = [0, 0, 0]; % Base
    for i = 1:6
        pos = T_all{i}(1:3, 4)';
        positions = [positions; pos];
    end
    plot3(positions(:,1), positions(:,2), positions(:,3), '-o', ...
          'Color', color, 'LineWidth', 2, 'MarkerFaceColor', color);
end

function T_all = forward_kinematics_chain(q, L)
    % Returns cell array of transforms for each link
    T_all = cell(1, 6);
    T_curr = eye(4);
    
    for i = 1:6
        a = L(i, 1); alpha = L(i, 2); d = L(i, 3); theta_off = L(i, 4);
        theta = q(i) + theta_off;
        
        % DH Transform Matrix
        Ti = [cos(theta), -sin(theta)*cos(alpha),  sin(theta)*sin(alpha), a*cos(theta);
              sin(theta),  cos(theta)*cos(alpha), -cos(theta)*sin(alpha), a*sin(theta);
              0,           sin(alpha),             cos(alpha),            d;
              0,           0,                      0,                     1];
          
        T_curr = T_curr * Ti;
        T_all{i} = T_curr;
    end
end
