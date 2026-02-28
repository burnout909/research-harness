try
    % Run the RRT experiment with default parameters (MaxConn=0.5, ValDist=0.1)
    % Disable animation for headless execution
    runRRTExperiment_v02(0.5, 0.1, false);
catch ME
    disp(['Error running experiment: ' ME.message]);
end