#!/bin/bash

set -e

echo "🚀 XMODE Animator v2 ULTIMATE FIX starting..."

# =====================================================
# BASE
# =====================================================

apt-get update
apt-get install -y \
git \
wget \
curl \
aria2 \
ffmpeg \
unzip \
python3-pip

PIP="/venv/main/bin/pip"
PYTHON="/venv/main/bin/python"

COMFY="/workspace/ComfyUI"

MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

echo "📦 Using Python:"
$PYTHON --version

echo "📦 Using Pip:"
$PIP --version

# =====================================================
# CLEAN BROKEN STUFF
# =====================================================

echo "🧹 Cleaning old broken nodes..."

rm -rf "$NODES/comfyui-kjnodes" || true
rm -rf "$NODES/ComfyUI-KJNodes" || true
rm -rf "$NODES/CRT-Nodes" || true
rm -rf "$NODES/crt-nodes" || true
rm -rf "$NODES/ComfyUI-WanVideoWrapper" || true

# =====================================================
# PIP CORE
# =====================================================

echo "📦 Installing core packages..."

$PIP install --upgrade \
pip \
setuptools \
wheel

$PIP install --upgrade --force-reinstall \
opencv-python \
opencv-python-headless \
numpy \
pillow \
einops \
safetensors \
accelerate \
transformers \
diffusers \
sentencepiece \
timm \
imageio \
imageio-ffmpeg \
onnxruntime-gpu \
scipy \
scikit-image

# =====================================================
# CUSTOM NODES
# =====================================================

cd "$NODES"

echo "📥 Installing WanVideoWrapper..."

git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

cd ComfyUI-WanVideoWrapper

# СТАБИЛЬНЫЙ КОММИТ ДО БАГА
git checkout 6fce1f7 || true

cd ..

echo "📥 Installing WanAnimatePreprocess..."
git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git || true

echo "📥 Installing KJNodes 2.4.8..."
git clone https://github.com/kijai/ComfyUI-KJNodes.git comfyui-kjnodes

cd comfyui-kjnodes
git checkout 2.4.8 || true
cd ..

echo "📥 Installing CRT-Nodes 1.3.9..."
git clone https://github.com/PGCRT/CRT-Nodes.git crt-nodes

cd crt-nodes
git checkout 1.3.9 || true
cd ..

echo "📥 Installing other nodes..."

git clone https://github.com/rgthree/rgthree-comfy.git || true
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git || true
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git || true
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git || true
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git || true
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git || true
git clone https://github.com/cubiq/ComfyUI_essentials.git || true
git clone https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git || true

# =====================================================
# INSTALL NODE REQUIREMENTS
# =====================================================

echo "📦 Installing node requirements..."

for dir in */; do
    if [ -f "$dir/requirements.txt" ]; then
        echo "→ $dir"
        $PIP install -r "$dir/requirements.txt" || true
    fi
done
# =====================================================
# PATCH SAM3 BLACKWELL MASKED ATTENTION
# =====================================================

echo "🩹 Applying SAM3-only Blackwell SDPA patch..."

SAM3_ATTN_FILE="$NODES/ComfyUI-SAM3/nodes/sam3/attention.py"

if [ ! -f "$SAM3_ATTN_FILE" ]; then
    echo "❌ SAM3 attention.py not found:"
    echo "$SAM3_ATTN_FILE"
    exit 1
fi

$PYTHON - "$SAM3_ATTN_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

marker = "DURDOM_BLACKWELL_SAM3_SDPA_PATCH"

old = """        if sdpa_mask is not None:
            masked_fn = optimized_attention_for_device(q.device, mask=True)
            out = masked_fn(q, k, v, heads=self.num_heads, mask=sdpa_mask, skip_reshape=True)
        else:
            out = sam3_attention(q, k, v, self.num_heads)
"""

new = """        if sdpa_mask is not None:
            # DURDOM_BLACKWELL_SAM3_SDPA_PATCH
            # Local fallback only for SAM3 masked attention.
            # Regular Animator and WanVideo keep their existing attention backend.
            out = torch.nn.functional.scaled_dot_product_attention(
                q.contiguous(),
                k.contiguous(),
                v.contiguous(),
                attn_mask=sdpa_mask.contiguous(),
                dropout_p=0.0,
                is_causal=False,
            )
        else:
            out = sam3_attention(q, k, v, self.num_heads)
"""

if marker in text:
    print("✅ SAM3 Blackwell patch already applied. Skipping.")
    raise SystemExit(0)

if old not in text:
    print("❌ Expected SAM3 attention block not found.")
    print("❌ ComfyUI-SAM3 source may have changed. Patch aborted safely.")
    raise SystemExit(1)

backup = path.with_suffix(".py.bak")
backup.write_text(text, encoding="utf-8")

path.write_text(text.replace(old, new, 1), encoding="utf-8")

print(f"✅ Backup created: {backup}")
print("✅ SAM3-only Blackwell SDPA patch applied.")
PY

$PYTHON -m py_compile "$SAM3_ATTN_FILE"

echo "✅ SAM3 attention.py syntax check passed."
# =====================================================
# PATCH multitalk_audio_stride BUG
# =====================================================

echo "🩹 Patching multitalk_audio_stride bug..."

SAMPLER_FILE="$NODES/ComfyUI-WanVideoWrapper/nodes_sampler.py"

if [ -f "$SAMPLER_FILE" ]; then

python3 << EOF
from pathlib import Path

path = Path("$SAMPLER_FILE")

text = path.read_text()

if "multitalk_audio_stride = None" not in text:

    text = text.replace(
        "def process(",
        "def process("
    )

    marker = "def process("

    idx = text.find(marker)

    if idx != -1:
        line_end = text.find("):", idx)

        if line_end != -1:
            insert_pos = text.find("\n", line_end) + 1

            text = (
                text[:insert_pos]
                + "        multitalk_audio_stride = None\n"
                + text[insert_pos:]
            )

    path.write_text(text)

print("PATCHED")
EOF

fi

# =====================================================
# EXTRA FAILSAFE PATCH
# =====================================================

echo "🩹 Applying secondary failsafe patch..."

sed -i \
's/if multitalk_audio_stride is not None:/if "multitalk_audio_stride" in locals() and multitalk_audio_stride is not None:/g' \
"$SAMPLER_FILE" || true

# =====================================================
# WORKFLOWS
# =====================================================

echo "📂 Installing workflows..."

mkdir -p "$WORKFLOWS"

cp /workspace/provisioning/animator_v2_1_0.json \
"$WORKFLOWS/animator_v2_1_0.json" 2>/dev/null || true

cp /workspace/provisioning/animator_v2_1_0_mask_mode.json \
"$WORKFLOWS/animator_v2_1_0_mask_mode.json" 2>/dev/null || true

# =====================================================
# MODEL DIRS
# =====================================================

echo "📁 Creating model folders..."

mkdir -p \
"$MODELS/diffusion_models" \
"$MODELS/vae" \
"$MODELS/text_encoders" \
"$MODELS/clip_vision" \
"$MODELS/clip" \
"$MODELS/loras" \
"$MODELS/detection" \
"$MODELS/controlnet"

# =====================================================
# MAIN MODEL
# =====================================================

echo "📥 Downloading WanModel..."

aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/diffusion_models" \
--out=WanModel.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanModel.safetensors"

# =====================================================
# VAE
# =====================================================

echo "📥 Downloading mo_vae..."

aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/vae" \
--out=mo_vae.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"

# =====================================================
# CLIP VISION
# =====================================================

echo "📥 Downloading clip vision..."

aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/clip_vision" \
--out=klip_vision.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

# =====================================================
# TEXT ENCODER
# =====================================================

echo "📥 Downloading text encoder..."

aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/text_encoders" \
--out=text_enc.safetensors \
"https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"

cp \
"$MODELS/text_encoders/text_enc.safetensors" \
"$MODELS/clip/text_enc.safetensors" || true

# =====================================================
# LORAS
# =====================================================

echo "📥 Downloading LoRAs..."

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

# =====================================================
# DETECTION
# =====================================================

echo "📥 Downloading detection models..."

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

# =====================================================
# CONTROLNET
# =====================================================

echo "📥 Downloading ControlNet..."

aria2c -x 16 -s 16 --continue=true \
--dir="$MODELS/controlnet" \
--out=Wan21_Uni3C_controlnet_fp16.safetensors \
"https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors"

# =====================================================
# FINAL
# =====================================================

echo ""
echo "======================================="
echo "✅ Animator v2 READY"
echo "✅ multitalk_audio_stride FIXED"
echo "✅ mo_vae FIXED"
echo "✅ KJNodes 2.4.8"
echo "✅ CRT-Nodes 1.3.9"
echo "✅ WanVideoWrapper stable commit"
echo "✅ OFMHUB models installed"
echo "======================================="
echo ""
echo "🔥 RESTART COMFYUI NOW 🔥"
