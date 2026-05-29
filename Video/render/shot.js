// Screenshot a local file:// page at 1920x1080.  node shot.js <relpath?query> <out.png>
const { chromium } = require("playwright");
const path = require("path");
(async () => {
  const [, , rel, out] = process.argv;
  const url = "file:///" + path.resolve(__dirname, rel).replace(/\\/g, "/");
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await p.goto(url, { waitUntil: "load" });
  await p.waitForTimeout(700);
  await p.screenshot({ path: path.resolve(__dirname, out), clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  await b.close();
  console.log(out);
})();
