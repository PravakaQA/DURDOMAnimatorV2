#!/bin/bash
set -e

echo "🚀 Provisioning XMODE (PHOTO) FIXED VERSION started..."

apt-get update && apt-get install -y \
git wget aria2 python3-pip unzip ffmpeg

PIP="/venv/main/bin/pip"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

echo "📦 Using pip: $PIP"

# =========================================================
# CUSTOM NODES
# =========================================================

mkdir -p "$NODES"
cd "$NODES"

echo "📥 Installing pinned custom nodes..."

# =========================================================
# WAN WRAPPER (СТАРАЯ РАБОЧАЯ ВЕРСИЯ)
# =========================================================

git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
cd ComfyUI-WanVideoWrapper
git checkout 7c9f4fd
cd ..

# =========================================================
# WAN PREPROCESS
# =========================================================

git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git

# =========================================================
# KJNODES (СТАРАЯ СТАБИЛЬНАЯ)
# =========================================================

git clone https://github.com/kijai/ComfyUI-KJNodes.git comfyui-kjnodes
cd comfyui-kjnodes
git checkout 6b0f7c2
cd ..

# =========================================================
# CRT NODES (СТАРАЯ)
# =========================================================

git clone https://github.com/PGCRT/CRT-Nodes.git crt-nodes
cd crt-nodes
git checkout 4d7c8de
cd ..

# =========================================================
# OTHER NODES
# =========================================================

git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git
git clone https://github.com/cubiq/ComfyUI_essentials.git
git clone https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git

# =========================================================
# INSTALL REQUIREMENTS
# =========================================================

echo "📦 Installing requirements..."

$PIP install --upgrade pip setuptools wheel

$PIP install \
opencv-python \
opencv-python-headless \
imageio-ffmpeg \
onnxruntime-gpu \
accelerate \
safetensors \
einops

for dir in */; do
    if [ -f "$dir/requirements.txt" ]; then
        echo "→ Installing $dir requirements"
        $PIP install -r "$dir/requirements.txt" || true
    fi
done

# =========================================================
# WORKFLOWS
# =========================================================

echo "📂 Installing workflows..."

mkdir -p "$WORKFLOWS"

# Кладешь json сюда:
# provisioning/workflows/

cp /workspace/provisioning/workflows/*.json "$WORKFLOWS/" || true

# =========================================================
# MODEL DIRS
# =========================================================

mkdir -p \
"$MODELS/diffusion_models" \
"$MODELS/vae" \
"$MODELS/text_encoders" \
"$MODELS/clip_vision" \
"$MODELS/clip" \
"$MODELS/loras" \
"$MODELS/detection" \
"$MODELS/controlnet"

# =========================================================
# MODELS
# =========================================================

echo "📥 Downloading models..."

# MAIN MODEL
aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/diffusion_models" \
--out=WanModel.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanModel.safetensors"

# VAE
aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/vae" \
--out=mo_vae.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"

# CLIP VISION
aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/clip_vision" \
--out=klip_vision.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

# TEXT ENCODER
aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/text_encoders" \
--out=text_enc.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"

cp "$MODELS/text_encoders/text_enc.safetensors" \
"$MODELS/clip/text_enc.safetensors" || true

# =========================================================
# LORAS
# =========================================================

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

# =========================================================
# DETECTION
# =========================================================

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

# =========================================================
# CONTROLNET
# =========================================================

aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/controlnet" \
--out=Wan21_Uni3C_controlnet_fp16.safetensors \
"https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors" || true

# =========================================================
# FIX PERMISSIONS
# =========================================================

chmod -R 777 "$COMFY"

echo ""
echo "✅ XMODE FIXED VERSION READY!"
echo "✅ multitalk_audio_stride bug fixed"
echo "✅ KJNodes compatibility fixed"
echo "✅ CRT nodes compatibility fixed"
echo "✅ workflows auto installed"
