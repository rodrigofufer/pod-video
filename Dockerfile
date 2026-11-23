# Imagen del pod de video de Rodrigo (RunPod). Lleva YA INSTALADO lo que antes se instalaba en cada pod, más las
# herramientas nuevas. Sin modelos de IA dentro (se bajan de Hugging Face al usarlos) y SIN llaves ni archivos privados.
# Se arma en GitHub Actions (.github/workflows/imagen.yml) → ghcr.io/rodrigofufer/pod-video:latest
# Detalle y plan: /home/rod/conocimiento/proyectos/pod-video.md

# Misma base que los pods de siempre (sshd + PUBLIC_KEY de RunPod): el ssh, el vigía y los scripts funcionan igual.
FROM runpod/base:1.6.0-ubuntu2404

ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1 NVIDIA_DRIVER_CAPABILITIES=all \
    HF_HUB_ENABLE_HF_TRANSFER=1 HF_HOME=/root/.cache/huggingface NPM_CONFIG_UPDATE_NOTIFIER=false NO_UPDATE_NOTIFIER=1

# ── 1. Lo de siempre: editores (editar16, editar_multi) y Remotion (Chrome headless) ───────────────────────────────
# El ffmpeg del sistema (apt, Ubuntu 24.04) es el MISMO que usaban los pods: los masters salen idénticos.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ffmpeg fonts-lato fonts-noto-core python3-venv python3-dev rsync file xz-utils curl ca-certificates imagemagick git \
      libnss3 libdbus-1-3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libxkbcommon0 libxcomposite1 libxdamage1 \
      libxfixes3 libxrandr2 libgbm1 libasound2t64 libpango-1.0-0 libcairo2 libegl1 libgl1 libgles2 libdrm2 \
      libxshmfence1 libx11-xcb1 libxss1 libxtst6 libgtk-3-0t64 libvulkan1 libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Node 22 LTS oficial, con sha256
RUN set -e; B=https://nodejs.org/dist/latest-v22.x; curl -fsSL "$B/SHASUMS256.txt" -o /tmp/s; \
    NV=$(awk '$2 ~ /linux-x64\.tar\.xz$/ {print $2}' /tmp/s); curl -fsSL -o /tmp/n.tar.xz "$B/$NV"; \
    echo "$(awk -v f="$NV" '$2==f {print $1}' /tmp/s)  /tmp/n.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/n.tar.xz -C /opt; for b in node npm npx; do ln -sf "/opt/${NV%.tar.xz}/bin/$b" /usr/local/bin/$b; done; \
    rm -f /tmp/n.tar.xz /tmp/s

# node_modules del proyecto de escenas (anim/) + Chrome headless shell de Remotion. anim_render.py los copia si el
# package-lock.json del proyecto es el mismo (LOCK_SHA); si cambió, hace npm ci como antes.
COPY anim/package.json anim/package-lock.json /opt/anim/
RUN cd /opt/anim && npm ci --no-audit --no-fund --loglevel=error && npx remotion browser ensure --log=error \
    && sha256sum package-lock.json | cut -d' ' -f1 > /opt/anim/LOCK_SHA

# venv de los editores (el mismo que creaba nube.py en cada pod)
RUN python3 -m venv /opt/venv-canal && /opt/venv-canal/bin/pip install -q numpy pillow "onnxruntime-gpu[cuda,cudnn]" \
      faster-whisper nvidia-cublas-cu12 nvidia-cudnn-cu12

# ── 2. Nuevo: ffmpeg 8.x estático (NVENC, libplacebo, vmaf, Vulkan, whisper) como «ffmpeg8» (no reemplaza al de arriba) ──
RUN set -e; U=$(curl -fsSL https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest \
      | python3 -c "import json,sys; a=[x['browser_download_url'] for x in json.load(sys.stdin)['assets'] if x['name'].endswith('-linux64-gpl-8.1.tar.xz') or x['name'].endswith('-linux64-gpl-8.0.tar.xz')]; print(sorted(a)[-1])"); \
    echo "ffmpeg8: $U"; curl -fsSL "$U" | tar -xJ -C /opt; D=$(ls -d /opt/ffmpeg-n8*-linux64-gpl-8*); \
    ln -s "$D/bin/ffmpeg" /usr/local/bin/ffmpeg8; ln -s "$D/bin/ffprobe" /usr/local/bin/ffprobe8

# ── 3. Nuevo: Blender 5.x (Cycles con OptiX, Gaussian splats) en modo consola ────────────────────────────────────
RUN set -e; S=$(curl -fsSL https://download.blender.org/release/ | grep -o 'Blender5\.[0-9]*/' | sort -t. -k2 -n | tail -1); \
    F=$(curl -fsSL "https://download.blender.org/release/$S" | grep -o 'blender-5\.[0-9.]*-linux-x64\.tar\.xz' | sort -V | tail -1); \
    echo "blender: $S$F"; curl -fsSL "https://download.blender.org/release/$S$F" | tar -xJ -C /opt; \
    ln -s /opt/${F%.tar.xz}/blender /usr/local/bin/blender

# ── 4. Nuevo: IA (PyTorch CUDA 12.8 para la 5090 + ComfyUI + Hugging Face rápido) ───────────────────────────────
RUN python3 -m venv /opt/venv-ia && /opt/venv-ia/bin/pip install -q torch torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cu128 \
    && /opt/venv-ia/bin/pip install -q "huggingface_hub[hf_transfer]" boto3 \
    && git clone --depth 1 https://github.com/Comfy-Org/ComfyUI /opt/ComfyUI \
    && /opt/venv-ia/bin/pip install -q -r /opt/ComfyUI/requirements.txt \
    && git clone --depth 1 https://github.com/Lightricks/ComfyUI-LTXVideo /opt/ComfyUI/custom_nodes/ComfyUI-LTXVideo \
    && (/opt/venv-ia/bin/pip install -q -r /opt/ComfyUI/custom_nodes/ComfyUI-LTXVideo/requirements.txt || echo "aviso: requisitos de ComfyUI-LTXVideo" >> /opt/AVISOS.txt)

# ── 5. Nuevo: audio (venv aparte para que no choque con ComfyUI): transcripción, limpieza de voz, separar pistas, ritmo ──
RUN python3 -m venv /opt/venv-audio && /opt/venv-audio/bin/pip install -q torch torchaudio --index-url https://download.pytorch.org/whl/cu128 \
    && for p in whisperx clearvoice "audio-separator[gpu]" beat-this auto-editor "scenedetect[opencv]" "huggingface_hub[hf_transfer]"; do \
         /opt/venv-audio/bin/pip install -q "$p" || echo "aviso: no se instaló $p" >> /opt/AVISOS.txt; done

# ── 5b. Kit de estilo «Huge» (2026-11-22, ver ~/conocimiento/proyectos/kit-estilo.md) ──────────────────────────
# venv-ia: FLUX 3 Klein y otros modelos de imagen por diffusers (miniaturas), OpenColorIO (color fijo del canal) y
# Playwright + Chromium (capturas de titulares y páginas para collages, como en Huge If True).
RUN /opt/venv-ia/bin/pip install -q diffusers transformers accelerate sentencepiece protobuf opencolorio playwright \
    && /opt/venv-ia/bin/playwright install --with-deps chromium >/dev/null \
    || echo "aviso: kit de estilo en venv-ia incompleto" >> /opt/AVISOS.txt
# ACE-Step 1.5 (música propia del canal, MIT): se instala con «uv sync» (nano-vllm viene dentro de su repo, no de
# PyPI). Su entorno queda en /opt/ACE-Step-1.5/.venv; los pesos se bajan al usarlo (HF_HOME).
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
    && git clone --depth 1 https://github.com/ACE-Step/ACE-Step-1.5 /opt/ACE-Step-1.5 \
    && (cd /opt/ACE-Step-1.5 && uv sync --python 3.12 -q) \
    && ln -s /opt/ACE-Step-1.5/.venv /opt/venv-acestep \
    || echo "aviso: ACE-Step 1.5 no se instaló" >> /opt/AVISOS.txt

# ── 6. Ficha de la imagen ───────────────────────────────────────────────────────────────────────────────────────
COPY herramientas/verificar.sh /opt/pod-video/verificar.sh
RUN chmod +x /opt/pod-video/verificar.sh && touch /opt/AVISOS.txt && date -u +%Y-%m-%dT%H:%MZ > /opt/pod-video/VERSION \
    && /opt/pod-video/verificar.sh --sin-gpu > /opt/pod-video/versiones.txt 2>&1 || true
