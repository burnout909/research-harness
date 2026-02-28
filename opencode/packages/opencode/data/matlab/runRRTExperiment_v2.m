function runRRTExperiment_v2(maxConn, valDist, showAnimation)
    if ischar(maxConn), maxConn = str2double(maxConn); end
    if ischar(valDist), valDist = str2double(valDist); end
    if nargin < 3, showAnimation = false; end
    if ischar(showAnimation), showAnimation = str2double(showAnimation); end
    try
        tic;
        scenario = robotScenario(UpdateRate=10);
        addMesh(scenario,"Box",Position=[0.35 0 0.2],Size=[0.5 0.9 0.05],Color=[0.7 0.7 0.7],Collision="mesh");
        franka = loadrobot("frankaEmikaPanda", "DataFormat", "row");
        robot = robotPlatform("Manipulator", scenario, RigidBodyTree=franka, ReferenceFrame="ENU");
        initialConfig = [0, -0.785, 0, -2.356, 0, 1.571, 0.785, 0.04, 0.04];
        setup(scenario);
        move(robot, "joint", initialConfig);
        planner = manipulatorRRT(robot.RigidBodyTree, scenario.CollisionMeshes);
        planner.MaxConnectionDistance = maxConn;
        planner.ValidationDistance = valDist;
        planner.IgnoreSelfCollision = true;
        pickUpConfig = [0.2371 -0.0200 0.0542 -2.2272 0.0013 2.2072 -0.9670 0.0400 0.0400];
        path = plan(planner, initialConfig, pickUpConfig);
        calcTime = toc;
        pathLength = size(path, 1);
        isSuccess = (pathLength > 0);
        if showAnimation && isSuccess
            ax = show3D(scenario, Visuals="on", Collisions="off");
            view(81,19); light;
            numState = 10;
            interpStates = interpolate(planner, path, numState);
            for idx = 1:size(interpStates, 1)
                jointConfig = interpStates(idx, :);
                move(robot, "joint", jointConfig);
                show3D(scenario, FastUpdate=true, Parent=ax, Visuals="on", Collisions="off");
                drawnow; advance(scenario);
            end
        end
        resultStruct = struct("MaxConnection", maxConn, "Validation", valDist, "Success", isSuccess, "Time", calcTime, "PathLength", pathLength, "Error", "");
        fid = fopen("experiment_result.json", "w");
        fprintf(fid, "%s", jsonencode(resultStruct));
        fclose(fid);
        disp("실험 완료!");
    catch ME
        resultStruct = struct("MaxConnection", maxConn, "Validation", valDist, "Success", false, "Time", 0, "PathLength", 0, "Error", ME.message);
        fid = fopen("experiment_result.json", "w");
        fprintf(fid, "%s", jsonencode(resultStruct));
        fclose(fid);
    end
end
