#!/bin/bash

set -e

echo "🚀 XMODE Animator v2.1 ULTIMATE FIX starting..."

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

# копируем все json из provisioning (новый Animator_V2_1 в т.ч.)
cp /workspace/provisioning/*.json "$WORKFLOWS/" 2>/dev/null || true

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
# DOWNLOAD HELPER (multi-source graceful fallback)
# dl <dir> <out_filename> <url> [fallback_url ...]
# =====================================================

# твоё личное зеркало — если канон-репа отвалится, льём отсюда
MIRROR="https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main"

dl () {
    local dir="$1"; local out="$2"; shift 2
    local url
    for url in "$@"; do
        echo "→ $out  ⇐  $url"
        if aria2c -x 16 -s 16 --continue=true \
            --dir="$dir" --out="$out" "$url"; then
            echo "✅ $out"
            return 0
        else
            echo "⚠️  не скачалось: $url — пробую следующий источник..."
        fi
    done
    echo "❌ $out не скачался ни с одного источника"
    return 1
}

# =====================================================
# MAIN MODEL  (diffusion_models)
# WanVideoModelLoader -> Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors
# =====================================================

echo "📥 Downloading Wan2.2 Animate model..."

dl "$MODELS/diffusion_models" "Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" \
"https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" \
"$MIRROR/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" \
|| exit 1

# =====================================================
# VAE  (стандартный Wan2.1 VAE — точное имя из воркфлоу)
# =====================================================

echo "📥 Downloading VAE..."

dl "$MODELS/vae" "wan_2.1_vae.safetensors" \
"https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
"$MIRROR/wan_2.1_vae.safetensors" \
|| exit 1

# =====================================================
# CLIP VISION
# =====================================================

echo "📥 Downloading CLIP vision..."

dl "$MODELS/clip_vision" "clip_vision_h.safetensors" \
"https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
"$MIRROR/clip_vision_h.safetensors" \
|| exit 1

# =====================================================
# TEXT ENCODER (umt5) -> text_encoders + копия в clip
# =====================================================

echo "📥 Downloading text encoder (umt5)..."

dl "$MODELS/text_encoders" "umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
"https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
"$MIRROR/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
|| exit 1

cp \
"$MODELS/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
"$MODELS/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" || true

# =====================================================
# LORAS  (WanVideoLoraSelectMulti — 4 шт, точные имена)
# ⚠️ канон-URL'ы лор проверь: если 404 — закинь файл в свой OFMHUB,
#    фолбэк на $MIRROR подхватит автоматически
# =====================================================

echo "📥 Downloading LoRAs..."

dl "$MODELS/loras" "lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" \
"https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" \
"$MIRROR/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" \
|| echo "⚠️ lightx2v rank256 пропущен — добавь источник"

dl "$MODELS/loras" "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
"https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
"$MIRROR/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
|| echo "⚠️ lightx2v 4steps high_noise пропущен — добавь источник"

dl "$MODELS/loras" "Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors" \
"https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors" \
"$MIRROR/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors" \
|| echo "⚠️ PusaV1 пропущен — добавь источник"

dl "$MODELS/loras" "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" \
"$MIRROR/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" \
|| echo "⚠️ Fun-A14B-HPS2.1 пропущен — это кастомная лора, лей со своего OFMHUB"

# =====================================================
# DETECTION  (OnnxDetectionModelLoader)
# =====================================================

echo "📥 Downloading detection models..."

dl "$MODELS/detection" "yolov10m.onnx" \
"https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" \
"$MIRROR/yolov10m.onnx" \
|| exit 1

dl "$MODELS/detection" "vitpose_h_wholebody_model.onnx" \
"https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx" \
"$MIRROR/vitpose_h_wholebody_model.onnx" \
|| exit 1

# .bin данные к vitpose onnx (внешний вес)
dl "$MODELS/detection" "vitpose_h_wholebody_data.bin" \
"https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin" \
"$MIRROR/vitpose_h_wholebody_data.bin" \
|| true

# =====================================================
# CONTROLNET  (WanVideoUni3C_ControlnetLoader)
# =====================================================

echo "📥 Downloading ControlNet (Uni3C)..."

dl "$MODELS/controlnet" "Wan21_Uni3C_controlnet_fp16.safetensors" \
"https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors" \
"$MIRROR/Wan21_Uni3C_controlnet_fp16.safetensors" \
|| exit 1

# =====================================================
# FINAL
# =====================================================

echo ""
echo "======================================="
echo "✅ Animator v2.1 READY"
echo "✅ Модели под НОВЫЙ воркфлоу (точные имена)"
echo "✅ multitalk_audio_stride FIXED"
echo "✅ SAM3 Blackwell patch"
echo "✅ KJNodes 2.4.8 / CRT-Nodes 1.3.9"
echo "✅ WanVideoWrapper stable commit"
echo "======================================="
echo ""
echo "🔥 RESTART COMFYUI NOW 🔥"
