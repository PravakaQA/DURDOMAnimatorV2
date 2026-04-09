#!/bin/bash
echo "🚀 Provisioning ANIMATOR V2.1 (VIDEO) started..."

apt-get update && apt-get install -y git wget aria2 python3-pip unzip

cd /workspace/ComfyUI/custom_nodes

echo "📦 Клонируем все custom nodes для Animator V2.1..."

git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
git clone https://github.com/kijai/ComfyUI-KJNodes.git
git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

echo "📦 Устанавливаем зависимости..."
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ $dir"
    pip install -r "$dir/requirements.txt" --no-deps || true
  fi
done

echo "📂 Копируем workflows..."
mkdir -p /workspace/ComfyUI/user/default/workflows
cp /provisioning/animator_v2_1_0.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0.json
cp /provisioning/animator_v2_1_0_mask_mode.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0_mask_mode.json

echo "✅ ANIMATOR V2.1 ГОТОВ!"
echo "Workflows находятся в: /workspace/ComfyUI/user/default/workflows/"