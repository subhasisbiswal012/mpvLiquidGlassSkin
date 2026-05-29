// Record a slide range of deck.html to a 1920x1080 webm using Playwright.
//   node record.js <partName> <fromIdx> <toIdx>
// Reads audio/timings.json for per-slide durations; injects them as
// window.__TIMINGS before the deck script runs. Serves the repo over http
// so <video>/<img> assets and autoplay behave like a real page.
const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", ".."); // repo root
const MIME = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript",
  ".png": "image/png", ".jpg": "image/jpeg", ".mp4": "video/mp4", ".json": "application/json",
  ".woff2": "font/woff2", ".svg": "image/svg+xml" };

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split("?")[0]);
      let file = path.join(ROOT, p);
      if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.statusCode = 404; return res.end("404"); }
      res.setHeader("Content-Type", MIME[path.extname(file)] || "application/octet-stream");
      res.setHeader("Accept-Ranges", "bytes");
      fs.createReadStream(file).pipe(res);
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

(async () => {
  const [, , partName, fromStr, toStr] = process.argv;
  const from = parseInt(fromStr, 10), to = parseInt(toStr, 10);
  const timings = JSON.parse(fs.readFileSync(path.join(__dirname, "audio", "timings.json"), "utf-8"));
  const durs = timings.durations;
  const total = durs.slice(from, to + 1).reduce((a, b) => a + b, 0);
  const outDir = path.join(__dirname, "out");
  fs.mkdirSync(outDir, { recursive: true });

  const server = await serve();
  const port = server.address().port;
  const url = `http://127.0.0.1:${port}/Video/render/deck.html?auto=1&from=${from}&to=${to}`;

  const browser = await chromium.launch({
    args: ["--autoplay-policy=no-user-gesture-required", "--disable-gpu-vsync", "--force-color-profile=srgb"],
  });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
    recordVideo: { dir: outDir, size: { width: 1920, height: 1080 } },
  });
  const page = await context.newPage();
  await page.addInitScript((t) => { window.__TIMINGS = t; }, durs);
  await page.goto(url, { waitUntil: "load" });

  // wait for the deck to flag completion (+safety margin)
  const budgetMs = (total + 2.5) * 1000;
  await page.waitForFunction(() => window.__deckDone === true, null, { timeout: budgetMs + 5000 }).catch(() => {});
  await page.waitForTimeout(300);

  const video = page.video();
  await context.close(); // finalizes the webm
  await browser.close();
  server.close();

  const tmp = await video.path();
  const dest = path.join(outDir, `part_${partName}.webm`);
  fs.renameSync(tmp, dest);
  console.log(`${dest}\nslides ${from}..${to}  ~${total.toFixed(1)}s`);
})();
