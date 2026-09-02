# Electron Microscopy Moiré Pattern Simulation and Segmentation

This repository contains tools for simulating electron microscopy images of nanoparticles assembled into moiré patterns and training a U-Net model for layer segmentation.

## Overview

Moiré patterns arise when two periodic lattices of nanoparticles overlap at different angles. This project provides:

1. **MATLAB simulation code** - Generates realistic synthetic electron microscopy images with ground truth labels
2. **Python training code** - Trains a U-Net deep learning model to segment individual layers from the moiré pattern

## Repository Structure

├── main.m                                    # Main simulation script
├── lattice_generator_grain_boundary_size.m   # Lattice generation with grain boundaries
├── utils/                                    # Utility functions (bokeh, rod_simple, Gaussian_beam, etc.)
├── MTFmatrix512.mat                          # Modulation Transfer Function matrix
├── train/                                    # Output: simulated training images
├── label/                                    # Output: ground truth labels
├── training.ipynb                            # Model training notebook
└── README.md

## Simulation (MATLAB)

### Requirements

- MATLAB R2018b or later
- Image Processing Toolbox

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| detectorRES | Image resolution (pixels) | 512 |
| detectorScale | Physical scale (nm/pixel) | ~1.37 |
| exposureTime | Exposure time (seconds) | 0.1 |
| beamFlux | Electron flux (e-/A^2/s) | 106 |
| IMFPgold | Inelastic mean free path - gold (nm) | 35 |
| IMFPwater | Inelastic mean free path - water (nm) | 185 |
| IMFPSiNx | Inelastic mean free path - SiNx (nm) | 144 |
| thicknessWater | Water layer thickness (nm) | 250 |
| thicknessCell | SiNx membrane thickness (nm) | 50 |

### Usage

Run main() in MATLAB. This will generate:
- Simulated EM images in train/
- Ground truth labels (3-channel) in label/

### Physics Model

The simulation includes:
- Beer-Lambert transmission through multi-layer sample
- Gaussian beam profile
- Poisson shot noise
- Gaussian readout noise
- Modulation Transfer Function (MTF) blur
- Random defocus (bokeh effect)

## Training (Python)

### Requirements

tensorflow>=2.0
keras
numpy
pillow

### Usage

1. Generate training data using MATLAB simulation

2. Load data and train:

imgs, label = load_data(img_path='train/', label_path='label/')
model = get_unet()
model.fit(imgs, label, batch_size=2, epochs=20, validation_split=0.2)

3. Run predictions:

preds = model.predict(test_imgs)

### Model Architecture

U-Net with:
- Input: 512x512x1 (grayscale)
- Output: 512x512x2 (two-layer segmentation)
- Encoder: 5 levels (64->128->256->512->1024 filters)
- Decoder: 4 upsampling levels with skip connections
- Dropout: 0.5 at bottleneck
- Loss: Binary cross-entropy
- Optimizer: Adam (lr=1e-4)

## Output Format

### Simulated Images
- 512x512 grayscale TIFF
- Float values normalized to display range

### Ground Truth Labels
- 512x512x3 TIFF
- Channel 1: Layer 1 particles
- Channel 2: Layer 2 particles
- Channel 3: Background
- Binary values (0 or 1)

