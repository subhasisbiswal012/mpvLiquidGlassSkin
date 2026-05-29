// Render the two install-recording placeholder cards to PNG.
const { chromium } = require("playwright");
const path = require("path");

const CARDS = [
  { out: "out/ph_mpv.png", badge: "▶ Step 1 · Insert your recording",
    title: 'Install <span class="grad">MPV</span>',
    sub: "Drop your “mpv installation guide” recording in here during editing." },
  { out: "out/ph_skin.png", badge: "▶ Step 2 · Insert your recording",
    title: 'Install the <span class="grad">Liquid&nbsp;Glass</span> skin',
    sub: "Drop your “install liquid glass skin” recording in here during editing." },
];

(async () => {
  const url = "file:///" + path.resolve(__dirname, "placeholder.html").replace(/\\/g, "/");
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  for (const c of CARDS) {
    await p.goto(url, { waitUntil: "load" });
    await p.evaluate(({ badge, title, sub }) => {
      document.getElementById("badge").textContent = badge;
      document.getElementById("title").innerHTML = title;
      document.getElementById("sub").textContent = sub;
    }, c);
    await p.waitForTimeout(500);
    await p.screenshot({ path: path.resolve(__dirname, c.out), clip: { x: 0, y: 0, width: 1920, height: 1080 } });
    console.log(c.out);
  }
  await b.close();
})();
