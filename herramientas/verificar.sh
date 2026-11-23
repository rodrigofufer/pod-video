#!/bin/bash
# Verifica qué trae la imagen del pod de video. Uso en el pod: /opt/pod-video/verificar.sh  (--sin-gpu: sin nvidia-smi)
echo "imagen pod-video $(cat /opt/pod-video/VERSION 2>/dev/null)"
[ "$1" = "--sin-gpu" ] || nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
echo "ffmpeg (sistema): $(ffmpeg -version | head -1)"
echo "ffmpeg8: $(ffmpeg8 -version 2>/dev/null | head -1)"
ffmpeg8 -hide_banner -encoders 2>/dev/null | grep -qE "h264_nvenc|hevc_nvenc" && echo "  ffmpeg8 NVENC: sí"
ffmpeg8 -hide_banner -filters 2>/dev/null | grep -oE " (libplacebo|whisper|libvmaf|fruc_vulkan) " | tr '\n' ' '; echo
echo "node: $(node -v) · remotion: $(cd /opt/anim && node -p "require('remotion/package.json').version")"
echo "blender: $(blender --version 2>/dev/null | head -1)"
echo "venv-canal: $(/opt/venv-canal/bin/python -c 'import numpy,PIL,faster_whisper;print("ok")' 2>&1 | tail -1)"
echo "venv-ia: $(/opt/venv-ia/bin/python -c 'import torch;print("torch",torch.__version__,"cuda",torch.version.cuda,"gpu",torch.cuda.is_available())' 2>&1 | tail -1)"
echo "venv-audio: $(/opt/venv-audio/bin/python -c 'import importlib.util as u;print({m:bool(u.find_spec(m)) for m in ["whisperx","clearvoice","audio_separator","beat_this","scenedetect"]})' 2>&1 | tail -1)"
echo "kit estilo: $(/opt/venv-ia/bin/python -c 'import diffusers,PyOpenColorIO,playwright;print("diffusers",diffusers.__version__,"ocio ok","playwright ok")' 2>&1 | tail -1)"
echo "ACE-Step: $(ls /opt/ACE-Step-1.5 >/dev/null 2>&1 && /opt/venv-acestep/bin/python -c 'import acestep;print("ok")' 2>&1 | tail -1)"
echo "ComfyUI: $(git -C /opt/ComfyUI log -1 --format=%cd --date=short 2>/dev/null) · nodos: $(ls /opt/ComfyUI/custom_nodes | tr '\n' ' ')"
[ -s /opt/AVISOS.txt ] && { echo "AVISOS:"; cat /opt/AVISOS.txt; }
exit 0
