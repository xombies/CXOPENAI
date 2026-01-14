# CXOPENAI

Monorepo containing:

- `apps/web`: React Router (SSR) web app
- `apps/mobile`: Expo / React Native app

## Web

```bash
cd apps/web
npm install
npm run dev
```

Build + run locally:

```bash
cd apps/web
npm run build
npm run start
```

## Deploy (Vercel)

- Import the repo in Vercel.
- Set the project **Root Directory** to `apps/web`.
- Configure any required env vars (search for `process.env.*` usage in `apps/web`).

## License

MIT License

Copyright (c) 2026 xombies

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
