function runRRTExperiment(maxConn, valDist, showAnimation)
    if ischar(maxConn), maxConn = str2double(maxConn); end
    if ischar(valDist), valDist = str2double(valDist); end
    if nargin < 3, showAnimation = false; end
    if ischar(showAnimation), showAnimation = str2double(showAnimation); end

    try
        tic;

        % 1. 시나리오 및 정적 장애물 세팅
        scenario = robotScenario(UpdateRate=10);
        addMesh(scenario,"Box",Position=[0.35 0 0.2],Size=[0.5 0.9 0.05],Color=[0.7 0.7 0.7],Collision="mesh");
        addMesh(scenario,"Box",Position=[0 -0.6 0.2],Size=[1.3 0.4 0.235],Color=[0.7 0.7 0.7],Collision="mesh");
        addMesh(scenario,"Box",Position=[0.3 -0.25 0.4],Size=[0.8 0.03 0.35],Color=[0.7 0.7 0.7],Collision="mesh");

        % 정적 장애물만 따로 저장 (플래너용)
        staticObstacles = scenario.CollisionMeshes;

        % 2. 움직일 수 있는 목표 상자 생성
        boxToMove = robotPlatform("Box", scenario, Collision="mesh", InitialBasePosition=[0.48 0.13 0.25]);
        updateMesh(boxToMove, "Cuboid", Collision="mesh", Size=[0.06 0.06 0.1], Color=[0.9 0.0 0.0]);

        % 3. 로봇 불러오기
        franka = loadrobot("frankaEmikaPanda", "DataFormat", "row");
        robot = robotPlatform("Manipulator", scenario, RigidBodyTree=franka, ReferenceFrame="ENU");

        initialConfig = [0, -0.785, 0, -2.356, 0, 1.571, 0.785, 0.04, 0.04];
        setup(scenario);
        move(robot, "joint", initialConfig);

        % 4. RRT 플래너 세팅
        planner = manipulatorRRT(robot.RigidBodyTree, staticObstacles);
        planner.MaxConnectionDistance = maxConn;
        planner.ValidationDistance = valDist;
        planner.IgnoreSelfCollision = true;

        % 5. 픽업 위치로의 경로 계획
        pickUpConfig = [0.2371 -0.0200 0.0542 -2.2272 0.0013 2.2072 -0.9670 0.0400 0.0400];
        path = plan(planner, initialConfig, pickUpConfig);

        % 5-1. 결과 메트릭 계산 (실제 조인트 이동 거리 총합)
        calcTime = toc;
        if isempty(path)
            pathLength = 0;
            isSuccess = false;
        else
            pathLength = sum(sqrt(sum(diff(path).^2, 2)));
            isSuccess = true;
        end

        % 6. 시각화 모드: 이동 -> 집기 -> 번쩍 들기 -> 넘어가기 -> 내려놓기
        if showAnimation && isSuccess
            ax = show3D(scenario, Visuals="on", Collisions="off");
            view(81,19); light;
            title(sprintf('AI Agent Optimized Pick-and-Place'));

            % (1) 상자 앞까지 이동
            interpStates = interpolate(planner, path, 10);
            for idx = 1:size(interpStates, 1)
                move(robot, "joint", interpStates(idx, :));
                show3D(scenario, FastUpdate=true, Parent=ax, Visuals="on", Collisions="off");
                drawnow; advance(scenario);
            end

            % (2) 상자 집기 (Attach)
            attach(robot, "Box", "panda_hand", ChildToParentTransform=trvec2tform([0 0 0.1]));
            show3D(scenario, FastUpdate=true, Parent=ax, Visuals="on", Collisions="off");
            drawnow;

            % (3) 상자 쥐고 허공으로 번쩍 들기 (중간 경유지)
            liftConfig = initialConfig;
            path_lift = plan(planner, pickUpConfig, liftConfig);
            if ~isempty(path_lift)
                interpStates_lift = interpolate(planner, path_lift, 10);
                for idx = 1:size(interpStates_lift, 1)
                    move(robot, "joint", interpStates_lift(idx, :));
                    show3D(scenario, FastUpdate=true, Parent=ax, Visuals="on", Collisions="off");
                    drawnow; advance(scenario);
                end
            end

            % (4) 벽 넘어 드롭 위치로 이동
            dropConfig = [-0.6564 0.2885 -0.3187 -1.5941 0.1103 1.8678 -0.2344 0.04 0.04];
            path_drop = plan(planner, liftConfig, dropConfig);
            if ~isempty(path_drop)
                interpStates_drop = interpolate(planner, path_drop, 10);
                for idx = 1:size(interpStates_drop, 1)
                    move(robot, "joint", interpStates_drop(idx, :));
                    show3D(scenario, FastUpdate=true, Parent=ax, Visuals="on", Collisions="off");
                    drawnow; advance(scenario);
                end
            end

            % (5) 상자 내려놓기 (Detach)
            detach(robot);
            show3D(scenario, FastUpdate=true, Parent=ax, Visuals="on", Collisions="off");
            drawnow;

            disp('벽 넘어 Pick and Place 완료!');
        end

        % 7. 결과를 JSON으로 저장
        resultStruct = struct('MaxConnection', maxConn, 'Validation', valDist, 'Success', isSuccess, 'Time', calcTime, 'PathLength', pathLength, 'Error', '');
        fid = fopen('experiment_result.json', 'w');
        fprintf(fid, '%s', jsonencode(resultStruct));
        fclose(fid);

    catch ME
        resultStruct = struct('MaxConnection', maxConn, 'Validation', valDist, 'Success', false, 'Time', 0, 'PathLength', 0, 'Error', ME.message);
        fid = fopen('experiment_result.json', 'w');
        fprintf(fid, '%s', jsonencode(resultStruct));
        fclose(fid);
        disp(['에러 발생: ', ME.message]);
    end
end
