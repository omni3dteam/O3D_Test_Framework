# Dockerfile
# OMNI3D Stack — Timelapse only (testing phase)

FROM python:3.11-slim

# ── system dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    binutils \
    supervisor \
    libz-dev \
    && rm -rf /var/lib/apt/lists/*

# ── Python dependencies ───────────────────────────────────────────────────────
COPY omni3d-container/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    pip install --no-cache-dir pyinstaller

# ── build timelapse binary ────────────────────────────────────────────────────
RUN mkdir -p /app
WORKDIR /build

COPY OMNI3D_Timelapse/src/ /build/OMNI3D_Timelapse/
RUN pyinstaller /build/OMNI3D_Timelapse/timelapse.py --onedir -y \
    && mv /build/dist/timelapse /app/timelapse

# ── supervisord config ────────────────────────────────────────────────────────
COPY omni3d-container/supervisord.conf /etc/supervisor/conf.d/omni3d.conf

WORKDIR /app
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/omni3d.conf"]
