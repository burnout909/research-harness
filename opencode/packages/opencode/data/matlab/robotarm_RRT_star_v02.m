% robotarm_RRT_star_v02.m
% 2-Link Robot Arm Path Planning using RRT* (Optimal RRT) - Baseline Experiment
% Date: 2026-02-28
% Version: v02 (Added data logging and image export)

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
nodes(1).coord = q_start;
nodes(1).parent = 0;
nodes(1).cost = 0;

% Visualization Setup (Hidden for batch run)
f = figure('Color', 'w', 'Position', [100, 100, 1000, 500], 'Visible', 'off');
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
fprintf('Starting RRT* Optimization (v02)...\n');
tic;

for i = 1:max_iter
    % 3.1 Sampling
    if rand < goal_bias
        q_rand = q_goal;
    else
        q_rand = [rand*2*pi - pi, rand*2*pi - pi];
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
    
    % 3.4 Collision Check
    if ~check_collision(q_new, q_near, L1, L2, obstacles) % Fixed args order for logic
        
        % 3.5 Choose Parent
        min_cost = nodes(nearest_idx).cost + norm(q_new - q_near);
        best_parent = nearest_idx;
        
        neighbor_idxs = find(dists <= search_radius);
        
        for idx = neighbor_idxs
            cost_via_neighbor = nodes(idx).cost + norm(q_new - nodes(idx).coord);
            if cost_via_neighbor < min_cost
                if ~check_collision(q_new, nodes(idx).coord, L1, L2, obstacles)
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
        
        % 3.6 Rewire
        for idx = neighbor_idxs
            cost_via_new = nodes(new_idx).cost + norm(nodes(idx).coord - q_new);
            if cost_via_new < nodes(idx).cost
                if ~check_collision(q_new, nodes(idx).coord, L1, L2, obstacles)
                    nodes(idx).parent = new_idx;
                    nodes(idx).cost = cost_via_new;
                end
            end
        end
        
        % Plot edges (only for final result, skipped loop drawing for speed)
    end
end
sim_time = toc;

%% 4. Extract Path & Save Results
dists_to_goal = arrayfun(@(n) norm(n.coord - q_goal), nodes);
[min_dist_goal, goal_idx] = min(dists_to_goal);

result_data = struct();
result_data.parameters.max_iter = max_iter;
result_data.parameters.step_size = step_size;
result_data.parameters.search_radius = search_radius;
result_data.time = sim_time;

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
    result_data.success = true;
    result_data.cost = nodes(goal_idx).cost;
    result_data.path = path_q;
    
    % Final Visualization
    subplot(1,2,2);
    % Plot all edges (grey)
    for k = 2:length(nodes)
        p = nodes(k).parent;
        if p > 0
            plot([nodes(p).coord(1), nodes(k).coord(1)], [nodes(p).coord(2), nodes(k).coord(2)], '-', 'Color', [0.9 0.9 0.9]);
        end
    end
    plot(path_q(:,1), path_q(:,2), 'r-', 'LineWidth', 2);
    
    subplot(1,2,1);
    % Draw final path robot configurations
    % Draw start
    [xe, ye, x_elbow, y_elbow] = forward_kinematics(q_start, L1, L2);
    plot([0, x_elbow, xe], [0, y_elbow, ye], 'g-o', 'LineWidth', 2);
    % Draw goal
    [xe, ye, x_elbow, y_elbow] = forward_kinematics(q_goal, L1, L2);
    plot([0, x_elbow, xe], [0, y_elbow, ye], 'r-o', 'LineWidth', 2);
    % Draw path trace
    for j = 1:5:size(path_q, 1) % Sampled frames
        [xe, ye, x_elbow, y_elbow] = forward_kinematics(path_q(j,:), L1, L2);
        plot([0, x_elbow, xe], [0, y_elbow, ye], 'b-', 'Color', [0 0 1 0.2]);
    end
    title(sprintf('Optimized Path (Cost: %.2f)', result_data.cost));
else
    fprintf('Failed to reach goal within tolerance.\n');
    result_data.success = false;
    result_data.cost = Inf;
    result_data.path = [];
end

% Save Outputs
output_dir = fullfile(pwd, '..', 'outputs');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

img_file = fullfile(output_dir, 'RRT_star_v02_result.png');
saveas(f, img_file);
fprintf('Saved plot to %s\n', img_file);

mat_file = fullfile(output_dir, 'RRT_star_v02_data.mat');
save(mat_file, 'nodes', 'result_data', 'obstacles');
fprintf('Saved data to %s\n', mat_file);

fprintf('Simulation Complete. Time: %.2f s, Nodes: %d\n', sim_time, length(nodes));


%% Helper Functions
function [xe, ye, x_elbow, y_elbow] = forward_kinematics(q, L1, L2)
    x_elbow = L1 * cos(q(1));
    y_elbow = L1 * sin(q(1));
    xe = x_elbow + L2 * cos(q(1) + q(2));
    ye = y_elbow + L2 * sin(q(1) + q(2));
end

function collision = check_collision(q_start, q_end, L1, L2, obstacles)
    steps = 5; % Reduced for speed
    collision = false;
    for s = 0:steps
        alpha = s / steps;
        q = q_start * (1 - alpha) + q_end * alpha;
        [xe, ye, x_elbow, y_elbow] = forward_kinematics(q, L1, L2);
        if check_line_collision([0, 0], [x_elbow, y_elbow], obstacles) || ...
           check_line_collision([x_elbow, y_elbow], [xe, ye], obstacles)
            collision = true; return;
        end
    end
end

function hit = check_line_collision(p1, p2, obstacles)
    hit = false;
    for i = 1:size(obstacles, 1)
        ox = obstacles(i,1); oy = obstacles(i,2); r = obstacles(i,3);
        v = p2 - p1; w = [ox, oy] - p1;
        c1 = dot(w, v); c2 = dot(v, v);
        if c2 == 0, dist = norm([ox, oy] - p1);
        elseif c1 <= 0, dist = norm([ox, oy] - p1);
        elseif c2 <= c1, dist = norm([ox, oy] - p2);
        else, b = c1 / c2; pb = p1 + b * v; dist = norm([ox, oy] - pb);
        end
        if dist <= r, hit = true; return; end
    end
end
