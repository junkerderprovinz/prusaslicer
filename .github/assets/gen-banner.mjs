/**
 * Generates the PrusaSlicer README banners (theme-adaptive pair, 1600x500):
 *   prusaslicer-banner.svg / .png      : white bg, dark-grey + orange "S" mark,
 *                                        "PrusaSlicer" in dark, grey claim
 *   prusaslicer-banner-dark.svg / .png : GitHub-dark #0d1117, the grey half of the
 *                                        mark lightened, name light, claim lighter grey
 * The README serves the pair via <picture> (prefers-color-scheme).
 *
 * House banner standard: the mark (icon.svg - the two-tone Prusa "S") is
 * left-anchored at x=165, 300px tall; the "PrusaSlicer" wordmark sits to its
 * right in Archivo Black (heavy grotesque, OFL), foreground colour; the cheeky
 * claim in Lato (OFL) grey, left-aligned with the wordmark and pulled close.
 * Name + claim are rendered to VECTOR PATHS (opentype.js) so the SVG needs no
 * font. On the dark banner the mark's #363636 half is lightened so it reads on
 * #0d1117 (the orange half and geometry are untouched); the white backing circle
 * is dropped (it would show as a white disc on the dark ground).
 *
 * Deps: `npm i -g @resvg/resvg-js opentype.js`. Fonts (OFL) are fetched at
 * runtime to the OS temp dir - NEVER committed. Run:
 *   node .github/assets/gen-banner.mjs
 */
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { createRequire } from "node:module";
import { execSync } from "node:child_process";

const require = createRequire(import.meta.url);
const gRoot = execSync("npm root -g").toString().trim();
const opentype = require(`${gRoot}/opentype.js`);
const { Resvg } = require(`${gRoot}/@resvg/resvg-js`);
const __dir = dirname(fileURLToPath(import.meta.url));

// ---- content + styling -----------------------------------------------------
const NAME = "PrusaSlicer";
const CLAIM = "Have your model and slice it too.";
const W = 1600, H = 500;
const LH = 563;                     // mark height (house standard) - square viewBox
const startX = 165;                 // left-anchor (house standard)
const gap = 70;                     // mark-to-wordmark gap
let nameSize = 132;                 // auto-fit down if the wordmark is too wide
const claimSize = 44, lineGap = 8;  // name -> claim gap
const THEMES = [
  { suffix: "",      bg: "#ffffff", name: "#1f2328", claim: "#5a5d5e", markGrey: "#363636", circle: true  },
  { suffix: "-dark", bg: "#0d1117", name: "#e6edf3", claim: "#9aa4ad", markGrey: "#c9d1d9", circle: false },
];
// ---------------------------------------------------------------------------

// Fonts (OFL): Archivo Black for the wordmark, Lato for the claim - fetched, never committed.
// Verify Content-Length so a truncated download can't silently break glyph outlines
// (a short file still parses, but the tail glyphs render broken).
async function font(url, file) {
  const p = join(tmpdir(), file);
  if (!existsSync(p) || readFileSync(p).length < 50000) {
    for (let attempt = 1; ; attempt++) {
      const r = await fetch(url);
      if (!r.ok) throw new Error(`font fetch ${r.status}: ${url}`);
      const buf = Buffer.from(await r.arrayBuffer());
      const len = Number(r.headers.get("content-length") || 0);
      if (len && buf.length !== len) {
        if (attempt >= 3) throw new Error(`font truncated ${buf.length}/${len}: ${url}`);
        continue;
      }
      writeFileSync(p, buf);
      break;
    }
  }
  const b = readFileSync(p);
  return opentype.parse(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
}
const archivo = await font("https://github.com/google/fonts/raw/main/ofl/archivoblack/ArchivoBlack-Regular.ttf", "prusa-ArchivoBlack.ttf");
const lato = await font("https://github.com/google/fonts/raw/main/ofl/lato/Lato-Regular.ttf", "prusa-Lato-Regular.ttf");

// The mark (icon.svg): white circle + #363636 half + #ed6b21 half, viewBox 0 0 800 800.
const iconRaw = readFileSync(join(__dir, "icon.svg"), "utf8");
const iconInner = iconRaw.replace(/^[\s\S]*?<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "");

// Left-anchor by the VISIBLE ink (the two "S" halves), not the box: the S sits inset
// inside its 800x800 circle viewBox, so anchoring the box at x=165 would leave a big
// left gap. Measure the halves' ink bbox and offset so the ink's left edge -> 165 and
// its vertical centre -> H/2.
//
// The same measurement decides where the wordmark starts. Deriving that from the box
// (startX + LH + gap) put the text at x=798 while the mark's ink ended at 497: a
// 301px gulf instead of the 70 this file asks for, which is what "the text sits too
// far right" looked like. The ink is 472 of the viewBox's 800 units wide, so the box
// overstates the mark by 40%.
const halves = iconInner.replace(/<circle[^>]*\/>\s*/, "");
const inkBB = new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800">${halves}</svg>`, { fitTo: { mode: "original" } }).innerBBox();
const k = LH / 800;
const markX = startX - inkBB.x * k;
const markY = H / 2 - (inkBB.y + inkBB.height / 2) * k;
const markRight = startX + inkBB.width * k;

// Auto-fit the wordmark to the free width, then place the [wordmark + claim] block.
const textX = markRight + gap;
const maxNameW = W - textX - 90;
if (archivo.getAdvanceWidth(NAME, nameSize) > maxNameW)
  nameSize *= maxNameW / archivo.getAdvanceWidth(NAME, nameSize);
const em = (f, s) => s / f.unitsPerEm;
const nameAsc = archivo.ascender * em(archivo, nameSize);
const nameDesc = -archivo.descender * em(archivo, nameSize);
const claimAsc = lato.ascender * em(lato, claimSize);
const claimDesc = -lato.descender * em(lato, claimSize);
const blockH = nameAsc + nameDesc + lineGap + claimAsc + claimDesc;
const top = (H - blockH) / 2;
const nameBaseline = top + nameAsc;
const claimBaseline = nameBaseline + nameDesc + lineGap + claimAsc;
// Render text as ONE <path> PER GLYPH, not a single merged path: resvg's tessellator
// can silently abort a merged multi-subpath path partway through for certain
// glyph/coordinate combinations, and per-glyph paths sidestep that entirely.
// Colour is applied per theme, so only the geometry (d) is precomputed.
const glyphD = (font, text, x, baseline, size) =>
  font.getPaths(text, x, baseline, size).map((p) => p.toPathData(2)).filter(Boolean);
const nameD = glyphD(archivo, NAME, textX, nameBaseline, nameSize);
const claimD = glyphD(lato, CLAIM, textX, claimBaseline, claimSize);
const paths = (ds, fill) => ds.map((d) => `<path d="${d}" fill="${fill}"/>`).join("");

for (const t of THEMES) {
  let inner = iconInner;
  if (!t.circle) inner = inner.replace(/<circle[^>]*\/>\s*/, "");     // drop the white backing disc
  inner = inner.replace(/#363636/gi, t.markGrey);                     // lighten the grey half on dark
  const mark = `<svg x="${markX.toFixed(2)}" y="${markY.toFixed(2)}" width="${LH}" height="${LH}" viewBox="0 0 800 800" xmlns="http://www.w3.org/2000/svg">${inner}</svg>`;

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="${NAME}">
  <rect width="${W}" height="${H}" fill="${t.bg}"/>
  ${mark}
  ${paths(nameD, t.name)}
  ${paths(claimD, t.claim)}
</svg>
`;
  writeFileSync(join(__dir, `prusaslicer-banner${t.suffix}.svg`), svg);
  const png = new Resvg(svg, { fitTo: { mode: "width", value: W }, background: t.bg }).render().asPng();
  writeFileSync(join(__dir, `prusaslicer-banner${t.suffix}.png`), png);
  console.log(`wrote prusaslicer-banner${t.suffix}.svg + .png (name ${Math.round(nameSize)}px)`);
}
console.log(`claim: "${CLAIM}"`);
