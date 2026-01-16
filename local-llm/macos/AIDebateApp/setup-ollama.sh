#!/bin/bash
set -euo pipefail

echo "Setting up AI Debate App with Ollama (Gemma recommended)"
echo ""

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama is not installed."
  echo "Install from https://ollama.com/ and re-run this script."
  exit 1
fi

echo "Checking for a small Gemma model (recommended: gemma3:1b)…"

if ollama list | grep -q "gemma3:1b"; then
  echo "Found gemma3:1b"
else
  echo "gemma3:1b not found."
  read -r -p "Download gemma3:1b now? (y/n): " choice
  if [[ "${choice}" == "y" ]]; then
    ollama pull gemma3:1b
  else
    echo "Skipping download. You can run: ollama pull gemma3:1b"
  fi
fi

echo ""
echo "Starting Ollama server (if not already running)…"
if curl -fsS --max-time 1 "http://localhost:11434/api/version" >/dev/null 2>&1; then
  echo "Ollama already running on http://localhost:11434"
else
  ollama serve >/dev/null 2>&1 &
  sleep 2
fi

echo ""
echo "Setup complete."
echo "Run the app with:"
echo "  swift run"
echo ""
echo "If you have a custom model (e.g. mk-x-gemma:1b), set it in Settings."
