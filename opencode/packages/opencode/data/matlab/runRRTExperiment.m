function runRRTExperiment(maxConn, valDist, showAnimation)
    % 파이썬에서 CLI로 넘길 때 문자열로 들어올 수 있으므로 숫자로 변환
    if ischar(maxConn), maxConn = str2double(maxConn); end
    if ischar(valDist), valDist = str2double(valDist); end
    % 애니메이션 ON/OFF 플래그 (입력이 없으면 기본값 false)
    if nargin < 3, showAnimation = false; end
    if ischar(showAnimation), showAnimation = str2double(showAnimation); end 

    try
        tic; % 연산 시간 측정 시작
        
        % 1. 시나리오 및 장애물 세팅
        scenario = robotScenario(UpdateRate=10);
        addMesh(scenario,"Box",Position=[0.35 0 0.2],Size=[0.5 0.9 0.05],Color=[0.7 0.7 0.7],Collision="mesh");
        addMesh(scenario,"Box",Position=[0 -0.6 0.2],Size=[1.3 0.4 0.235],Color=[0.7 0.7 0.7],Collision="mesh");
        addMesh(scenario,"Box",Position=[0.3 -0.25 0.4],Size=[0.8 0.03 0.35],Color=[0.7 0.7 0.7],Collision="mesh");
        
        % 2. 로봇 불러오기 (DataFormat을 'row'로 강제 고정!)
        franka = loadrobot("frankaEmikaPanda", "DataFormat", "row");
        robot = robotPlatform("Manipulator", scenario, RigidBodyTree=franka, ReferenceFrame="ENU");
        
        % [해결 1] 자기 충돌이 절대 나지 않는 안전한 초기 자세(Ready Pose) 강제 주입
        initialConfig = [0, -0.785, 0, -2.356, 0, 1.571, 0.785, 0.04, 0.04];
        setup(scenario);
        move(robot, "joint", initialConfig);
        
        % 3. AI가 넘겨준 파라미터로 RRT 플래너 세팅
        planner = manipulatorRRT(robot.RigidBodyTree, scenario.CollisionMeshes);
        planner.MaxConnectionDistance = maxConn;
        planner.ValidationDistance = valDist;
        
        % [해결 2] 데모용 치트키: 자기 자신과의 충돌(Self-collision) 체크 아예 무시!
        planner.IgnoreSelfCollision = true; 
        
        % 4. 목표 지점 설정 및 경로 계획 실행
        pickUpConfig = [0.2371 -0.0200 0.0542 -2.2272 0.0013 2.2072 -0.9670 0.0400 0.0400];
        path = plan(planner, initialConfig, pickUpConfig);
        
        % 5. 결과 메트릭 계산
        calcTime = toc;
        pathLength = size(path, 1);
        isSuccess = (pathLength > 0);
        
        % 6. 시각화 모드 실행 (showAnimation == 1 일 때)
        if showAnimation && isSuccess
            disp('시각화 모드 실행 중...');
            ax = show3D(scenario, Visuals="on", Collisions="off");
            view(81,19);
            light;
            title(sprintf('AI Optimized Path (MaxConn: %.2f, ValDist: %.2f)', maxConn, valDist));
            
            numState = 10;
            interpStates = interpolate(planner, path, numState);
            
            for idx = 1:size(interpStates, 1)
                jointConfig = interpStates(idx, :);
                move(robot, "joint", jointConfig);
                show3D(scenario, FastUpdate=true, Parent=ax, Visuals="on", Collisions="off");
                drawnow;
                advance(scenario);
            end
            disp('애니메이션 종료');
        end

        % 7. 결과를 JSON으로 저장
        resultStruct = struct('MaxConnection', maxConn, 'Validation', valDist, 'Success', isSuccess, 'Time', calcTime, 'PathLength', pathLength, 'Error', '');
        fid = fopen('experiment_result.json', 'w');
        fprintf(fid, '%s', jsonencode(resultStruct));
        fclose(fid);
        
        disp('실험 완료 및 JSON 저장 성공!');
        
    catch ME
        % 에러 처리
        resultStruct = struct('MaxConnection', maxConn, 'Validation', valDist, 'Success', false, 'Time', 0, 'PathLength', 0, 'Error', ME.message);
        fid = fopen('experiment_result.json', 'w');
        fprintf(fid, '%s', jsonencode(resultStruct));
        fclose(fid);
        disp(['에러 발생: ', ME.message]);
    end
end