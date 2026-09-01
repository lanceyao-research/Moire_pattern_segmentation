function [X, Y, X2, Y2] = lattice_generator_grain_boundary_size(d, detectorRES, PARTICLERES)
    %% ================================================================
    %  MOIRÉ LATTICE GENERATOR WITH GRAIN BOUNDARY
    %  ================================================================
    %  Generates hexagonal lattice positions for two layers with:
    %    - Different rotation angles (creates moiré pattern)
    %    - Grain boundary in layer 1 (two grains with different orientations)
    %    - Random irregular boundaries for realistic appearance
    %  
    %  Inputs:
    %    d           - Lattice constant (pixels)
    %    detectorRES - Detector resolution (pixels)
    %    PARTICLERES - Particle canvas size (pixels)
    %  
    %  Outputs:
    %    X, Y   - Layer 1 particle positions (combined grains A & B)
    %    X2, Y2 - Layer 2 particle positions
    %  ================================================================
    
    % Total canvas size
    RES = detectorRES + PARTICLERES;
    
    %% ==================== ROTATION ANGLES ====================
    % Different angles create the moiré interference pattern
    
    A1_A = 44 + rand() * 30;    % Layer 1, Grain A: 44-74 degrees
    A1_B = 24 + rand() * 20;    % Layer 1, Grain B: 24-44 degrees
    A2 = 24 + rand() * 20;      % Layer 2: 24-44 degrees
    
    %% ==================== BASE HEXAGONAL LATTICE ====================
    % Create a hexagonal close-packed lattice structure
    
    % Generate 1D lattice points (oversized for rotation)
    points_y = (0:d:4*RES) - 2*RES;
    
    % Create 2D grid
    [X, Y] = meshgrid(points_y, points_y);
    
    % Convert to hexagonal: compress Y by sqrt(3)/2
    Y = Y .* sqrt(3) / 2;
    
    % Offset every other row by half lattice constant (hexagonal symmetry)
    X(1:2:end, :) = X(1:2:end, :) + 0.5 * d;
    
    % Center the lattice at origin
    mid = floor(size(Y, 1) / 2);
    mid = [X(mid, mid), Y(mid, mid)];
    Y = Y - mid(2);
    X = X - mid(1);
    
    % Flatten to 1D arrays
    Y = Y(:);
    X = X(:);
    
    % Create second layer offset by d/2 in Y direction
    X2 = X;
    Y2 = Y + d/2;
    
    %% ==================== INITIALIZE LAYER BLOCKS ====================
    
    L1_A = [X, Y];     % Layer 1, Grain A
    L1_B = L1_A;       % Layer 1, Grain B (same positions, different rotation)
    L2 = [X2, Y2];     % Layer 2
    
    %% ==================== APPLY ROTATIONS ====================
    % Rotation creates the moiré pattern when layers overlap
    
    % Rotate Layer 1, Grain A
    R = [cosd(A1_A) -sind(A1_A);
         sind(A1_A)  cosd(A1_A)];
    L1_A = L1_A * R;
    
    % Rotate Layer 1, Grain B
    R = [cosd(A1_B) -sind(A1_B);
         sind(A1_B)  cosd(A1_B)];
    L1_B = L1_B * R;
    
    % Rotate Layer 2
    R = [cosd(A2) -sind(A2);
         sind(A2)  cosd(A2)];
    L2 = L2 * R;
    
    %% ==================== GRAIN BOUNDARY GENERATION ====================
    % Creates a curved boundary separating the two grains in Layer 1
    
    % Generate semicircle points for boundary shape
    th = 0:pi/50:pi;
    
    % Randomly decide whether to include grain boundary (90% chance)
    if_GB = rand() > 0.1;
    
    % Create boundary shape:
    %   - With GB: semicircle with radius 5000 pixels
    %   - Without GB: push boundary far away (50000 pixels offset)
    semicircle = [(5000 * if_GB * cos(th))' + 50000 * (~if_GB), ...
                  (5000 * if_GB * sin(th))'];
    
    % Random rotation of grain boundary orientation
    A_GB = rand() * 360;
    R = [cosd(A_GB) -sind(A_GB);
         sind(A_GB)  cosd(A_GB)];
    semicircle = semicircle * R;
    
    %% ==================== SPLIT LATTICES BY GRAIN BOUNDARY ====================
    % Assign particles to Grain A or Grain B based on position
    
    % Grain A: particles inside the semicircle
    M1A = inpolygon(L1_A(:,1), L1_A(:,2), semicircle(:,1), semicircle(:,2));
    L1_A = L1_A(M1A, :);
    
    % Grain B: particles outside the semicircle
    M1B = ~inpolygon(L1_B(:,1), L1_B(:,2), semicircle(:,1), semicircle(:,2));
    L1_B = L1_B(M1B, :);
    
    %% ==================== COMBINE CHANNELS ====================
    
    % Channel 1: Combined Layer 1 (Grain A + Grain B)
    C1 = [L1_A; L1_B];
    
    % Channel 2: Layer 2
    C2 = L2;
    
    % Extract coordinates
    X = C1(:, 1);
    Y = C1(:, 2);
    X2 = C2(:, 1);
    Y2 = C2(:, 2);
    
    %% ==================== RANDOM TRANSLATION (DISABLED) ====================
    % Optional: add random offset to entire lattice
    
    rand1 = rand() * 0;    % Currently disabled (multiplied by 0)
    rand2 = rand() * 0;
    
    X = X + RES * rand1;
    X2 = X2 + RES * rand1;
    Y = Y + RES * rand2;
    Y2 = Y2 + RES * rand2;
    
    %% ==================== CENTER LATTICE ON IMAGE ====================
    
    X = X + detectorRES/2 + PARTICLERES/2;
    Y = Y + detectorRES/2 + PARTICLERES/2;
    X2 = X2 + detectorRES/2 + PARTICLERES/2;
    Y2 = Y2 + detectorRES/2 + PARTICLERES/2;
    
    %% ==================== FILTER TO IMAGE BOUNDS ====================
    % Remove particles outside the valid image region
    
    % Define image boundary as polygon
    boundary_rect = [1 1 RES RES]';
    boundary_rect_y = [1 RES RES 1]';
    
    % Filter Layer 1
    filter0 = inpolygon(X, Y, boundary_rect, boundary_rect_y);
    X = X(filter0);
    Y = Y(filter0);
    
    % Filter Layer 2
    filter0 = inpolygon(X2, Y2, boundary_rect, boundary_rect_y);
    X2 = X2(filter0);
    Y2 = Y2(filter0);
    
    %% ==================== IRREGULAR BOUNDARY (LAYER 1) ====================
    % Create random convex hull boundary for Layer 1 particles
    % Simulates finite assembly/domain size
    
    % Generate random points for convex hull
    rd_points = normrnd(RES/2, RES*0.3, [20, 2]);
    K = convhull(rd_points);
    boundary = rd_points(K, :);
    
    % Apply boundary filter to Layer 1
    filter1_1 = inpolygon(X, Y, boundary(:,1), boundary(:,2));
    X = X(filter1_1);
    Y = Y(filter1_1);
    
    % Apply same boundary to Layer 2 (first filter)
    filter1_2 = inpolygon(X2, Y2, boundary(:,1), boundary(:,2));
    X2 = X2(filter1_2);
    Y2 = Y2(filter1_2);
    
    %% ==================== IRREGULAR BOUNDARY (LAYER 2) ====================
    % Create additional smaller boundary for Layer 2 only
    % Results in Layer 2 being smaller than Layer 1
    
    rd_points = normrnd(RES/2, RES*0.2, [20, 2]);  % Smaller variance
    K = convhull(rd_points);
    boundary = rd_points(K, :);
    
    % Apply second boundary filter to Layer 2 only
    filter2 = inpolygon(X2, Y2, boundary(:,1), boundary(:,2));
    X2 = X2(filter2);
    Y2 = Y2(filter2);
    
    %% ==================== DEBUG VISUALIZATION (COMMENTED) ====================
    % Uncomment to visualize lattice positions
    %
    %   scatter(X, Y); hold on
    %   scatter(X2, Y2)
    %   xlim([0 512])
    %   ylim([0 512])
    %   plot(boundary(:,1), boundary(:,2))
    
end