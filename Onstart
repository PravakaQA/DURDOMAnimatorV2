#!/usr/bin/env bash
# onstart.sh — ЛЁГКИЙ фикс на КАЖДЫЙ старт пода (Vast On-start / PROVISIONING_SCRIPT).
# Делает только быстрые вещи, НЕ клонирует ноды/модели (они в /workspace):
#   1) чистит рекламный редирект (teskors-инжектор)
#   2) ставит guard-ноду, которая чистит инжектор при каждом запуске ComfyUI
#   3) чинит onnxruntime под нужный CUDA (libcudart.so.13/12) -> возвращает 3 ноды
set +e
COMFY=/workspace/ComfyUI
CN="$COMFY/custom_nodes"
VENV=/venv/main
[ -f "$VENV/bin/activate" ] && source "$VENV/bin/activate"
PY="$VENV/bin/python"; command -v "$PY" >/dev/null 2>&1 || PY=python
PIP="$PY -m pip"

echo "===== [onstart] 1/3 despam ====="
find "$CN" -type f -name 'ts_photo_preview.js' -delete 2>/dev/null
grep -rilaE 'location\.(replace|assign|href)[[:space:]]*=|window\.location[[:space:]]*=|Gathering applications|sinlab|landing\.html|start-here' \
  "$CN" --include=*.js --include=*.html 2>/dev/null | xargs -r rm -f
echo "ок"

echo "===== [onstart] 2/3 guard-нода ====="
GUARD="$CN/zzz_despam_guard"
mkdir -p "$GUARD"
cat > "$GUARD/__init__.py" <<'PYEOF'
# Авто-чистка рекламного инжектора при КАЖДОМ старте ComfyUI.
# Грузится последним (имя zzz_*), поэтому сносит файл даже если нода его восстановила.
import os, re
_CN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_STRONG = re.compile(r"sinlab|landing\.html|start-here|Gathering applications", re.I)
_REDIR  = re.compile(r"location\.(replace|assign|href)\s*=|window\.location\s*=", re.I)
_BADNAME = {"ts_photo_preview.js"}
_n = 0
for _root, _dirs, _files in os.walk(_CN):
    if "zzz_despam_guard" in _root:
        continue
    _in_teskors = "teskors" in _root.lower()
    for _fn in _files:
        if not _fn.endswith((".js", ".html")):
            continue
        _p = os.path.join(_root, _fn)
        try:
            if _fn in _BADNAME:
                os.remove(_p); _n += 1; print("[despam] removed", _p); continue
            with open(_p, "r", errors="ignore") as _f:
                _t = _f.read()
            if _STRONG.search(_t) or (_in_teskors and _REDIR.search(_t)):
                os.remove(_p); _n += 1; print("[despam] removed", _p)
        except Exception:
            pass
if _n:
    print(f"[despam] guard cleaned {_n} file(s)")
NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}
PYEOF
echo "guard поставлена: $GUARD"

echo "===== [onstart] 3/3 onnxruntime GPU ====="
# определяем какой libcudart нужен ORT (по .so, без импорта — он может падать)
ORTSO=$(find "$VENV" -path '*/onnxruntime/capi/onnxruntime_pybind11_state*.so' 2>/dev/null | head -1)
if [ -n "$ORTSO" ]; then
    NEED=$(ldd "$ORTSO" 2>/dev/null | grep -oE 'libcudart\.so\.[0-9]+' | grep -oE '[0-9]+$' | head -1)
    echo "onnxruntime требует libcudart.so.${NEED:-?}"
    if ! ldconfig -p 2>/dev/null | grep -q "libcudart.so.${NEED}"; then
        if [ "$NEED" = "13" ]; then
            # CUDA 13: пакеты БЕЗ суффикса (старые *-cu13 — пустышки и валятся)
            $PIP install -q --no-cache-dir nvidia-cuda-runtime nvidia-cublas nvidia-cufft nvidia-curand nvidia-cudnn-cu13
        elif [ -n "$NEED" ]; then
            $PIP install -q --no-cache-dir nvidia-cuda-runtime-cu12 nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 nvidia-cudnn-cu12
        fi
    else
        echo "libcudart.so.${NEED} уже в ldconfig — пропускаю установку"
    fi
    PYLIB=$($PY -c "import site;print(site.getsitepackages()[0])" 2>/dev/null)
    [ -n "$PYLIB" ] && { ls -d "$PYLIB"/nvidia/*/lib > /etc/ld.so.conf.d/zz-nvidia-onnx.conf 2>/dev/null; ldconfig; }
fi
$PY -c "import onnxruntime as o; print('[onnx] OK', o.get_available_providers())" 2>/dev/null \
  || echo "[onnx] всё ещё не импортится — глянь строку 'требует libcudart' выше"

echo "===== [onstart] done — перезапусти ComfyUI (pkill -f main.py), если он уже стартовал ====="
