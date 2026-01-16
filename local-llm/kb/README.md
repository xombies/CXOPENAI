## Local Knowledge Packs (optional)

Drop large, local-only files here (e.g. `1 GB.json`) when you want the app to reference external data during development.

- This folder is intentionally **not** versioned for large assets.
- `1 GB.json` is ~1GB and should not be committed to GitHub or shipped to Vercel.

If you want the LLM to actually use this data, we need one of:
- **RAG** (search/snippet injection) from the UI/server, or
- a real **fine-tune** pipeline outside the app (Ollama won’t “tune” just by placing a JSON file).

Tell me what the JSON schema represents and how you want it used (searchable facts vs writing-style examples), and I’ll wire it in cleanly.

