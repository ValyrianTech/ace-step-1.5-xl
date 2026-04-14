# ACE-Step 1.5 XL Docker Image

A Docker image for running ACE-Step 1.5 XL's built-in API server with models pre-baked.

**XL Model**: Uses the 4B-parameter DiT decoder for higher audio quality. Requires a GPU with **48GB+ VRAM**.

[![ValyrianTech](https://img.shields.io/badge/ValyrianTech-Links-blue)](https://linktr.ee/ValyrianTech) [![Patreon](https://img.shields.io/badge/Patreon-Support-orange)](http://patreon.com/ValyrianTech)

## Deploy on RunPod

The fastest way to get started is to deploy the pre-built image on RunPod:

[![Deploy on RunPod](https://img.shields.io/badge/RunPod-Deploy-blueviolet?logo=runpod)](https://console.runpod.io/deploy?template=5fn9cdbhtr&ref=2vdt3dn9)

This template includes all models pre-loaded and is ready to use immediately. Once deployed:
- **REST API**: `https://<POD_ID>-8000.proxy.runpod.net`

## Features

- **ACE-Step's built-in API server** with full feature set
- **Multi-stage Docker build** with XL models baked in (~20GB image)
- **GPU support** via NVIDIA CUDA 13 runtime
- **LLM-powered features**: lyrics/caption formatting

## Quick Start

### Prerequisites

- Docker with NVIDIA Container Toolkit
- NVIDIA GPU with CUDA support
- HuggingFace token (for downloading gated models during build)

### 1. Build the Docker Image

```bash
# Using the build script
python build_docker.py acestep-api-xl --hf-token YOUR_HF_TOKEN --latest

# Or manually
docker build --build-arg HF_TOKEN=YOUR_HF_TOKEN -t acestep-api-xl:latest .
```

### 2. Run with Docker Compose

```bash
docker compose up -d
```

The API will be available at `http://localhost:8000`.

## CLI Tool (Recommended)

The easiest way to generate music is using the included Python CLI script:

```bash
python generate_music.py \
  --api-url http://localhost:8000 \
  --caption "Upbeat indie pop with jangly guitars and energetic vocals" \
  --lyrics "[Verse 1]\nWalking down the street\nMusic in my feet\n\n[Chorus]\nWe are alive tonight" \
  --duration 90 \
  --output my_song.mp3
```

The CLI handles task submission, polling, and file download automatically. See `python generate_music.py --help` for all options, or check the [API Usage Guide](docs/API_USAGE.md) for detailed examples.

## API Endpoints

See the [ACE-Step API documentation](https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/API.md) for full details.

### Core Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/v1/models` | GET | List available models |
| `/release_task` | POST | Create music generation task |
| `/query_result` | POST | Batch query task results |
| `/format_input` | POST | Format and enhance lyrics/caption via LLM |
| `/v1/audio` | GET | Download audio file |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ACESTEP_CONFIG_PATH` | `/app/checkpoints/acestep-v15-xl-base` | Full path to XL DiT model |
| `ACESTEP_LM_MODEL_PATH` | `/app/checkpoints/acestep-5Hz-lm-1.7B` | Full path to LM model |
| `ACESTEP_OUTPUT_DIR` | `/app/outputs` | Generated audio output directory |
| `ACESTEP_DEVICE` | `cuda` | Device (cuda, cpu, mps) |
| `ACESTEP_LM_BACKEND` | `pt` | LLM backend (vllm, pt) |
| `ACESTEP_API_HOST` | `0.0.0.0` | Server host |
| `ACESTEP_API_PORT` | `8000` | Server port |

## License

See the [ACE-Step 1.5 repository](https://github.com/ace-step/ACE-Step-1.5) for license information.
