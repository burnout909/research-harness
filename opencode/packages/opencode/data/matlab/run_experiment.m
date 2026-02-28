% Wrapper script to run the RRT experiment
% Try running with visualization enabled by default
% Usage: run_experiment

% Add current folder to path
addpath(pwd);

% Run the experiment with default parameters
% MaxConnectionDistance = 0.5
% ValidationDistance = 0.05
% Animation = true
disp('Running RRT Experiment with default parameters...');
try
    runRRTExperiment(0.5, 0.05, true);
    if exist('experiment_result.json', 'file')
        type('experiment_result.json');
    end
catch e
    disp('Error running experiment:');
    disp(e.message);
end
