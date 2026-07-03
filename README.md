Cards
=====

Two Cubes – the web puzzle game. Fully static, no backend: all state lives in
the browser (localStorage).

Run it with any static file server from the repo root, e.g.:

`python3 -m http.server 8080`

or

`docker-compose up`

then open http://localhost:8080

Tests
-----

Playwright behavior tests (they spawn a local server automatically):

```
npm install
npx playwright install chromium
npm test                # against a local server
npm run test:prod       # against the production deploy (twocubes.io)
```

Deploy
------

Hosted on Cloudflare Pages: https://twocubes.pages.dev

`npm run deploy` stages the game files into `dist/` and publishes them with
wrangler (requires `wrangler login`).
