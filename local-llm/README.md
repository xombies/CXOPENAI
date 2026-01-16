# LocalLLM (AgentC vs AgentX)

This folder contains:
- `site/Homepage.html`: the local debate UI (served at `http://localhost:8000/Homepage.html`)
- `scripts/ollama_proxy.py`: a tiny CORS proxy (runs on `http://localhost:3030`)
- `macos/AIDebateApp`: a Swift macOS wrapper app (WKWebView + in-app localhost server + Ollama proxy)

## Run locally (Web)
1) Start Ollama:
   - `ollama serve`
2) Start the proxy (CORS-safe for the browser):
   - `python3 ./local-llm/scripts/ollama_proxy.py`
3) Serve the site:
   - `python3 -m http.server 8000 --directory ./local-llm/site`
4) Open:
   - `http://localhost:8000/Homepage.html`

## Run locally (macOS app)
Open `local-llm/macos/AIDebateApp/Package.swift` in Xcode and run, or:
- `cd local-llm/macos/AIDebateApp && swift run`

The macOS app serves `Homepage.html` from an in-app localhost server and proxies Ollama same-origin, so it does not require the Python proxy.

## Vercel
`apps/web/public/Homepage.html` is a copy of `local-llm/site/Homepage.html` so it’s accessible at `https://<your-domain>/Homepage.html` after deploy.
