# pod-video

Imagen de contenedor para pods de GPU en RunPod que producen video: Remotion (Chrome headless), ffmpeg (el del sistema y uno 8.x estático), Blender 5.x, PyTorch CUDA 12.8, ComfyUI con nodos de LTX-Video y herramientas de audio (WhisperX, ClearerVoice, separación de pistas, detección de ritmo).

- Imagen: `ghcr.io/rodrigofufer/pod-video:latest` (se arma sola con GitHub Actions al cambiar el `Dockerfile`).
- No trae modelos de IA: se bajan de Hugging Face al usarlos (`HF_HOME`). No trae llaves ni archivos privados.
- Base `runpod/base:1.6.0-ubuntu2404` (sshd y llave pública de RunPod).
- Verificar dentro del pod: `/opt/pod-video/verificar.sh`.

Rutas: `/opt/anim` (node_modules de Remotion), `/opt/venv-canal` (editores), `/opt/venv-ia` (PyTorch + ComfyUI en `/opt/ComfyUI`), `/opt/venv-audio`, `ffmpeg8`, `blender`.
