#!/bin/bash
set -e

echo "🚀 XMODE WAN AUTO INSTALL FIXED"

apt-get update && apt-get install -y \
git wget curl aria2 unzip ffmpeg jq

PIP="/venv/main/bin/pip"
COMFY="/workspace/ComfyUI"
NODES="$COMFY/custom_nodes"
MODELS="$COMFY/models"
WORKFLOWS="$COMFY/user/default/workflows"

# =========================================================
# PYTHON
# =========================================================

echo "📦 Python deps"

$PIP install --upgrade pip setuptools wheel

$PIP install \
opencv-python \
opencv-python-headless \
imageio-ffmpeg \
onnxruntime-gpu \
accelerate \
diffusers \
transformers \
sentencepiece \
safetensors \
einops \
omegaconf

# =========================================================
# CUSTOM NODES
# =========================================================

mkdir -p "$NODES"
cd "$NODES"

echo "📥 Installing custom nodes"

# =========================================================
# WAN VIDEO WRAPPER (STABLE)
# =========================================================

git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

cd ComfyUI-WanVideoWrapper
git checkout 7c9127b
cd ..

# =========================================================
# WAN PREPROCESS
# =========================================================

git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git

# =========================================================
# KJNODES FIXED VERSION
# =========================================================

git clone https://github.com/kijai/ComfyUI-KJNodes.git

cd ComfyUI-KJNodes
git checkout 1.3.8
cd ..

# =========================================================
# VIDEO HELPER SUITE FIXED VERSION
# =========================================================

git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

cd ComfyUI-VideoHelperSuite
git checkout 2.4.8
cd ..

# =========================================================
# OTHER NODES
# =========================================================

git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git
git clone https://github.com/cubiq/ComfyUI_essentials.git
git clone https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git
git clone https://github.com/PGCRT/CRT-Nodes.git

# =========================================================
# INSTALL REQUIREMENTS
# =========================================================

echo "📦 Installing requirements"

for dir in */ ; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "Installing $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

# =========================================================
# PATCH WAN BUG
# =========================================================

echo "🩹 Patching WanVideoWrapper bug"

FILE="$NODES/ComfyUI-WanVideoWrapper/nodes_sampler.py"

if ! grep -q "multitalk_audio_stride = None" "$FILE"; then

sed -i '/if multitalk_audio_stride is not None:/i\
        multitalk_audio_stride = None
' "$FILE"

fi

# =========================================================
# DISABLE NODES 2.0
# =========================================================

echo "🩹 Disabling Nodes 2.0"

mkdir -p "$COMFY/user/default"

cat > "$COMFY/user/default/comfy.settings.json" <<EOF
{
  "Comfy.NodeLibrary.Enabled": false,
  "Comfy.UseNewMenu": false,
  "Comfy.Nodes.2.0": false
}
EOF

# =========================================================
# WORKFLOWS
# =========================================================

echo "📂 Installing workflows"

mkdir -p "$WORKFLOWS"

# СЮДА ПОДСТАВИШЬ СВОЙ GITHUB RAW
curl -L \
"https://raw.githubusercontent.com/USERNAME/REPO/main/animator_v2_1_0.json" \
-o "$WORKFLOWS/animator_v2_1_0.json"

curl -L \
"https://raw.githubusercontent.com/USERNAME/REPO/main/animator_v2_1_0_mask_mode.json" \
-o "$WORKFLOWS/animator_v2_1_0_mask_mode.json"

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

echo "📥 Downloading models"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/diffusion_models" \
-o WanModel.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanModel.safetensors"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/vae" \
-o mo_vae.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/clip_vision" \
-o klip_vision.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/text_encoders" \
-o text_enc.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"

cp "$MODELS/text_encoders/text_enc.safetensors" \
"$MODELS/clip/text_enc.safetensors" || true

# =========================================================
# LORAS
# =========================================================

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/loras" \
-o light.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/light.safetensors"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/loras" \
-o wan_reworked.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/wan.reworked.safetensors"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/loras" \
-o WanPusa.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanPusa.safetensors"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/loras" \
-o WanFun.reworked.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanFun.reworked.safetensors"

# =========================================================
# DETECTION
# =========================================================

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/detection" \
-o yolov10m.onnx \
"https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/detection" \
-o vitpose_h_wholebody_model.onnx \
"https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/detection" \
-o vitpose_h_wholebody_data.bin \
"https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"

# =========================================================
# CONTROLNET
# =========================================================

aria2c -x 16 -s 16 --continue=true \
-d "$MODELS/controlnet" \
-o Wan21_Uni3C_controlnet_fp16.safetensors \
"https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors"

echo ""
echo "✅ INSTALL COMPLETE"
echo "🔥 WAN FIXED"
echo "🔥 WORKFLOWS INSTALLED"
echo "🔥 VERSION CONFLICTS FIXED"
