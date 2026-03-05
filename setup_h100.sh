#!/bin/bash
# Relightable 3D Gaussian - Environment setup for H100 (Ubuntu)
# Uses PyTorch 2.x + CUDA 12, no CUDA 11.x requirement.

set -e

echo "============================================"
echo " Relightable 3D Gaussian - H100 / Ubuntu"
echo "============================================"

if ! command -v nvidia-smi &> /dev/null; then
    echo "[ERROR] nvidia-smi not found. Need NVIDIA GPU + driver."
    exit 1
fi
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader

if ! command -v conda &> /dev/null; then
    echo "[ERROR] conda not found. Install Miniconda/Anaconda first."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# --- 1. Create conda env (Python 3.10 for PyTorch 2.x) ---
echo ""
echo ">>> Step 1: Creating conda environment (Python 3.10) ..."
conda create -n r3dg python=3.10 -y 2>/dev/null || true
eval "$(conda shell.bash hook)"
conda activate r3dg

# --- 2. Base dependencies (from environment.yml, relaxed versions) ---
echo ""
echo ">>> Step 2: Installing base dependencies ..."
conda install -y matplotlib numpy tensorboard tqdm pip cmake
pip install dearpygui imageio opencv-python pillow plyfile scipy

# --- 3. PyTorch 2.x with CUDA 12 (H100-compatible) ---
echo ""
echo ">>> Step 3: Installing PyTorch 2.x + CUDA 12 ..."
conda install -y pytorch torchvision torchaudio pytorch-cuda=12.4 -c pytorch -c nvidia

# DEBUG: Check which torch is being picked up
python -c "
import torch
import sys
import os
import json
import time

log_entry = {
    'sessionId': 'dcaa02',
    'timestamp': int(time.time() * 1000),
    'location': 'setup_h100.sh',
    'message': 'Checking torch installation',
    'data': {
        'torch_version': torch.__version__,
        'torch_path': torch.__file__,
        'cuda_available': torch.cuda.is_available(),
        'cuda_version': torch.version.cuda,
        'sys_path': sys.path,
        'hypothesisId': 'A'
    }
}
print(f'DEBUG_LOG: {json.dumps(log_entry)}')
with open('debug_dcaa02.log', 'a') as f:
    f.write(json.dumps(log_entry) + '\n')
"

python -c "import torch; print(f'PyTorch {torch.__version__}, CUDA: {torch.cuda.is_available()}')"

# --- 4. torch_scatter (PyTorch 2.x compatible) ---
echo ""
echo ">>> Step 4: Installing torch_scatter ..."
pip install torch_scatter --no-build-isolation

# --- 5. kornia ---
echo ""
echo ">>> Step 5: Installing kornia ..."
pip install kornia

# --- 6. nvdiffrast ---
echo ""
echo ">>> Step 6: Installing nvdiffrast ..."
if [ ! -d "$PROJECT_DIR/nvdiffrast" ]; then
    git clone https://github.com/NVlabs/nvdiffrast "$PROJECT_DIR/nvdiffrast"
fi
pip install "$PROJECT_DIR/nvdiffrast" --no-build-isolation

# --- 7. Custom CUDA extensions ---
echo ""
echo ">>> Step 7: Installing custom extensions (simple-knn, bvh, r3dg-rasterization) ..."
pip install "$PROJECT_DIR/submodules/simple-knn" --no-build-isolation 2>/dev/null || true
pip install "$PROJECT_DIR/bvh" --no-build-isolation 2>/dev/null || true
pip install "$PROJECT_DIR/r3dg-rasterization" --no-build-isolation 2>/dev/null || true

# --- 8. Verify ---
echo ""
echo ">>> Step 8: Verifying ..."
python -c "
import torch
print('torch:', torch.__version__, '| CUDA:', torch.cuda.is_available())
try:
    import torch_scatter; print('torch_scatter: OK')
except Exception as e: print('torch_scatter:', e)
try:
    import kornia; print('kornia:', kornia.__version__)
except Exception as e: print('kornia:', e)
try:
    import nvdiffrast; print('nvdiffrast: OK')
except Exception as e: print('nvdiffrast:', e)
try:
    import bvh_tracing; print('bvh_tracing: OK')
except Exception as e: print('bvh_tracing:', e)
print('Done.')
"

echo ""
echo "============================================"
echo " Activate: conda activate r3dg"
echo "============================================"
