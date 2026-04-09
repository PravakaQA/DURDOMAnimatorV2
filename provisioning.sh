#!/bin/bash
echo "🚀 Provisioning ANIMATOR V2.1 (VIDEO) - FULL AUTO FIXED started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip
cd /workspace/ComfyUI/custom_nodes
# ←←←←← ЭТО САМАЯ ВАЖНАЯ СТРОКА ←←←←←
PIP="/venv/main/bin/pip"
echo "📦 Используем venv pip: $PIP"
echo "📥 Клонируем ВСЕ custom nodes для Animator V2.1..."
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git
git clone https://github.com/kijai/ComfyUI-KJNodes.git
git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git
git clone https://github.com/cubiq/ComfyUI_essentials.git
git clone https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git
git clone https://github.com/PGCRT/CRT-Nodes.git

echo "📦 Устанавливаем все зависимости в venv..."
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Устанавливаем зависимости для $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

echo "📂 Копируем workflows..."
mkdir -p /workspace/ComfyUI/user/default/workflows
cp /workspace/provisioning/animator_v2_1_0.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0.json 2>/dev/null || echo "⚠️ animator_v2_1_0.json не найден"
cp /workspace/provisioning/animator_v2_1_0_mask_mode.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0_mask_mode.json 2>/dev/null || echo "⚠️ animator_v2_1_0_mask_mode.json не найден"

# ====================== МОДЕЛИ ======================
echo ""
echo "🚀 Скачиваем все модели для ANIMATOR V2.1..."
cd /workspace/ComfyUI/models
mkdir -p diffusion_models vae clip_vision clip loras

echo "📥 1. Основная модель → WanModel.safetensors (~25-30 ГБ)"
aria2c -x 16 -s 16 --continue=true --dir=diffusion_models \
  --out=WanModel.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"

echo "📥 2. VAE → mo_vae.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=vae \
  --out=mo_vae.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"

echo "📥 3. CLIP Vision → klip_vision.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=clip_vision \
  --out=klip_vision.safetensors \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

echo "📥 4. Text Encoder → text_enc.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=clip \
  --out=text_enc.safetensors \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

echo "📥 5. LoRA light → light.safetensors"
LIGHT_URL="https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/light.safetensors"
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -I "$LIGHT_URL")
if [ "$HTTP_STATUS" = "200" ]; then
  aria2c -x 16 -s 16 --continue=true --dir=loras \
    --out=light.safetensors \
    "$LIGHT_URL"
else
  echo "⚠️ light.safetensors не найден публично (HTTP $HTTP_STATUS) — поставь вручную или замени на none в воркфлоу"
fi

echo "📥 6. LoRA wan_reworked → wan_reworked.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=wan_reworked.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/wan_reworked.safetensors"

echo "📥 7. LoRA WanPusa → WanPusa.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=WanPusa.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/WanPusa.safetensors"

echo "📥 8. LoRA WanFun.reworked → WanFun.reworked.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=WanFun.reworked.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/WanFun.reworked.safetensors"

echo ""
echo "✅ ANIMATOR V2.1 ПОЛНОСТЬЮ ГОТОВ!"
echo "Workflows: /workspace/ComfyUI/user/default/workflows/"
echo "Модели: diffusion_models, vae, clip_vision, clip, loras"
echo "После перезапуска ComfyUI зайди в Manager → Check Missing (должно быть чисто)"
echo "Готово к запуску! 🔥"
