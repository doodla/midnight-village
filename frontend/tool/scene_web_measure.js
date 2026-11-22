const { chromium } = require('playwright-core');

const url = process.argv[2];
const out = process.argv[3];

function stats(deltas) {
  const s = [...deltas].sort((a, b) => a - b);
  const q = (p) => s[Math.min(s.length - 1, Math.floor(p * s.length))];
  return {
    frames: deltas.length,
    median: +q(0.5).toFixed(1),
    p95: +q(0.95).toFixed(1),
    max: +s[s.length - 1].toFixed(1),
    over25: deltas.filter((d) => d > 25).length,
    dropped: deltas.filter((d) => d > 33.5).length,
  };
}

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME || '/usr/bin/google-chrome',
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const results = {};
  for (const rate of [1, 4]) {
    const ctx = await browser.newContext({
      viewport: { width: 390, height: 844 },
      deviceScaleFactor: 2,
      isMobile: true,
      hasTouch: true,
    });
    const page = await ctx.newPage();
    const cdp = await ctx.newCDPSession(page);
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForTimeout(6000);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate });
    await page.evaluate(() => {
      window.__rec = null;
      window.__start = (ms) =>
        new Promise((resolve) => {
          const t = [];
          const begin = performance.now();
          const tick = (now) => {
            t.push(now);
            if (now - begin < ms) requestAnimationFrame(tick);
            else resolve(t);
          };
          requestAnimationFrame(tick);
        });
    });
    const deltasOf = (t) => t.slice(1).map((v, i) => v - t[i]);
    const run = async (key, label) => {
      const all = [];
      for (let i = 0; i < 6; i++) {
        const p = page.evaluate(() => window.__start(900));
        await page.waitForTimeout(60);
        await page.keyboard.press(key);
        const t = await p;
        all.push(...deltasOf(t));
        await page.waitForTimeout(400);
        // Back to the start for the next one.
        await page.keyboard.press('r');
        await page.waitForTimeout(700);
        if (key === 'w') {
          await page.keyboard.press('d');
          await page.waitForTimeout(800);
          await page.keyboard.press('n');
          await page.waitForTimeout(500);
        }
      }
      results[`${label} x${rate}`] = stats(all);
    };
    // Idle: nothing moving, for the browser's own cadence.
    {
      const t = await page.evaluate(() => window.__start(1500));
      results[`idle x${rate}`] = stats(deltasOf(t));
    }
    await page.keyboard.press('r');
    await page.waitForTimeout(700);
    await run('n', 'crossfade (card to board, today)');
    await page.keyboard.press('r');
    await page.waitForTimeout(700);
    await run('d', 'dusk (table to card)');
    // The dawn starts on the board: get there first.
    await page.keyboard.press('d');
    await page.waitForTimeout(800);
    await page.keyboard.press('n');
    await page.waitForTimeout(500);
    await run('w', 'dawn (board to talk)');
    if (rate === 1) {
      // A look at the browser's own picture, mid-scene.
      await page.keyboard.press('r');
      await page.waitForTimeout(700);
      await page.keyboard.press('d');
      await page.waitForTimeout(800);
      await page.keyboard.press('n');
      await page.waitForTimeout(600);
      await page.keyboard.press('w');
      await page.waitForTimeout(120);
      await page.screenshot({ path: out + '-dawn-mid.png' });
    }
    await ctx.close();
  }
  console.log(JSON.stringify(results, null, 1));
  await browser.close();
})();
