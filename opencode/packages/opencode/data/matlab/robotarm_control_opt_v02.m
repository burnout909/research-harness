% robotarm_control_opt_v02.m
% 1-DOF Robot Arm Trajectory Optimization
% Minimize energy: J = integral(u^2) dt
% Subject to dynamics: J_arm * theta_ddot + b_arm * theta_dot = u
% Constraints: |u| <= u_max, theta(T) = theta_target

clear; clc; close all;

%% Parameters
J_arm = 0.1;       % Inertia (kg*m^2)
b_arm = 0.1;       % Damping (N*m*s/rad)
u_max = 20.0;      % Max torque (N*m)
theta_target = 1.0;% Target position (rad)
T = 2.0;           % Duration (s)
dt = 0.01;         % Time step
N = floor(T/dt);   % Number of steps

%% Optimization Setup
% Decision variables: u (control input) for N steps
u0 = zeros(N, 1);  % Initial guess
lb = -u_max * ones(N, 1);
ub = u_max * ones(N, 1);

% Optimize using fmincon (requires Optimization Toolbox)
% If not available, we can switch to a simple PID simulation
options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp', 'MaxIterations', 100);

% Objective Function: Minimize energy
obj_fun = @(u) sum(u.^2) * dt;

% Constraints Function
nonlcon = @(u) robot_dynamics_constraints(u, J_arm, b_arm, theta_target, dt, N);

%% Run Optimization
fprintf('Starting optimization...\n');
try
    [u_opt, fval, exitflag, output] = fmincon(obj_fun, u0, [], [], [], [], lb, ub, nonlcon, options);
    converged = (exitflag > 0);
catch ME
    fprintf('Optimization failed: %s\n', ME.message);
    u_opt = u0; % Fallback
    converged = false;
    fval = 0;
    output.iterations = 0;
end

%% Simulation with Optimal Input
t = (0:N-1)' * dt;
[theta, theta_dot] = simulate_robot(u_opt, J_arm, b_arm, dt, N);

%% Save Results
results.time = t;
results.torque = u_opt;
results.position = theta;
results.velocity = theta_dot;
results.cost = fval;
results.iterations = output.iterations;
results.converged = converged;

% Ensure directory exists
if ~exist('data/matlab', 'dir')
    mkdir('data/matlab');
end

save('data/matlab/robotarm_control_opt_v02_result.mat', '-struct', 'results');
fprintf('Optimization finished. Results saved to data/matlab/robotarm_control_opt_v02_result.mat\n');

%% Helper Functions
function [c, ceq] = robot_dynamics_constraints(u, J, b, target, dt, N)
    [theta, theta_dot] = simulate_robot(u, J, b, dt, N);
    
    % Inequality constraints (c <= 0)
    c = []; 
    
    % Equality constraints (ceq = 0)
    % Final state constraints
    ceq = [theta(end) - target; theta_dot(end)];
end

function [theta, theta_dot] = simulate_robot(u, J, b, dt, N)
    theta = zeros(N, 1);
    theta_dot = zeros(N, 1);
    
    % Euler integration
    for k = 1:N-1
        theta_ddot = (u(k) - b * theta_dot(k)) / J;
        theta_dot(k+1) = theta_dot(k) + theta_ddot * dt;
        theta(k+1) = theta(k) + theta_dot(k) * dt;
    end
end
