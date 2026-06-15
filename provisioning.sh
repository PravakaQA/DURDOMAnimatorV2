#!/bin/bash
# =====================================================================
# Animator V2.1 — provisioning (на базе рабочего шаблона animka.sh)
# Воспроизводит шаблон 1-в-1: ComfyUI 0.10.0 + те же ноды (по коммитам)
# + реальные URL моделей. Чистые имена под воркфлоу, без лишних патчей.
# Запускать на свежем поде / Jupyter. Идемпотентно (пропускает что есть).
# =====================================================================
set -e
source /venv/main/bin/activate 2>/dev/null || true

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY="${WORKSPACE}/ComfyUI"
PIP="pip"

# опционально: export HF_TOKEN=... перед запуском, если упрётся в гейты HF
HF_TOKEN="${HF_TOKEN:-}"

# ---- закреплённые версии из рабочего шаблона ----
COMFY_COMMIT="9d273d3a"   # ComfyUI 0.10.0

# repo|commit (точные коммиты из дампа шаблона)
NODES=(
  "https://github.com/kijai/ComfyUI-WanVideoWrapper|088128b"
  "https://github.com/kijai/ComfyUI-KJNodes|3e80b28"
  "https://github.com/kijai/ComfyUI-WanAnimatePreprocess|0e0b6a2"
  "https://github.com/kijai/ComfyUI-segment-anything-2|0c35fff"
  "https://github.com/PozzettiAndrea/ComfyUI-SAM3.git|de0ff5d"
  "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite|4ee72c0"
  "https://github.com/cubiq/ComfyUI_essentials|9d9f4be"
  "https://github.com/rgthree/rgthree-comfy|738105a"
  "https://github.com/yolain/ComfyUI-Easy-Use|625efbf"
  "https://github.com/chflame163/ComfyUI_LayerStyle|d94bef1"
  "https://github.com/fq393/ComfyUI-ZMG-Nodes|51510c6"
  "https://github.com/jnxmx/ComfyUI_HuggingFace_Downloader|fe86409"
  "https://github.com/teskor-hub/comfyui-teskors-utils.git|9ae6df6"
)

# ---- модели: папка | имя_файла | url ----
MODELS=(
  # text encoder (umt5)  -> text_encoders (+ копия в clip)
  "text_encoders|umt5_xxl_fp8_e4m3fn_scaled.safetensors|https://huggingface.co/f5aiteam/CLIP/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
  # clip vision
  "clip_vision|clip_vision_h.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
  # vae
  "vae|wan_2.1_vae.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
  # diffusion (главная модель Animate)
  "diffusion_models|Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
  # loras (все 4 — реальные URL из шаблона)
  "loras|lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors"
  "loras|wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
  "loras|Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors|https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors"
  "loras|Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Pusa/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors"
  # detection (yolo + vitpose .onnx + .bin)
  "detection|yolov10m.onnx|https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
  "detection|vitpose_h_wholebody_model.onnx|https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
  "detection|vitpose_h_wholebody_data.bin|https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
  # upscaler
  "upscale_models|4xUltrasharp_4xUltrasharpV10.pt|https://huggingface.co/gazsuv/pussydetectorv4/resolve/main/4xUltrasharp_4xUltrasharpV10.pt"
  # --- Z-Image: НЕ нужен для Animator/mask. Расскоментируй если юзаешь Z-Image воркфлоу.
  #   (это part 1 of 2 — понадобятся ещё part 2 + model.safetensors.index.json)
  # "diffusion_models|diffusion_pytorch_model-00001-of-00002.safetensors|https://huggingface.co/Tongyi-MAI/Z-Image/resolve/main/transformer/diffusion_pytorch_model-00001-of-00002.safetensors"
)

# =====================================================================
echo "############# base #############"
apt-get update -y && apt-get install -y git wget curl aria2 ffmpeg unzip || true
$PIP install --upgrade pip setuptools wheel || true

# =====================================================================
echo "############# ComfyUI ($COMFY_COMMIT / 0.10.0) #############"
if [[ ! -d "$COMFY/.git" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY"
fi
cd "$COMFY"
git fetch --all -q || true
git checkout "$COMFY_COMMIT" 2>/dev/null || echo "⚠️ не смог переключиться на $COMFY_COMMIT (оставляю текущий)"
[[ -f requirements.txt ]] && $PIP install --no-cache-dir -r requirements.txt || true

# =====================================================================
echo "############# custom nodes (по коммитам) #############"
mkdir -p "$COMFY/custom_nodes"
cd "$COMFY/custom_nodes"
for entry in "${NODES[@]}"; do
    repo="${entry%%|*}"; commit="${entry##*|}"
    dir="${repo##*/}"; dir="${dir%.git}"
    if [[ ! -d "$dir/.git" ]]; then
        echo "→ clone $dir"
        git clone --recursive "$repo" "$dir" || { echo "[!] clone failed: $repo"; continue; }
    fi
    ( cd "$dir" && git fetch -q --all || true
      git checkout "$commit" 2>/dev/null || echo "  ⚠️ $dir: коммит $commit недоступен, оставляю default" )
    [[ -f "$dir/requirements.txt" ]] && $PIP install --no-cache-dir -r "$dir/requirements.txt" || true
done

# фикс LayerStyle (guidedFilter из cv2.ximgproc) — опционально
$PIP install --no-cache-dir opencv-contrib-python 2>/dev/null || true

# =====================================================================
echo "############# models #############"
dl () {
    local sub="$1" out="$2" url="$3"
    local dir="$COMFY/models/$sub"
    mkdir -p "$dir"
    if [[ -e "$dir/$out" && $(stat -c%s "$dir/$out" 2>/dev/null||echo 0) -gt 1000000 ]]; then
        echo "✅ есть: $sub/$out"; return 0
    fi
    local hdr=()
    [[ -n "$HF_TOKEN" && "$url" == *huggingface.co* ]] && hdr=(--header="Authorization: Bearer $HF_TOKEN")
    echo "→ $sub/$out"
    aria2c -x16 -s16 --continue=true "${hdr[@]}" --dir="$dir" --out="$out" "$url" \
        || echo "  [!] не скачалось: $url"
}

for m in "${MODELS[@]}"; do
    IFS='|' read -r sub out url <<< "$m"
    dl "$sub" "$out" "$url"
done

# umt5 нужен и в clip (некоторые лоадеры смотрят туда)
mkdir -p "$COMFY/models/clip"
[[ -e "$COMFY/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" && \
   ! -e "$COMFY/models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]] && \
   ln -s "$COMFY/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
         "$COMFY/models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# =====================================================================
echo "############# workflows (если положил рядом) #############"
WF="$COMFY/user/default/workflows"; mkdir -p "$WF"
cp "$WORKSPACE"/provisioning/*.json "$WF/" 2>/dev/null || true
cp "$WORKSPACE"/*.json "$WF/" 2>/dev/null || true

echo ""
echo "==========================================="
echo "✅ Готово. ComfyUI 0.10.0 + ноды по коммитам + все модели/лоры."
echo "🔁 Перезапусти ComfyUI (через портал инстанса или процесс)."
echo "==========================================="
