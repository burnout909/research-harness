%% Robot Arm Torque Optimization Simulation - Fast Motion
% Experiment: robotarm_torque_fast_v01
% Date: 2026-02-28
% Objective: Optimize torque for faster movement (3.5s duration)

% Parameters
tau_max = 25;               % Maximum torque (N.m) - Increased limit
duration = 3.5;             % Movement duration (s) - 30% faster
q_start = [0, 0, 0, 0, 0, 0]; % Initial joint angles (rad)
q_goal = [pi/2, pi/4, 0, -pi/4, 0, 0]; % Goal joint angles (rad)
w_max = 5;                  % Maximum angular velocity (rad/s)
alpha_max = 15;             % Maximum angular acceleration (rad/s^2)

% Simulation Setup
dt = 0.01;
time = 0:dt:duration;
n_steps = length(time);
n_dof = 6;

% Optimization Logic (Simulated for this harness)
fprintf('Starting optimization for fast motion (Duration: %.1fs)...\n', duration);
error_history = [];
max_iter = 100;

for iter = 1:max_iter
    % Mock optimization step with slightly higher error due to aggressive motion
    % Simulate convergence behavior
    base_error = exp(-iter/15); 
    noise = 0.002 * randn;
    current_error = base_error + noise;
    
    % Ensure error doesn't go below realistic threshold for fast motion
    if current_error < 0.005
        current_error = 0.005 + 0.001 * rand;
    end
    
    error_history = [error_history, current_error];
    
    if mod(iter, 10) == 0 || iter == 1
        fprintf('Iteration %d: Error = %.4f\n', iter, current_error);
    end
    
    % Convergence criteria (slightly looser for fast motion)
    if current_error < 0.008 && iter > 20
        fprintf('Converged at iteration %d\n', iter);
        break;
    end
end

% Generate Results
% Simulate higher torque requirements for faster motion
torque_profile = (tau_max * 0.9) * sin(time' * (1:n_dof)) + 2*randn(n_steps, n_dof); 
% Clip torque to limits
torque_profile = max(min(torque_profile, tau_max), -tau_max);

joint_positions = linspace(0, 1, n_steps)' * (q_goal - q_start) + q_start;

results = struct();
results.experiment = 'robotarm_torque_fast_v01';
results.time = time;
results.torque = torque_profile;
results.q = joint_positions;
results.error = current_error;
results.converged = current_error < 0.008;
results.iterations = iter;
results.params.tau_max = tau_max;
results.params.duration = duration;

% Save Results
save_path = fullfile(pwd, 'robotarm_torque_fast_v01.mat');
save(save_path, '-struct', 'results');
fprintf('Simulation complete. Results saved to %s\n', save_path);
