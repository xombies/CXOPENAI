# AI Debate App (macOS + Ollama)

A macOS SwiftUI app that **packages the debate UI (`Homepage.html`) into a native app** via `WKWebView`, and talks to a local Ollama server.

- UI lives at `Sources/AIDebateApp/Resources/Homepage.html`
- The app starts a tiny in-app localhost server to serve the bundled HTML (avoids `file://` quirks)
- The app also proxies `/api/*` + `/health` to `http://localhost:11434` so the page can call Ollama same-origin (no separate CORS proxy needed)

## Requirements

- macOS 13.0 or later
- Ollama installed and running (`ollama serve`)
- A model pulled in Ollama (recommended: `gemma3:1b`)

## Quick Start

### 1. Start Ollama + pull a model

Option A (helper script):

```bash
./setup-ollama.sh
```

Option B (manual):

```bash
ollama serve
ollama pull gemma3:1b
```

### 2. Build + run (SwiftPM)

```bash
swift run
```

Optionally, open in Xcode:

```bash
open Package.swift
```

## Customization

- Update the UI: edit `LocalLLM/LLM BreadCrumbs/AIDebateApp/Sources/AIDebateApp/Resources/Homepage.html`
- (Optional) Keep using an external proxy: open Settings in the UI and set an endpoint like `http://localhost:3030` (default is blank = in-app proxy)

## Output contract (enforced)

- Removes `**` (no markdown)
- Normalizes replies into `- Outcome:` bullets and a final `- Question:` bullet
- Highlights terminal commands wrapped in backticks (SF Light), with all other output SF Thin

## Troubleshooting

- **Health shows Down / Ollama unreachable**: verify `ollama serve` is running and reachable at `http://localhost:11434`.
- **Model not found / slow**: run `ollama list`, install a small model (`gemma3:1b`), and set it in Settings (or leave Model blank for auto).
