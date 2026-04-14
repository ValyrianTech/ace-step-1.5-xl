# =============================================================================
# ACE-Step 1.5 XL FastAPI Server - Multi-stage Dockerfile
# =============================================================================
# This image includes the ACE-Step XL models (~20GB total)
# Build with: docker build --build-arg HF_TOKEN=your_token -t acestep-api-xl:latest .
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Model Downloader - Download models from HuggingFace
# -----------------------------------------------------------------------------
FROM python:3.11-slim as model-downloader

# Accept HuggingFace token as build argument (required for gated models)
ARG HF_TOKEN
ENV HF_TOKEN=${HF_TOKEN}

WORKDIR /models

# Install huggingface-hub with hf_transfer for faster downloads
RUN pip install --no-cache-dir "huggingface-hub[cli,hf_transfer]"

# Enable fast transfers
ENV HF_HUB_ENABLE_HF_TRANSFER=1

# Download main model package (includes VAE, Qwen3-Embedding, acestep-5Hz-lm-1.7B)
# Uses HF_TOKEN for authentication with gated repos
# Exclude non-XL DiT models since we use acestep-v15-xl-base instead
RUN python -c "import os; from huggingface_hub import snapshot_download; snapshot_download('ACE-Step/Ace-Step1.5', local_dir='/models/checkpoints', token=os.environ.get('HF_TOKEN'), ignore_patterns=['acestep-v15-turbo/*', 'acestep-v15-base/*'])"

# Download acestep-v15-xl-base as the primary DiT model (4B parameters, ~9GB)
RUN python -c "import os; from huggingface_hub import snapshot_download; snapshot_download('ACE-Step/acestep-v15-xl-base', local_dir='/models/checkpoints/acestep-v15-xl-base', token=os.environ.get('HF_TOKEN'))"

# Optional: Download additional LM models (uncomment if needed)
# RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('ACE-Step/acestep-5Hz-lm-0.6B', local_dir='/models/checkpoints/acestep-5Hz-lm-0.6B')"
# RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('ACE-Step/acestep-5Hz-lm-4B', local_dir='/models/checkpoints/acestep-5Hz-lm-4B')"

# Optional: Download additional XL DiT models (uncomment if needed)
# RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('ACE-Step/acestep-v15-xl-sft', local_dir='/models/checkpoints/acestep-v15-xl-sft')"
# RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('ACE-Step/acestep-v15-xl-turbo', local_dir='/models/checkpoints/acestep-v15-xl-turbo')"

# -----------------------------------------------------------------------------
# Stage 2: Runtime - Install ACE-Step and run from /app
# -----------------------------------------------------------------------------
FROM nvidia/cuda:13.0.0-runtime-ubuntu22.04 as runtime

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Library paths for torchcodec (PyTorch libs + CUDA libs)
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/lib/python3.11/dist-packages/torch/lib:${LD_LIBRARY_PATH} \
    # ACE-Step configuration
    ACESTEP_PROJECT_ROOT=/app \
    ACESTEP_OUTPUT_DIR=/app/outputs \
    ACESTEP_TMPDIR=/app/outputs \
    ACESTEP_DEVICE=cuda \
    # ACE-Step API model paths (full paths to pre-baked XL models)
    ACESTEP_CONFIG_PATH=/app/checkpoints/acestep-v15-xl-base \
    ACESTEP_LM_MODEL_PATH=/app/checkpoints/acestep-5Hz-lm-1.7B \
    ACESTEP_LM_BACKEND=pt \
    # Server configuration
    ACESTEP_API_HOST=0.0.0.0 \
    ACESTEP_API_PORT=8000

WORKDIR /app

# Install system dependencies including Python, pip, git, and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3-pip \
    git \
    curl \
    build-essential \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.11 /usr/bin/python

# Install uv for faster dependency resolution
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Clone ACE-Step directly into /app and install
RUN git clone https://github.com/ace-step/ACE-Step-1.5.git /app && \
    rm -rf /app/.git && \
    uv pip install --system --no-cache .

# Create symlink so ACE-Step's model discovery finds /app/checkpoints
# ACE-Step uses __file__ to locate checkpoints relative to its install path
RUN ln -s /app/checkpoints /usr/local/lib/python3.11/dist-packages/checkpoints

# Copy models from model-downloader stage into /app/checkpoints
COPY --from=model-downloader /models/checkpoints /app/checkpoints

# Create placeholder for acestep-v15-turbo to satisfy check_main_model_exists()
# We use acestep-v15-xl-base instead, but the check looks for all MAIN_MODEL_COMPONENTS
RUN mkdir -p /app/checkpoints/acestep-v15-turbo

# Copy startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Create output directory
RUN mkdir -p /app/outputs

# Install FFmpeg 6+ from PPA for torchcodec compatibility (Ubuntu 22.04 has FFmpeg 4.4 which is too old)
# Also install libnpp for CUDA video decoding support
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common \
    && add-apt-repository -y ppa:ubuntuhandbook1/ffmpeg6 \
    && apt-get update && apt-get install -y --no-install-recommends \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswresample-dev \
    libavdevice-dev \
    libnpp-12-8 \
    && rm -rf /var/lib/apt/lists/*

# Downgrade torchcodec to 0.10.0 (compatible with PyTorch 2.10, 0.11 requires PyTorch 2.11)
RUN uv pip install --system torchcodec==0.10.0 --index-url=https://download.pytorch.org/whl/cu128

# Expose ports (8000 for API, 7860 for Gradio UI)
EXPOSE 8000 7860

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Run both API server and Gradio UI
CMD ["/app/start.sh"]
