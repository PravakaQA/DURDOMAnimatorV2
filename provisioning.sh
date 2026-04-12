#!/bin/bash
set -e
echo "🚀 Provisioning XMODE (PHOTO) — ФИНАЛЬНАЯ ВЕРСИЯ (OFMHUB + mo_vae fix) started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip
PIP="/venv/main/bin/pip"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

echo "📦 Using pip: $PIP"

# ====================== CUSTOM NODES ======================
echo "📥 Cloning custom nodes..."
cd "$NODES"
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git || true
git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git || true
git clone https://github.com/kijai/ComfyUI-KJNodes.git || true
git clone https://github.com/rgthree/rgthree-comfy.git || true
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git || true
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git || true
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git || true
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git || true
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git || true
git clone https://github.com/cubiq/ComfyUI_essentials.git || true
git clone https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git || true
git clone https://github.com/PGCRT/CRT-Nodes.git || true

echo "📦 Installing node requirements..."
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Installing requirements for $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

# ====================== WORKFLOWS ======================
echo "📂 Copying workflows..."
mkdir -p "$WORKFLOWS"
cp /workspace/provisioning/animator_v2_1_0.json "$WORKFLOWS/animator_v2_1_0.json" 2>/dev/null || echo "⚠️ animator_v2_1_0.json not found"
cp /workspace/provisioning/animator_v2_1_0_mask_mode.json "$WORKFLOWS/animator_v2_1_0_mask_mode.json" 2>/dev/null || echo "⚠️ animator_v2_1_0_mask_mode.json not found"

# ====================== MODEL DIRS ======================
echo "📁 Creating model directories..."
mkdir -p "$MODELS/diffusion_models" "$MODELS/vae" "$MODELS/text_encoders" "$MODELS/clip_vision" "$MODELS/clip" "$MODELS/loras" "$MODELS/detection" "$MODELS/controlnet"

cd "$MODELS"

# ====================== CORE MODELS (OFMHUB) ======================
echo "📥 1. MAIN MODEL → WanModel.safetensors"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/diffusion_models" --out=WanModel.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanModel.safetensors"

echo "📥 2. VAE → mo_vae.safetensors (ВАЖНЫЙ ФИКС!)"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/vae" --out=mo_vae.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"

echo "📥 3. CLIP Vision → klip_vision.safetensors"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/clip_vision" --out=klip_vision.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

echo "📥 4. Text Encoder → text_enc.safetensors"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/text_encoders" --out=text_enc.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"
cp "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/clip/text_enc.safetensors" 2>/dev/null || true

# ====================== LORAS ======================
echo "📥 5-8. LoRA (light, wan_reworked, WanPusa, WanFun.reworked)"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/loras" --out=light.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/light.safetensors"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/loras" --out=wan_reworked.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/wan.reworked.safetensors"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/loras" --out=WanPusa.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanPusa.safetensors"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/loras" --out=WanFun.reworked.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanFun.reworked.safetensors"

# ====================== DETECTION ======================
echo "📥 9-11. Detection (yolov10m + vitpose)"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/detection" --out=yolov10m.onnx \
  "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/detection" --out=vitpose_h_wholebody_model.onnx \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/detection" --out=vitpose_h_wholebody_data.bin \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"

# ====================== CONTROLNET ======================
echo "📥 12. ControlNet"
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/controlnet" --out=Wan21_Uni3C_controlnet_fp16.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors" || true

echo ""
echo "✅ XMODE (PHOTO) ПОЛНОСТЬЮ ГОТОВ!"
echo "mo_vae.safetensors теперь скачан и переименован правильно"
echo "После перезапуска ComfyUI зайди в Manager → Check Missing"
echo "Должно быть 0 missing 🔥"
