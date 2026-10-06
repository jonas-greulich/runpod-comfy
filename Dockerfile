# runpod-comfy: ComfyUI-Basis-Image für RunPod, ohne Modelle.
# Modelle lädt scripts/start.sh beim Pod-Start je nach PROFILE nach.
FROM ubuntu:24.04

ARG COMFYUI_VERSION=v0.39.1
ARG TORCH_INDEX=https://download.pytorch.org/whl/cu128

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    COMFY_DIR=/opt/ComfyUI

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev build-essential \
        git aria2 ffmpeg libgl1 libglib2.0-0 ca-certificates \
        openssh-server rsync curl \
    && rm -rf /var/lib/apt/lists/* \
    && python3.12 -m venv $VIRTUAL_ENV \
    && mkdir -p /run/sshd

# PyTorch (CUDA 12.8: RTX 4090/5090, L40S, A100, H100)
RUN pip install --upgrade pip \
    && pip install torch torchvision torchaudio --index-url $TORCH_INDEX

# ComfyUI, auf Release-Tag gepinnt
RUN git clone --depth 1 --branch $COMFYUI_VERSION https://github.com/comfyanonymous/ComfyUI.git $COMFY_DIR \
    && pip install -r $COMFY_DIR/requirements.txt

# Custom Nodes, auf Commits gepinnt (Stand 2026-10-06)
COPY custom_nodes.txt /tmp/custom_nodes.txt
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN cd $COMFY_DIR/custom_nodes \
    && grep -vE '^\s*(#|$)' /tmp/custom_nodes.txt | while read -r url commit; do \
         name=$(basename "$url" .git); \
         git clone "$url" "$name" && git -C "$name" checkout "$commit"; \
         if [ -f "$name/requirements.txt" ]; then pip install -r "$name/requirements.txt"; fi; \
       done

COPY scripts/ /opt/scripts/
COPY profiles/ /opt/profiles/
COPY workflows/ /opt/workflows/
RUN chmod +x /opt/scripts/*.sh

EXPOSE 8188 22
WORKDIR $COMFY_DIR
CMD ["/opt/scripts/start.sh"]
