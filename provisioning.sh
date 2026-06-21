#!/bin/bash
# =====================================================================
# Animator V2.1 — provisioning (на базе рабочего шаблона animka.sh)
# ComfyUI 0.10.0 + те же ноды (по коммитам) + реальные URL моделей.
# ВСТРОЕНА авто-чистка рекламного редиректа (teskors ts_photo_preview.js и пр.).
# ВСТРОЕН авто-фикс onnxruntime-gpu под нужный CUDA (cu13/cu12) для детекта позы.
# Подходит как PROVISIONING_SCRIPT на Vast.ai — гонится сам при запуске,
# ComfyUI стартует портал, поэтому здесь его НЕ запускаем.
# =====================================================================
set -e
source /venv/main/bin/activate 2>/dev/null || true

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY="${WORKSPACE}/ComfyUI"
PIP="pip"
HF_TOKEN="${HF_TOKEN:-}"   # опц.: export HF_TOKEN=... если упрётся в гейт HF

COMFY_COMMIT="9d273d3a"    # ComfyUI 0.10.0 (как в рабочем шаблоне)

# repo|commit
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

# папка | имя_файла | url
MODELS=(
  "text_encoders|umt5_xxl_fp8_e4m3fn_scaled.safetensors|https://huggingface.co/f5aiteam/CLIP/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
  "clip_vision|clip_vision_h.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
  "vae|wan_2.1_vae.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
  "diffusion_models|Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
  "loras|lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors"
  "loras|wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
  "loras|Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors|https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors"
  "loras|Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Pusa/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors"
  "detection|yolov10m.onnx|https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
  "detection|vitpose_h_wholebody_model.onnx|https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
  "detection|vitpose_h_wholebody_data.bin|https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
  "upscale_models|4xUltrasharp_4xUltrasharpV10.pt|https://huggingface.co/gazsuv/pussydetectorv4/resolve/main/4xUltrasharp_4xUltrasharpV10.pt"
)

# сигнатуры рекламного редиректа.
#  - SPAM_SIG: строки/домены лендинга (домен может меняться, строка "Gathering
#    applications" у этого зловреда стабильна; IP редиректа у каждого пода свой).
#  - REDIR_SIG: код жёсткого редиректа браузера (легит-виджеты так не делают).
SPAM_SIG='sinlab|landing\.html|start-here|Gathering applications|gatherApplications'
REDIR_SIG='location\.(replace|assign|href)[[:space:]]*=?[[:space:]]*[`'"'"'"(]|top\.location|window\.location[[:space:]]*='
# известные имена файлов-инжекторов (teskors)
BAD_FILES='ts_photo_preview.js'

# =====================================================================
echo "############# base #############"
apt-get update -y && apt-get install -y git wget curl aria2 ffmpeg unzip || true
$PIP install --upgrade pip setuptools wheel || true

echo "############# ComfyUI ($COMFY_COMMIT / 0.10.0) #############"
if [[ ! -d "$COMFY/.git" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY"
fi
cd "$COMFY"
git fetch --all -q || true
git checkout "$COMFY_COMMIT" 2>/dev/null || echo "⚠️ не смог переключиться на $COMFY_COMMIT (оставляю текущий)"
[[ -f requirements.txt ]] && $PIP install --no-cache-dir -r requirements.txt || true

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

# фикс LayerStyle (guidedFilter) — опционально
$PIP install --no-cache-dir opencv-contrib-python 2>/dev/null || true

# ВАЖНО (делаем ПОСЛЕ нод, иначе их requirements вернут CPU-onnxruntime):
# поза (yolo/vitpose .onnx) должна считаться на GPU. onnxruntime + onnxruntime-gpu
# вместе ломают CUDA — поэтому сносим оба и ставим ТОЛЬКО onnxruntime-gpu.
echo "############# onnxruntime-gpu (GPU для детекта позы) #############"
$PIP uninstall -y onnxruntime onnxruntime-gpu 2>/dev/null || true
$PIP install --no-cache-dir onnxruntime-gpu || true

# Свежие onnxruntime-gpu (>=1.23) собраны под CUDA 13 и требуют libcudart.so.13,
# а torch на поде обычно cu12 (только libcudart.so.12) → ImportError, нода
# WanAnimatePreprocess падает ("missing nodes"). Определяем, какой major нужен
# онниксу, и доставляем РОВНО те nvidia-CUDA-либы.
# !!! Для CUDA 13 пакеты идут БЕЗ суффикса (nvidia-cuda-runtime / -cublas / ...),
#     а старые *-cu13 стали пустыми заглушками и валятся при сборке. cuDNN — cu13.
ORTDIR=$(/venv/main/bin/python -c "import onnxruntime,os;print(os.path.dirname(onnxruntime.__file__))" 2>/dev/null)
NEED=$(ldd "$ORTDIR"/capi/onnxruntime_pybind11_state*.so 2>/dev/null \
        | grep -oE 'libcudart\.so\.[0-9]+' | grep -oE '[0-9]+$' | head -1)
echo "onnxruntime требует libcudart.so.${NEED:-?}"
if [[ "$NEED" == "13" ]]; then
    $PIP install --no-cache-dir nvidia-cuda-runtime nvidia-cublas nvidia-cufft nvidia-curand nvidia-cudnn-cu13 || true
else
    # фолбэк/дефолт — CUDA 12 (старые суффиксы)
    $PIP install --no-cache-dir nvidia-cuda-runtime-cu12 nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 nvidia-cudnn-cu12 || true
fi

# прописать все nvidia-либы в ldconfig, чтобы ComfyUI (его поднимает портал)
# видел libcudart.so.* при старте — иначе onnxruntime снова не импортнётся.
PYLIB=$(/venv/main/bin/python -c "import site;print(site.getsitepackages()[0])" 2>/dev/null)
if [[ -n "$PYLIB" ]]; then
    ls -d "$PYLIB"/nvidia/*/lib > /etc/ld.so.conf.d/zz-nvidia-onnx.conf 2>/dev/null || true
    ldconfig || true
fi
echo "проверка провайдеров (должен быть CUDAExecutionProvider):"
/venv/main/bin/python -c "import onnxruntime as o; print(o.__version__, o.get_available_providers())" 2>/dev/null \
    || echo "⚠️ onnxruntime не импортнулся — глянь строку 'требует libcudart' выше"

# =====================================================================
echo "############# 🧹 sanitize: вырезаю рекламные редиректы #############"
# Чистим ТОЛЬКО заражённые web-ассеты (js/html), сами ноды (TSColorMatch,
# TSVideoCombineNoMetadata и т.д.) остаются рабочими. Домен инжектора меняется,
# поэтому чистим тремя ситами: известные строки лендинга + код жёсткого
# редиректа браузера + известные имена файлов-инжекторов.
CN="$COMFY/custom_nodes"
removed=0
nuke () { [[ -f "$1" ]] && { echo "🧹 удаляю инъектор: $1"; rm -f "$1"; removed=$((removed+1)); }; }

# 1) известные строки лендинга по всем web-ассетам всех нод
while IFS= read -r f; do [[ -n "$f" ]] && nuke "$f"; done < <(
    grep -rilaE "$SPAM_SIG" "$CN" --include=*.js --include=*.html --include=*.css 2>/dev/null)

# 2) известные имена файлов-инжекторов
for bf in $BAD_FILES; do
    while IFS= read -r f; do [[ -n "$f" ]] && nuke "$f"; done < <(
        find "$CN" -type f -name "$bf" 2>/dev/null)
done

# 3) любой web-js с кодом жёсткого редиректа браузера (легит-виджеты так не делают)
while IFS= read -r f; do [[ -n "$f" ]] && nuke "$f"; done < <(
    grep -rilaE "$REDIR_SIG" "$CN" --include=*.js 2>/dev/null)

[[ "$removed" -eq 0 ]] && echo "чисто — рекламных вставок не найдено" \
                       || echo "удалено инъекторов: $removed"

# если сигнатура вдруг в .py — авто не трогаем, только предупреждаем
pybad=$(grep -rilaE "$SPAM_SIG" "$CN" --include=*.py 2>/dev/null)
[[ -n "$pybad" ]] && echo "⚠️ ВНИМАНИЕ: сигнатура в .py (проверь руками): $pybad"

# =====================================================================
echo "############# models #############"
dl () {
    local sub="$1" out="$2" url="$3"
    local dir="$COMFY/models/$sub"; mkdir -p "$dir"
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

# umt5 нужен и в clip
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
echo "✅ Готово. ComfyUI 0.10.0 + ноды + модели + рекламный редирект вычищен."
echo "ℹ️ ComfyUI поднимет портал инстанса сам (тут не запускаем)."
echo "==========================================="

