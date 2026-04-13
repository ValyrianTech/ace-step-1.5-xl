#!/bin/bash
# Start both ACE-Step API server and Gradio UI

echo "Starting ACE-Step services..."

# Model paths (pre-baked in Docker image)
CONFIG_PATH="${ACESTEP_CONFIG_PATH:-/app/checkpoints/acestep-v15-xl-base}"
LM_MODEL_PATH="${ACESTEP_LM_MODEL_PATH:-/app/checkpoints/acestep-5Hz-lm-1.7B}"

echo "Using DiT model: $CONFIG_PATH"
echo "Using LM model: $LM_MODEL_PATH"

# Start Gradio UI in background on port 7860 (with logging)
echo "Starting Gradio UI on port 7860..."
acestep --server-name 0.0.0.0 --port 7860 --init_service true --config_path "$CONFIG_PATH" --lm_model_path "$LM_MODEL_PATH" --backend pt 2>&1 | tee /app/outputs/gradio.log &
GRADIO_PID=$!
echo "Gradio UI started with PID $GRADIO_PID"

# Wait for Gradio to initialize before starting API server
sleep 10

# Start API server on port 8000 (with logging)
# API server reads config from environment variables: ACESTEP_CONFIG_PATH, ACESTEP_LM_MODEL_PATH
echo "Starting API server on port 8000..."
acestep-api --host 0.0.0.0 --port 8000 2>&1 | tee /app/outputs/api.log &
API_PID=$!
echo "API server started with PID $API_PID"

echo "All services started. Logs available at /app/outputs/"
echo "  - Gradio UI: /app/outputs/gradio.log"
echo "  - API Server: /app/outputs/api.log"

# Keep container running for RunPod web terminal
sleep infinity
