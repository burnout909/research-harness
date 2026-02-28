% robotarm_RRT_star_v01.m
% 2-Link Robot Arm Path Planning using RRT* (Optimal RRT)
% Features:
% - 2-Link Planar Arm Kinematics
% - Configuration Space (C-Space) Sampling
% - Link-level Collision Detection (not just end-effector)
% - Path Optimization (Rewiring)

clear; clc; close all;

%% 1. Experiment Setup
% Robot Parameters
L1 = 1.0; % Length of link 1
L2 = 1.0; % Length of link 2
link_width = 0.1;

% Environment (Obstacles: [x, y, radius])
obstacles = [
    1.0, 1.0, 0.4;
    -0.5, 1.5, 0.3;
    0.5, -0.5, 0.3
];

% Task Definition (Joint Angles in Radians)
q_start = [0, 0];          % Start configuration
q_goal = [pi/2, pi/4];     % Goal configuration
goal_tol = 0.1;            % Tolerance to reach goal

% RRT* Parameters
max_iter = 3000;
step_size = 0.1;           % Max angle change per step
search_radius = 0.5;       % Rewiring radius
goal_bias = 0.1;           % Probability to sample goal

%% 2. Initialization
nodes(1).coord = q_start;  % Joint angles [theta1, theta2]
nodes(1).parent = 0;
nodes(1).cost = 0;
nodes(1).coord_end = forward_kinematics(q_start, L1, L2); % End effector pos (for vis)

% Visualization Setup
f = figure('Color', 'w', 'Position', [100, 100, 1000, 500]);
subplot(1,2,1); hold on; grid on; axis equal;
title('Workspace (Robot Arm)');
xlabel('X (m)'); ylabel('Y (m)');
axis([-2.5 2.5 -2.5 2.5]);

% Draw Obstacles
for i = 1:size(obstacles, 1)
    rectangle('Position', [obstacles(i,1)-obstacles(i,3), obstacles(i,2)-obstacles(i,3), ...
               2*obstacles(i,3), 2*obstacles(i,3)], 'Curvature', [1 1], 'FaceColor', [0.2 0.2 0.2]);
end

subplot(1,2,2); hold on; grid on; axis equal;
title('C-Space (Joint Angles)');
xlabel('\theta_1 (rad)'); ylabel('\theta_2 (rad)');
axis([-pi pi -pi pi]);
plot(q_start(1), q_start(2), 'go', 'MarkerFaceColor', 'g');
plot(q_goal(1), q_goal(2), 'ro', 'MarkerFaceColor', 'r');

%% 3. RRT* Main Loop
fprintf('Starting RRT* Optimization...\n');

for i = 1:max_iter
    % 3.1 Sampling
    if rand < goal_bias
        q_rand = q_goal;
    else
        q_rand = [rand*2*pi - pi, rand*2*pi - pi]; % Random [-pi, pi]
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
    
    % 3.4 Collision Check (Robot Body)
    if ~check_collision(q_near, q_new, L1, L2, obstacles)
        
        % 3.5 Choose Parent (Cost Optimization)
        min_cost = nodes(nearest_idx).cost + norm(q_new - q_near);
        best_parent = nearest_idx;
        
        % Find neighbors within radius
        neighbor_idxs = find(dists <= search_radius);
        
        for idx = neighbor_idxs
            cost_via_neighbor = nodes(idx).cost + norm(q_new - nodes(idx).coord);
            if cost_via_neighbor < min_cost
                if ~check_collision(nodes(idx).coord, q_new, L1, L2, obstacles)
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
        
        % 3.6 Rewire (Optimize Neighbors)
        for idx = neighbor_idxs
            cost_via_new = nodes(new_idx).cost + norm(nodes(idx).coord - q_new);
            if cost_via_new < nodes(idx).cost
                if ~check_collision(q_new, nodes(idx).coord, L1, L2, obstacles)
                    nodes(idx).parent = new_idx;
                    nodes(idx).cost = cost_via_new;
                    % Note: Strictly, we should update children costs recursively here,
                    % but skipped for basic performance.
                end
            end
        end
        
        % Plotting (C-Space)
        if mod(i, 50) == 0
            subplot(1,2,2);
            plot([nodes(best_parent).coord(1), q_new(1)], [nodes(best_parent).coord(2), q_new(2)], 'b-', 'Color', [0.8 0.8 0.8]);
            plot(q_new(1), q_new(2), 'b.', 'MarkerSize', 2);
            drawnow limitrate;
        end
        
        % Check Goal
        if norm(q_new - q_goal) < goal_tol
            fprintf('Goal region reached at iter %d! Continuing for optimization...\n', i);
        end
    end
end

%% 4. Extract Path
% Find node closest to goal
dists_to_goal = arrayfun(@(n) norm(n.coord - q_goal), nodes);
[min_dist_goal, goal_idx] = min(dists_to_goal);

if min_dist_goal < goal_tol
    fprintf('Path Found! Cost: %.4f\n', nodes(goal_idx).cost);
    
    % Backtrack
    curr = goal_idx;
    path_idx = [];
    while curr ~= 0
        path_idx = [curr, path_idx];
        curr = nodes(curr).parent;
    end
    
    path_q = reshape([nodes(path_idx).coord], 2, [])';
    
    % Visualize Final Path
    subplot(1,2,2);
    plot(path_q(:,1), path_q(:,2), 'r-', 'LineWidth', 2);
    
    subplot(1,2,1);
    for j = 1:size(path_q, 1)
        q = path_q(j, :);
        [xe, ye, x_elbow, y_elbow] = forward_kinematics(q, L1, L2);
        
        % Draw Robot
        % Clear previous robot lines (tricky in loop, just draw over or use handle)
        if j > 1; delete(h_arm); end
        h_arm = plot([0, x_elbow, xe], [0, y_elbow, ye], 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
        pause(0.05);
    end
    title('Robot Arm Motion (Optimized)');
else
    fprintf('Failed to reach goal within tolerance.\n');
end

%% Helper Functions

function [xe, ye, x_elbow, y_elbow] = forward_kinematics(q, L1, L2)
    x_elbow = L1 * cos(q(1));
    y_elbow = L1 * sin(q(1));
    xe = x_elbow + L2 * cos(q(1) + q(2));
    ye = y_elbow + L2 * sin(q(1) + q(2));
end

function collision = check_collision(q_start, q_end, L1, L2, obstacles)
    % Interpolate between configurations to check swept volume
    steps = 10;
    collision = false;
    
    for s = 0:steps
        alpha = s / steps;
        q = q_start * (1 - alpha) + q_end * alpha;
        [xe, ye, x_elbow, y_elbow] = forward_kinematics(q, L1, L2);
        
        % Check Link 1 (Origin to Elbow)
        if check_line_collision([0, 0], [x_elbow, y_elbow], obstacles)
            collision = true; return;
        end
        
        % Check Link 2 (Elbow to End-Effector)
        if check_line_collision([x_elbow, y_elbow], [xe, ye], obstacles)
            collision = true; return;
        end
    end
end

function hit = check_line_collision(p1, p2, obstacles)
    hit = false;
    for i = 1:size(obstacles, 1)
        ox = obstacles(i,1); oy = obstacles(i,2); r = obstacles(i,3);
        % Distance from point (center of obstacle) to line segment p1-p2
        % Vector formulation
        v = p2 - p1;
        w = [ox, oy] - p1;
        
        c1 = dot(w, v);
        c2 = dot(v, v);
        
        if c2 == 0 % p1 and p2 are same
            dist = norm([ox, oy] - p1);
        elseif c1 <= 0
            dist = norm([ox, oy] - p1);
        elseif c2 <= c1
            dist = norm([ox, oy] - p2);
        else
            b = c1 / c2;
            pb = p1 + b * v;
            dist = norm([ox, oy] - pb);
        end
        
        if dist <= r
            hit = true; return;
        end
    end
end
