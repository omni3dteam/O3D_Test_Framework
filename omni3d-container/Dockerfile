# Dockerfile
# OMNI3D Stack — OMNI3D_Template (testing phase)

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

# ── build binary ─────────────────────────────────────────────────────────────
RUN mkdir -p /app
WORKDIR /build

COPY OMNI3D_Template/src/ /build/OMNI3D_Template/
RUN pyinstaller /build/OMNI3D_Template/template.py --onedir -y \
    && mv /build/dist/template /app/template

# ── supervisord config ────────────────────────────────────────────────────────
COPY omni3d-container/supervisord.conf /etc/supervisor/conf.d/omni3d.conf

WORKDIR /app
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/omni3d.conf"]
