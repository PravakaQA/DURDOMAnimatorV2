#!/bin/bash

set -e

echo "🚀 Provisioning XMODE (PHOTO) — FIXED VERSION started..."

apt-get update && apt-get install -y \
    git \
    wget \
    aria2 \
    python3-pip \
    unzip \
    ffmpeg

PIP="/venv/main/bin/pip"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

echo "📦 Using pip: $PIP"

# ======================
# FIX GLOBAL DEPS
# ======================

echo "📦 Installing global dependencies..."

$PIP install --upgrade pip setuptools wheel

$PIP install \
    accelerate \
    transformers \
    sentencepiece \
    safetensors \
    diffusers \
    einops \
    opencv-python \
    opencv-python-headless \
    imageio \
    imageio-ffmpeg \
    av \
    huggingface_hub

# ======================
# CUSTOM NODES
# ======================

echo "📥 Installing pinned custom nodes..."

cd "$NODES"

# CLEAN OLD BROKEN NODES
rm -rf ComfyUI-WanVideoWrapper
rm -rf ComfyUI-KJNodes
rm -rf CRT-Nodes

# ======================
# WAN VIDEO WRAPPER
# ======================

git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

cd ComfyUI-WanVideoWrapper

# ❌ УБРАН ЕБАНЫЙ BROKEN CHECKOUT
# git checkout 7c9f4fd

if [ -f requirements.txt ]; then
    $PIP install -r requirements.txt || true
fi

cd ..

# ======================
# OTHER NODES
# ======================

git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git || true

# ======================
# KJ NODES FIXED VERSION
# ======================

git clone https://github.com/kijai/ComfyUI-KJNodes.git

cd ComfyUI-KJNodes
git checkout v1.3.8 || true
cd ..

# ======================
# CRT NODES FIXED VERSION
# ======================

git clone https://github.com/PGCRT/CRT-Nodes.git

cd CRT-Nodes
git checkout v2.3.8 || true
cd ..

git clone https://github.com/rgthree/rgthree-comfy.git || true
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git || true
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git || true
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git || true
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git || true
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git || true
git clone https://github.com/cubiq/ComfyUI_essentials.git || true
git clone https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git || true

# ======================
# INSTALL ALL REQUIREMENTS
# ======================

echo "📦 Installing node requirements..."

for dir in */; do
    if [ -f "$dir/requirements.txt" ]; then
        echo "→ Installing requirements for $dir"
        $PIP install -r "$dir/requirements.txt" || true
    fi
done

# ======================
# FIX WAN AUDIO MULTI
# ======================

echo "🔧 Fixing Wan Audio Multi dependencies..."

$PIP install \
    accelerate \
    librosa \
    soundfile \
    scipy \
    numpy \
    einops \
    transformers \
    sentencepiece || true

# ======================
# WORKFLOWS
# ======================

echo "📂 Copying workflows..."

mkdir -p "$WORKFLOWS"

cp /workspace/provisioning/animator_v2_1_0.json \
   "$WORKFLOWS/animator_v2_1_0.json" \
   2>/dev/null || echo "⚠️ animator_v2_1_0.json not found"

cp /workspace/provisioning/animator_v2_1_0_mask_mode.json \
   "$WORKFLOWS/animator_v2_1_0_mask_mode.json" \
   2>/dev/null || echo "⚠️ animator_v2_1_0_mask_mode.json not found"

# ======================
# MODEL DIRS
# ======================

echo "📁 Creating model directories..."

mkdir -p \
    "$MODELS/diffusion_models" \
    "$MODELS/vae" \
    "$MODELS/text_encoders" \
    "$MODELS/clip_vision" \
    "$MODELS/clip" \
    "$MODELS/loras" \
    "$MODELS/detection" \
    "$MODELS/controlnet"

cd "$MODELS"

# ======================
# CORE MODELS
# ======================

echo "📥 MAIN MODEL"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/diffusion_models" \
    --out=WanModel.safetensors \
    "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanModel.safetensors"

echo "📥 VAE"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/vae" \
    --out=mo_vae.safetensors \
    "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"

echo "📥 CLIP VISION"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/clip_vision" \
    --out=klip_vision.safetensors \
    "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

echo "📥 TEXT ENCODER"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/text_encoders" \
    --out=text_enc.safetensors \
    "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"

cp "$MODELS/text_encoders/text_enc.safetensors" \
   "$MODELS/clip/text_enc.safetensors" \
   2>/dev/null || true

# ======================
# LORAS
# ======================

echo "📥 LoRAs"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/loras" \
    --out=light.safetensors \
    "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/light.safetensors"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/loras" \
    --out=wan_reworked.safetensors \
    "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/wan.reworked.safetensors"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/loras" \
    --out=WanPusa.safetensors \
    "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanPusa.safetensors"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/loras" \
    --out=WanFun.reworked.safetensors \
    "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanFun.reworked.safetensors"

# ======================
# DETECTION
# ======================

echo "📥 Detection models"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/detection" \
    --out=yolov10m.onnx \
    "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/detection" \
    --out=vitpose_h_wholebody_model.onnx \
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/detection" \
    --out=vitpose_h_wholebody_data.bin \
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"

# ======================
# CONTROLNET
# ======================

echo "📥 ControlNet"

aria2c -x 16 -s 16 --continue=true \
    --dir="$MODELS/controlnet" \
    --out=Wan21_Uni3C_controlnet_fp16.safetensors \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors" || true

# ======================
# CLEAN CACHE
# ======================

echo "🧹 Cleaning cache..."

find "$COMFY" -type d -name "__pycache__" -exec rm -rf {} + || true

# ======================
# DONE
# ======================

echo ""
echo "✅ XMODE (PHOTO) FULLY READY!"
echo "✅ Wan Audio Multi fixed"
echo "✅ accelerate installed"
echo "✅ KJNodes pinned to v1.3.8"
echo "✅ CRT-Nodes pinned to v2.3.8"
echo "✅ Broken git checkout removed"
echo "✅ mo_vae fixed"
echo ""
echo "🔄 Restart ComfyUI now"
