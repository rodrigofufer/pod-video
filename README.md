# pod-video

Imagen de contenedor para pods de GPU en RunPod que producen video: Remotion (Chrome headless), ffmpeg (el del sistema y uno 8.x estático), Blender 5.x, PyTorch CUDA 12.8, ComfyUI con nodos de LTX-Video y herramientas de audio (WhisperX, ClearerVoice, separación de pistas, detección de ritmo).

- Dos imágenes (se arman solas con GitHub Actions al cambiar el `Dockerfile`):
  - `ghcr.io/rodrigofufer/pod-video:base` (= `:latest`): editores, Remotion, ffmpeg 8, Blender. Ligera, para cada video.
  - `ghcr.io/rodrigofufer/pod-video:ia`: base + PyTorch/ComfyUI, audio, kit de estilo y ACE-Step. Pesada (~19 GB), solo para tareas de IA.
- No trae modelos de IA: se bajan de Hugging Face al usarlos (`HF_HOME`). No trae llaves ni archivos privados.
- Base `runpod/base:1.6.0-ubuntu2404` (sshd y llave pública de RunPod).
- Verificar dentro del pod: `/opt/pod-video/verificar.sh`.

Kit de estilo: Remotion 4.0.545 con motion-blur, effects, transitions, paths, shapes, noise, lottie y roughjs (node_modules en `/opt/anim`); diffusers + OpenColorIO + Playwright/Chromium en `/opt/venv-ia`; ACE-Step 1.5 (música) en `/opt/venv-acestep`.

Rutas: `/opt/anim` (node_modules de Remotion), `/opt/venv-canal` (editores), `/opt/venv-ia` (PyTorch + ComfyUI en `/opt/ComfyUI`), `/opt/venv-audio`, `ffmpeg8`, `blender`.
