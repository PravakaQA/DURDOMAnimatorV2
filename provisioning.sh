#!/bin/bash
# despam.sh — вырезает рекламный редирект (sinlab.art / landing.html / start-here)
# из ComfyUI. Безопасно: ноды -> карантин, фронт -> чистая переустановка,
# лишние web-файлы -> бэкап+вынос. Минифицированный JS НЕ режется построчно.
# Идемпотентно, можно гонять после каждого ребута.
set +e

C="${COMFY:-/workspace/ComfyUI}"
Q="/workspace/_quarantine"
TS="$(date +%s)"
mkdir -p "$Q"

# сигнатуры рекламного редиректа (добавь сюда новые домены, если всплывут)
SIG='sinlab|sinlab\.art|landing\.html|start-here'

PYBIN="/venv/main/bin/python"
PIPBIN="/venv/main/bin/pip"

# путь к статике фронта
FE="$($PYBIN - <<'PY' 2>/dev/null
import os
try:
    import comfyui_frontend_package as p
    print(os.path.join(os.path.dirname(p.__file__), "static"))
except Exception:
    print("")
PY
)"

found=0

echo "==================================================="
echo "1) custom_nodes — ищу инъектор"
echo "==================================================="
hits=$(grep -rilaE "$SIG" "$C/custom_nodes" 2>/dev/null)
if [ -n "$hits" ]; then
    found=1
    echo "Заражённые файлы:"; echo "$hits" | sed 's/^/   /'
    echo "$hits" | sed -E "s#^($C/custom_nodes/[^/]+)/.*#\1#" | sort -u | while read -r d; do
        n=$(basename "$d")
        echo ">>> карантиню ноду: $n"
        mv "$d" "$Q/${n}.${TS}"
    done
else
    echo "чисто"
fi

echo ""
echo "==================================================="
echo "2) web/ и user/ — лишние внедрённые файлы"
echo "==================================================="
wf=$(grep -rilaE "$SIG" "$C/web" "$C/user" 2>/dev/null)
if [ -n "$wf" ]; then
    found=1
    for f in $wf; do
        echo ">>> бэкап+вынос: $f"
        cp "$f" "$Q/$(basename "$f").${TS}.bak"
        rm -f "$f"
    done
else
    echo "чисто"
fi

echo ""
echo "==================================================="
echo "3) фронт (comfyui_frontend_package) — index.html и пр."
echo "==================================================="
if [ -n "$FE" ] && grep -rilaE "$SIG" "$FE" >/dev/null 2>&1; then
    found=1
    echo ">>> фронт пропатчен — переустанавливаю начисто"
    $PIPBIN install --no-cache-dir --force-reinstall comfyui_frontend_package
else
    echo "чисто (или фронт не найден)"
fi

echo ""
echo "==================================================="
echo "4) прочие .html внутри ComfyUI"
echo "==================================================="
hf=$(grep -rilaE "$SIG" "$C" --include=*.html 2>/dev/null | grep -v "$Q")
if [ -n "$hf" ]; then
    found=1
    for f in $hf; do
        echo ">>> бэкап+вынос: $f"
        cp "$f" "$Q/$(basename "$f").${TS}.bak"
        rm -f "$f"
    done
else
    echo "чисто"
fi

echo ""
echo "==================================================="
echo "5) ПОДОЗРИТЕЛЬНОЕ (только показываю — глянь глазами)"
echo "==================================================="
echo "-- обфускация / редиректы / service worker в нодах и web --"
grep -rilaE "atob\(|eval\(unescape|serviceWorker\.register|location\.(href|replace|assign)\s*=\s*[\"'\`]https?:" \
    "$C/custom_nodes" "$C/web" 2>/dev/null | grep -viE "/node_modules/" | head -40

echo ""
echo "-- entrypoint / системные (правь руками, не трогаю авто) --"
grep -rilaE "$SIG" /root /opt /usr/local/bin /etc 2>/dev/null | grep -v "$Q" | head -20

echo ""
echo "==================================================="
if [ "$found" -eq 1 ]; then
    echo "✅ Что-то нашёл и вычистил. Бэкапы в $Q"
else
    echo "ℹ️ В файлах ComfyUI сигнатур НЕ найдено."
    echo "   Значит редирект зашит в ОБРАЗ/портал шаблона (вне ComfyUI),"
    echo "   и чинить надо переездом на чистый под (см. ниже)."
fi
echo "🔁 Перезапусти ComfyUI и сделай Ctrl+Shift+R (или открой в инкогнито) —"
echo "   зловредный JS кэшируется в браузере и редиректит даже после чистки сервера."
echo "==================================================="
