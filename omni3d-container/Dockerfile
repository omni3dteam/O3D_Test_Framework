# Dockerfile
# OMNI3D Stack — OMNI3D_Template (testing phase)
#
# Build order:
#   1. Install omnode (internal library)
#   2. Install service requirements
#   3. Build service binary with PyInstaller

FROM python:3.11-slim

# ── system dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    binutils \
    supervisor \
    libz-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# ── build and install omnode ──────────────────────────────────────────────────
COPY OMNI3D_omnode/ /build/OMNI3D_omnode/
RUN SETUPTOOLS_SCM_PRETEND_VERSION=0.0.1 \
    pip install --no-cache-dir /build/OMNI3D_omnode/

# ── service dependencies ──────────────────────────────────────────────────────
COPY omni3d-container/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    pip install --no-cache-dir pyinstaller

# ── build service binary ──────────────────────────────────────────────────────
RUN mkdir -p /app
WORKDIR /build

COPY OMNI3D_Template/src/ /build/OMNI3D_Template/
COPY OMNI3D_omnode/src/ /build/omnode/
RUN pyinstaller /build/OMNI3D_Template/template.py --onedir -y \
    --paths /build \
    --collect-all omnode \
    --collect-all fastapi \
    --collect-all uvicorn \
    && mv /build/dist/template /app/template

# ── supervisord config ────────────────────────────────────────────────────────
COPY omni3d-container/supervisord.conf /etc/supervisor/conf.d/omni3d.conf

WORKDIR /app
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/omni3d.conf"]
