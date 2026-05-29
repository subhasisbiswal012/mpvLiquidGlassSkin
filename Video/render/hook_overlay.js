// Capture slide 0's text + scrim as a transparent PNG (hook_overlay.png),
// so ffmpeg can lay it over the real Demo.mp4 footage.
const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..");
const MIME = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript",
  ".png": "image/png", ".mp4": "video/mp4", ".json": "application/json", ".woff2": "font/woff2" };

function serve() {
  return new Promise((resolve) => {
    const s = http.createServer((req, res) => {
      const p = decodeURIComponent(req.url.split("?")[0]);
      const f = path.join(ROOT, p);
      if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.statusCode = 404; return res.end(); }
      res.setHeader("Content-Type", MIME[path.extname(f)] || "application/octet-stream");
      fs.createReadStream(f).pipe(res);
    });
    s.listen(0, "127.0.0.1", () => resolve(s));
  });
}

(async () => {
  const server = await serve();
  const port = server.address().port;
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${port}/Video/render/deck.html?slide=0`, { waitUntil: "load" });
  // strip everything but scrim + text so the PNG has clean alpha
  await page.addStyleTag({ content: `
    html, body, #viewport, #stage { background: transparent !important; }
    .cover-video, .blob, #grain, .vignette { display: none !important; }
    #progress { display: none !important; }
  ` });
  await page.waitForTimeout(1500); // let entrance animation settle
  const stage = await page.$("#stage");
  await stage.screenshot({ path: path.join(__dirname, "out", "hook_overlay.png"), omitBackground: true });
  await browser.close();
  server.close();
  console.log("hook_overlay.png saved");
})();
