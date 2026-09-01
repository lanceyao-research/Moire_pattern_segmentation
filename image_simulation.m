function main()
    %% ================================================================
    %  ELECTRON MICROSCOPY SIMULATION FOR NANOPARTICLE MOIRÉ PATTERNS
    %  ================================================================
    %  This script generates synthetic electron microscopy images of 
    %  nanoparticles arranged in moiré patterns for ML training data.
    %  
    %  Output: 
    %    - Simulated EM images (train/)
    %    - Ground truth labels (label/)
    %  ================================================================
    
    % Add utility functions to path
    addpath('utils')
    clf;
    rng(12323);  % Set random seed for reproducibility
    
    %% ==================== SIMULATION PARAMETERS ====================
    
    % ----- Detector Configuration -----
    detectorRES = 512;                    % Resolution of detector (pixels)
    detectorScale = 700 / detectorRES;    % Physical scale (nm/pixel)
                                          % 700nm total field of view
    
    % ----- Load Modulation Transfer Function (MTF) -----
    % MTF accounts for detector's frequency response
    MTFmatrix = load(strcat('MTFmatrix', num2str(detectorRES), '.mat'));
    MTFmatrix = MTFmatrix.MTFmatrix;
    
    % ----- Output Paths -----
    gtPath = 'label/';    % Ground truth output directory
    simPath = 'train/';   % Simulated images output directory
    
    % ----- Beam Parameters -----
    exposureTime = 0.1;              % Exposure time (seconds)
    beamFlux = 106;                  % Electron flux (electrons/Å²/s)
    conversionFactor = 10.7;         % Detector conversion (intensity/electron)
    
    % ----- Particle Configuration -----
    PARTICLERES = 200;    % Particle canvas size (pixels) - should be larger 
                          % than actual particle size
    
    % ----- Material Properties (Inelastic Mean Free Path) -----
    % IMFP determines how far electrons travel before scattering
    IMFPgold = 35;        % Gold nanoparticles (nm) - range: 20-85 nm
    IMFPwater = 185;      % Water/buffer solution (nm)
    IMFPSiNx = 144;       % Silicon nitride membrane (nm)
    
    % ----- Sample Geometry -----
    thicknessWater = 250;    % Water layer thickness (nm)
    thicknessCell = 50;      % Silicon nitride membrane thickness (nm) 
                             % Note: *2 for top and bottom membranes
    
    % ----- Particle Height (z-dimension) -----
    h = 112.1 / detectorScale;    % Particle height converted to pixels
    
    %% ==================== DERIVED PARAMETERS ====================
    
    % Convert beam flux to electrons per pixel for the exposure
    % Original: electrons/(Å²*s) -> electrons/pixel
    beamFlux = beamFlux * 100 * (detectorScale^2) * exposureTime;
    
    %% ==================== MAIN SIMULATION LOOP ====================
    
    for dIdx = 1:3000    % Generate 3000 training images
        
        %% ----- Randomize Particle and Lattice Parameters -----
        
        % Particle diameter: random between 27-42 nm, converted to pixels
        sz = (27 + rand() * 15) / detectorScale;
        
        % Lattice constant: random between 40-55 nm, converted to pixels
        d = (40 + rand() * 15) / detectorScale;
        
        % Ensure particles don't overlap (minimum spacing = 1.2x particle size)
        d = max([d, sz * 1.2]);
        
        %% ----- Generate Particle Templates -----
        
        % Create sharp ground-truth particle (rod shape)
        particle_gt = rod_simple(PARTICLERES, sz, h);
        
        % Apply defocus blur (bokeh effect) for realistic appearance
        % Blur radius: 8-10 pixels (simulates out-of-focus effects)
        particle = bokeh(particle_gt, 8 + rand() * 2);
        
        clf;  % Clear figure for new simulation
        
        %% ----- Initialize Sample Layers -----
        
        % Water layer thickness map (will be reduced where particles exist)
        water = ones(detectorRES) * thicknessWater;
        
        % Cell membrane thickness (top + bottom = 2x)
        cell = ones(detectorRES) * 2 * thicknessCell;
        
        % Canvas for particle thickness accumulation
        % Extended size to handle particles at edges
        canvas = zeros(detectorRES + 2*PARTICLERES, detectorRES + 2*PARTICLERES);
        
        % Ground truth: 3-channel image (layer1, layer2, background)
        gt = zeros(detectorRES + 2*PARTICLERES, detectorRES + 2*PARTICLERES, 3);
        
        %% ----- Generate Lattice Positions with Grain Boundary -----
        
        % Get positions for two layers that form the moiré pattern
        [X, Y, X2, Y2] = lattice_generator_grain_boundary_size(d, detectorRES, PARTICLERES);
        
        disp(['Image ', num2str(dIdx), ' - Lattice constant: ', ...
              num2str(d * detectorScale), ' nm / Particle size: ', ...
              num2str(sz * detectorScale), ' nm'])
        
        % Store positions as coordinate arrays
        poss1 = [X, Y];    % Layer 1 particle positions
        poss2 = [X2, Y2];  % Layer 2 particle positions
        
        %% ----- Place Particles on Canvas (Layer 1) -----
        
        for i = 1:length(poss1)
            % Get integer pixel position
            pos = floor(poss1(i, :) + 0.99999);
            
            % Add particle to ground truth (channel 1)
            gt(pos(1):pos(1)+PARTICLERES-1, pos(2):pos(2)+PARTICLERES-1, 1) = ...
                gt(pos(1):pos(1)+PARTICLERES-1, pos(2):pos(2)+PARTICLERES-1, 1) + particle_gt;
            
            % Add blurred particle to simulation canvas
            canvas(pos(1):pos(1)+PARTICLERES-1, pos(2):pos(2)+PARTICLERES-1) = ...
                canvas(pos(1):pos(1)+PARTICLERES-1, pos(2):pos(2)+PARTICLERES-1) + particle;
        end
        
        %% ----- Place Particles on Canvas (Layer 2) -----
        
        for i = 1:length(poss2)
            pos = floor(poss2(i, :) + 0.99999);
            
            % Add particle to ground truth (channel 2)
            gt(pos(1):pos(1)+PARTICLERES-1, pos(2):pos(2)+PARTICLERES-1, 2) = ...
                gt(pos(1):pos(1)+PARTICLERES-1, pos(2):pos(2)+PARTICLERES-1, 2) + particle_gt;
            
            % Add blurred particle to simulation canvas
            canvas(pos(1):pos(1)+PARTICLERES-1, pos(2):pos(2)+PARTICLERES-1) = ...
                canvas(pos(1):pos(1)+PARTICLERES-1, pos(2):pos(2)+PARTICLERES-1) + particle;
        end
        
        % Convert ground truth to binary mask (invert: 1=no particle)
        gt = ~logical(gt(PARTICLERES+1:PARTICLERES+detectorRES, ...
                        PARTICLERES+1:PARTICLERES+detectorRES, :));
        
        %% ==================== TRANSMISSION CALCULATION ====================
        % Models electron transmission through the sample using Beer-Lambert law
        % I = I0 * exp(-thickness/IMFP)
        
        % Crop canvas to detector size
        sim = canvas(PARTICLERES+1:PARTICLERES+detectorRES, ...
                     PARTICLERES+1:PARTICLERES+detectorRES);
        
        % Convert particle thickness from pixels to nanometers
        sim = sim * detectorScale;
        
        % Water is displaced by particles (conservation of volume)
        water = water - sim;
        
        % Calculate transmitted intensity using Beer-Lambert law
        % Includes: Gaussian beam profile, gold particles, water, SiNx membranes
        sim0 = beamFlux * Gaussian_beam() .* ...
               exp(-(sim/IMFPgold + water/IMFPwater + cell/IMFPSiNx));
        
        % Background intensity (no particles, just water and membranes)
        bkg_ints = beamFlux * exp(-(thicknessWater/IMFPwater + 2*thicknessCell/IMFPSiNx));
        
        %% ==================== NOISE SIMULATION ====================
        
        % ----- Shot Noise (Poisson Statistics) -----
        % Fundamental quantum noise in electron counting
        sim = poissrnd(sim0);
        
        % Finalize ground truth as binary mask
        gt = gt(:, :, :) < 0.5;
        
        % ----- Readout Noise (Gaussian) -----
        % Electronic noise from detector readout
        % Standard deviation: 20-40 counts (randomized)
        sim = normrnd(sim, 20 + rand() * 20);
        
        %% ==================== MTF CORRECTION ====================
        % Apply Modulation Transfer Function to simulate detector response
        % MTF reduces high-frequency content (blurring effect)
        
        FT = fft2(sim);              % 2D Fourier Transform
        FT = fftshift(FT);           % Center zero frequency
        FT = FT .* MTFmatrix;        % Apply MTF filter
        FT = ifftshift(FT);          % Restore frequency positions
        sim = abs(ifft2(FT));        % Inverse FFT
        
        % Convert electron counts to intensity units
        sim = sim * conversionFactor;
        bkg_ints = bkg_ints * conversionFactor;
        
        %% ==================== POST-PROCESSING ====================
        
        % Resize to final output dimensions
        sim = imresize(sim, [512 512]);
        gt = imresize(gt, [512 512]);
        
        % Apply random zoom/crop augmentation
        [sim, gt] = zoom_in(sim, gt);
        
        %% ----- Contrast and Brightness Adjustment -----
        % Normalize image to realistic display range
        
        % Calculate contrast from center cross-section
        min_CW = min([sim(256, :)'; sim(:, 256)]);
        max_CW = max([sim(256, :)'; sim(:, 256)]);
        contrast = max_CW - min_CW;
        
        % Normalize contrast with random variation (1x to 2x)
        sim = sim ./ (contrast * (1 + rand() * 1));
        
        % Adjust brightness to target range (0.1 to 0.4)
        brightness = mean(sim(:));
        sim = (sim - brightness) + 0.1 + rand() * 0.3;
        
        %% ----- Display and Save -----
        
        imshow(sim);
        drawnow;
        
        % Generate filenames with index and lattice constant
        gtname = strcat(gtPath, num2str(dIdx, '%04d'), '-', num2str(d, '%.2f'), '.tif');
        simname = strcat(simPath, num2str(dIdx, '%04d'), '-', num2str(d, '%.2f'), '.tif');
        
        % Save images
        imwrite(sim, simname);
        imwrite(double(gt), gtname);
    end
end

%% ================================================================
%  ZOOM IN AUGMENTATION FUNCTION
%  ================================================================
%  Applies random zoom and crop for data augmentation
%  
%  Inputs:
%    im - Input simulated image
%    gt - Ground truth label
%  
%  Outputs:
%    sample - Zoomed/cropped simulated image
%    gt_out - Corresponding ground truth
%  ================================================================

function [sample, gt_out] = zoom_in(im, gt)
    % Zoom range: 90% to 100% of original size
    r = 0.9;
    z = r + rand() * 0.1;
    
    % Calculate cropped region size
    sample_sz = round(length(im) * z);
    
    % Random position for crop (within valid bounds)
    top_left_bound = length(im) - sample_sz + 1;
    pos = floor(rand([1, 2]) * top_left_bound) + 1;
    
    % Extract and resize simulated image
    sample = im(pos(1):pos(1)+sample_sz-1, pos(2):pos(2)+sample_sz-1);
    sample = imresize(sample, size(im));
    
    % Extract and resize ground truth (preserve all channels)
    gt_out = gt(pos(1):pos(1)+sample_sz-1, pos(2):pos(2)+sample_sz-1, :);
    gt_out = imresize(gt_out, size(im));
end