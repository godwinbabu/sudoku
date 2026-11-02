/* @ds-bundle: {"format":4,"namespace":"PureSudokuDesignSystem_019def","components":[{"name":"Board","sourcePath":"components/Board/Board.jsx"},{"name":"HintCard","sourcePath":"components/HintCard/HintCard.jsx"},{"name":"Keypad","sourcePath":"components/Keypad/Keypad.jsx"}],"sourceHashes":{"assets/app-icon/icon-options.js":"3e30818c993c","assets/app-icon/icon.js":"011e6b4d22b9","components/Board/Board.jsx":"caf5e22e5e62","components/HintCard/HintCard.jsx":"d25d75e93283","components/Keypad/Keypad.jsx":"14bcf0cbd2c7","ui_kits/puresudoku-2/Display.jsx":"0388f0c0fd1b","ui_kits/puresudoku-2/GameScreen.jsx":"62c3d926ef65","ui_kits/puresudoku-2/Import.jsx":"3f9a8fcacbb3","ui_kits/puresudoku-2/Learn.jsx":"34e7d0ffcbf6","ui_kits/puresudoku-2/NightSheet.jsx":"91e995b8109a","ui_kits/puresudoku-2/Primitives.jsx":"e134ee4a38ce","ui_kits/puresudoku-2/Screens.jsx":"cacc593e33fd","ui_kits/puresudoku-2/engine.js":"285dacd8a873","ui_kits/puresudoku-2/night.js":"8bea4c1ce72d"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.PureSudokuDesignSystem_019def = window.PureSudokuDesignSystem_019def || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// assets/app-icon/icon-options.js
try { (() => {
// Five alternative app-icon concepts. window.PSIconAlt(key, px) → SVG string.
(function () {
  let n = 0;
  const SERIF = `'New York','Newsreader',ui-serif,Georgia,serif`;
  const wrap = (px, id, defs, body, bg = '#000') => `<svg xmlns="http://www.w3.org/2000/svg" width="${px}" height="${px}" viewBox="0 0 1024 1024"><defs>${defs}<clipPath id="${id}m"><rect width="1024" height="1024" rx="229"/></clipPath></defs><g clip-path="url(#${id}m)"><rect width="1024" height="1024" fill="${bg}"/>${body}</g></svg>`;
  const warm = id => `<linearGradient id="${id}w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFD495"/><stop offset="1" stop-color="#E9832B"/></linearGradient>`;
  const glow = (id, a = 0.4) => `<radialGradient id="${id}g"><stop offset="0" stop-color="rgba(240,138,46,${a})"/><stop offset="1" stop-color="rgba(240,138,46,0)"/></radialGradient>`;
  const ICONS = {
    moon(px) {
      const id = 'pa' + n++;
      return wrap(px, id, warm(id) + glow(id, 0.22) + `<mask id="${id}c"><rect width="1024" height="1024" fill="#000"/><circle cx="500" cy="520" r="300" fill="#fff"/><circle cx="640" cy="430" r="268" fill="#000"/></mask>`, `<circle cx="470" cy="560" r="420" fill="url(#${id}g)"/>
<g stroke="#3B230C" stroke-width="10" stroke-linecap="round"><path d="M398 180V860M626 180V860M170 408H850M170 636H850"/></g>
<rect width="1024" height="1024" fill="url(#${id}w)" mask="url(#${id}c)"/>`);
    },
    lastcell(px) {
      const id = 'pa' + n++,
        o = 150,
        s = 226,
        g = 22;
      let t = '';
      const digits = [3, 8, 1, 6, 4, 9, 2, 5, 0];
      for (let k = 0; k < 9; k++) {
        const x = o + k % 3 * (s + g),
          y = o + Math.floor(k / 3) * (s + g);
        if (k === 8) t += `<rect x="${x - 40}" y="${y - 40}" width="${s + 80}" height="${s + 80}" rx="70" fill="url(#${id}g)"/><rect x="${x}" y="${y}" width="${s}" height="${s}" rx="34" fill="url(#${id}w)"/>`;else t += `<rect x="${x}" y="${y}" width="${s}" height="${s}" rx="34" fill="#140C05"/><text x="${x + s / 2}" y="${y + s / 2}" dy=".35em" text-anchor="middle" font-family="${SERIF}" font-size="128" font-weight="500" fill="#5E3A16">${digits[k]}</text>`;
      }
      return wrap(px, id, warm(id) + glow(id, 0.55), t);
    },
    numeral(px) {
      const id = 'pa' + n++;
      return wrap(px, id, warm(id) + glow(id, 0.3), `<circle cx="600" cy="640" r="520" fill="url(#${id}g)"/>
<g stroke="#2E1B0A" stroke-width="8"><path d="M341 0V1024M683 0V1024M0 341H1024M0 683H1024"/></g>
<text x="590" y="1010" text-anchor="middle" font-family="${SERIF}" font-size="1040" font-weight="500" fill="url(#${id}w)">9</text>`);
    },
    ember(px) {
      const id = 'pa' + n++;
      let d = '';
      for (let k = 0; k < 9; k++) {
        if (k === 4) continue;
        d += `<circle cx="${282 + k % 3 * 230}" cy="${282 + Math.floor(k / 3) * 230}" r="30" fill="#5A3614"/>`;
      }
      return wrap(px, id, `<radialGradient id="${id}c"><stop offset="0" stop-color="#FFF1D6"/><stop offset=".35" stop-color="#FFC06A"/><stop offset=".75" stop-color="#EE8530"/><stop offset="1" stop-color="#C9601A"/></radialGradient>` + glow(id, 0.5), `<circle cx="512" cy="512" r="330" fill="url(#${id}g)"/>${d}<circle cx="512" cy="512" r="112" fill="url(#${id}c)"/>`, '#050302');
    },
    window(px) {
      const id = 'pa' + n++,
        x = 252,
        s = 520,
        p = s / 3;
      return wrap(px, id, warm(id) + glow(id, 0.45) + `<linearGradient id="${id}s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0C0906"/><stop offset="1" stop-color="#000"/></linearGradient>`, `<rect width="1024" height="1024" fill="url(#${id}s)"/>
<path d="M214 196a54 54 0 1 0 50 74a44 44 0 1 1 -50 -74Z" fill="#B9753A" opacity=".75"/>
<circle cx="${x + p * 2.5}" cy="${x + p * 0.5}" r="300" fill="url(#${id}g)"/>
<rect x="${x}" y="${x}" width="${s}" height="${s}" rx="10" fill="#080604"/>
<rect x="${x + p * 2}" y="${x}" width="${p}" height="${p}" fill="url(#${id}w)"/>
<g stroke="#2C1C0D" stroke-width="18"><rect x="${x}" y="${x}" width="${s}" height="${s}" rx="10" fill="none" stroke-width="26"/><path d="M${x + p} ${x}V${x + s}M${x + 2 * p} ${x}V${x + s}M${x} ${x + p}H${x + s}M${x} ${x + 2 * p}H${x + s}"/></g>
<rect x="${x - 40}" y="${x + s + 6}" width="${s + 80}" height="22" rx="11" fill="#2C1C0D"/>`, '#000');
    }
  };
  // Learning-led concepts
  Object.assign(ICONS, {
    xwing(px) {
      const id = 'pa' + n++,
        c = [300, 724];
      let t = `<g stroke="#2E1C0B" stroke-width="8"><path d="M371 120V904M653 120V904M120 371H904M120 653H904"/></g>`;
      t += `<g stroke="#F0A34B" stroke-width="10" stroke-linecap="round" opacity=".55"><path d="M${c[0]} ${c[0]}L${c[1]} ${c[1]}M${c[1]} ${c[0]}L${c[0]} ${c[1]}"/></g>`;
      t += `<g stroke="#8A5520" stroke-width="6" stroke-dasharray="4 18" stroke-linecap="round"><path d="M${c[0]} ${c[0]}H${c[1]}M${c[0]} ${c[1]}H${c[1]}M${c[0]} ${c[0]}V${c[1]}M${c[1]} ${c[0]}V${c[1]}"/></g>`;
      c.forEach(x => c.forEach(y => {
        t += `<circle cx="${x}" cy="${y}" r="120" fill="url(#${id}g)"/><circle cx="${x}" cy="${y}" r="62" fill="url(#${id}w)"/>`;
      }));
      return wrap(px, id, warm(id) + glow(id, 0.4), t);
    },
    resolve(px) {
      const id = 'pa' + n++;
      const pos = d => [212 + (d - 1) % 3 * 300, 212 + Math.floor((d - 1) / 3) * 300];
      let t = `<rect x="92" y="92" width="840" height="840" rx="60" fill="none" stroke="#2E1C0B" stroke-width="10"/>`;
      [1, 3, 7, 9].forEach(d => {
        const [x, y] = pos(d);
        t += `<text x="${x}" y="${y}" dy=".35em" text-anchor="middle" font-family="${SERIF}" font-size="150" font-weight="500" fill="#4F3112">${d}</text><path d="M${x - 70} ${y + 70}L${x + 70} ${y - 70}" stroke="#7A2E1E" stroke-width="12" stroke-linecap="round"/>`;
      });
      t += `<circle cx="512" cy="512" r="330" fill="url(#${id}g)"/><text x="512" y="512" dy=".35em" text-anchor="middle" font-family="${SERIF}" font-size="430" font-weight="500" fill="url(#${id}w)">5</text>`;
      return wrap(px, id, warm(id) + glow(id, 0.38), t);
    },
    hintring(px) {
      return window.PSIcon('dark', px);
    },
    ladder(px) {
      const id = 'pa' + n++;
      let t = '';
      [0, 1, 2, 3, 4].forEach(i => {
        const h = 150 + i * 120,
          x = 190 + i * 140;
        t += `<rect x="${x}" y="${860 - h}" width="92" height="${h}" rx="22" fill="${i === 4 ? `url(#${id}w)` : ['#2A190A', '#3A230D', '#4F3112', '#6E4419'][i]}"/>`;
      });
      t = `<circle cx="796" cy="300" r="300" fill="url(#${id}g)"/>` + t;
      t += `<g fill="#B9753A">${[[286, 640], [426, 520], [566, 400]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="12"/>`).join('')}</g>`;
      return wrap(px, id, warm(id) + glow(id, 0.42), t);
    },
    book(px) {
      const id = 'pa' + n++;
      const page = (x0, lit) => {
        let s = `<path d="M${x0} 300Q${x0 + 170} 270 ${x0 + 340} 300V760Q${x0 + 170} 730 ${x0} 760Z" fill="#120B05" stroke="#3A230D" stroke-width="8"/>`;
        for (let k = 0; k < 9; k++) {
          const x = x0 + 50 + k % 3 * 82,
            y = 360 + Math.floor(k / 3) * 112;
          s += k === lit ? `<rect x="${x}" y="${y}" width="74" height="96" rx="12" fill="url(#${id}w)"/>` : `<rect x="${x}" y="${y}" width="74" height="96" rx="12" fill="#21150A"/>`;
        }
        return s;
      };
      return wrap(px, id, warm(id) + glow(id, 0.38), `<circle cx="512" cy="520" r="420" fill="url(#${id}g)"/>${page(160, -1)}${page(524, 4)}<path d="M512 290V780" stroke="#5A3614" stroke-width="10" stroke-linecap="round"/>`);
    }
  });
  ICONS.current = null;
  window.PSIconAlt = (k, px = 1024) => ICONS[k](px);
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "assets/app-icon/icon-options.js", error: String((e && e.message) || e) }); }

// assets/app-icon/icon.js
try { (() => {
// PureSudoku app icon — "The hint" (option 2c).
// Proof cells in solid rings, the answer in a dashed ring: the app's own teaching marks.
// window.PSIcon(variant, px) → SVG string. variant: 'dark' | 'light' | 'tinted'.
(function () {
  // Digit outlines: Newsreader Medium (OFL), centred on their bounding box at 1000 units. No live text.
  const GLYPHS = {
    "1": "M-166.3 314.5L-21.8 286L-21.8-233.5L-208.3-178L-219.8-211.5L39.8-342L83.3-342L83.3 286L219.8 314.5L219.8 342L-166.3 342L-166.3 314.5Z",
    "2": "M-111.3 238.3L141.3 238.3L213.8 130.3L242.3 130.3L206.3 352.3L186.8 352.3L132.8 334.8L-229.8 334.8L-229.8 310.8L-39.8 93.8Q8.3 39.8 35.3-1.5Q62.3-42.8 73.5-75.8Q84.8-108.8 84.8-138.3L84.8-138.3Q84.8-196.8 51.8-231Q18.8-265.3-38.3-265.3L-38.3-265.3Q-76.3-265.3-108.3-252.3Q-140.3-239.3-164.3-208.5Q-188.3-177.8-202.3-124.8L-202.3-124.8L-242.3-132.3Q-219.3-241.8-155.8-297Q-92.3-352.3 1.3-352.3L1.3-352.3Q58.8-352.3 102.3-329.5Q145.8-306.8 170.3-265.8Q194.8-224.8 194.8-168.8L194.8-168.8Q194.8-137.3 186.8-107.8Q178.8-78.3 159-46.3Q139.3-14.3 103.8 25.3Q68.3 64.8 13.3 116.3L13.3 116.3L-111.3 238.3Z",
    "3": "M-55.8 11L-93.3 20.5L-105.3-23Q-34.3-43 5-66Q44.3-89 60.3-116.5Q76.3-144 76.3-176.5L76.3-176.5Q76.3-218 50.8-246Q25.3-274-24.8-274L-24.8-274Q-78.3-274-115-245Q-151.8-216-168.8-149.5L-168.8-149.5L-208.8-159Q-195.8-220-167.3-262.3Q-138.8-304.5-95.3-326.8Q-51.8-349 4.8-349L4.8-349Q59.8-349 97-331.3Q134.3-313.5 153.3-282Q172.3-250.5 172.3-209.5L172.3-209.5Q172.3-170.5 153-137.8Q133.8-105 97.3-80.5L97.3-80.5Q67.3-60.5 27.8-47L27.8-47Q85.8-50.5 128.3-34.5L128.3-34.5Q175.3-16 200.3 22.8Q225.3 61.5 225.3 117.5L225.3 117.5Q225.3 182.5 186.3 234.8Q147.3 287 76.8 318Q6.3 349-88.3 349L-88.3 349Q-137.8 349-168 339.8Q-198.3 330.5-211.8 314.5Q-225.3 298.5-225.3 279L-225.3 279Q-225.3 257.5-211 243.8Q-196.8 230-175.3 230L-175.3 230Q-163.3 230-151.3 237Q-139.3 244-126.3 254.3Q-113.3 264.5-98.8 274.8Q-84.3 285-67.5 292Q-50.8 299-30.8 299L-30.8 299Q9.8 299 44.3 280.3Q78.8 261.5 99.8 224.8Q120.8 188 120.8 134.5L120.8 134.5Q120.8 83.5 99.3 51.5Q77.8 19.5 38 8.8Q-1.8-2-55.8 11L-55.8 11Z",
    "5": "M-100 353.3L-100 353.3Q-149.5 353.3-179.3 343.5Q-209 333.8-222.3 317.8Q-235.5 301.8-235.5 283.3L-235.5 283.3Q-235.5 259.8-220.8 246Q-206 232.3-187 232.3L-187 232.3Q-175.5 232.3-163.5 239.3Q-151.5 246.3-138.8 256Q-126 265.8-111.8 276Q-97.5 286.3-81.3 293Q-65 299.8-45.5 299.8L-45.5 299.8Q-1.5 299.8 35 281.8Q71.5 263.8 93.5 228.8Q115.5 193.8 115.5 142.8L115.5 142.8Q115.5 111.3 103.3 83.5Q91 55.8 59.3 33.8Q27.5 11.8-31-2.3Q-89.5-16.3-182.5-20.3L-182.5-20.3L-95-333.8L102-333.8L235.5-353.3L199.5-238.3L-66-238.3L-106-115.3Q-42.5-109.3 5.5-97.3L5.5-97.3Q63-82.8 101-61.8Q139-40.8 161-14Q183 12.8 192.3 44Q201.5 75.3 201.5 110.3L201.5 110.3Q201.5 163.3 179.5 207.8Q157.5 252.3 117.3 284.8Q77 317.3 21.8 335.3Q-33.5 353.3-100 353.3Z",
    "6": "M164.8-355.5L164.8-355.5L186.3-319Q116.8-297 64.5-269.8Q12.3-242.5-24.8-208.8Q-61.8-175-85-133.3Q-108.3-91.5-119.3-40.5L-119.3-40.5Q-126.3-8-128.3 29.5L-128.3 29.5Q-117.8 20-107.8 12L-107.8 12Q-77.8-13-51.3-27.5Q-24.8-42 1-48.5Q26.8-55 54.3-55L54.3-55Q106.8-55 147.8-33.8Q188.8-12.5 212.5 28.5Q236.3 69.5 236.3 130L236.3 130Q236.3 196.5 206.8 247.3Q177.3 298 125 326.8Q72.8 355.5 3.3 355.5L3.3 355.5Q-74.8 355.5-128.3 319Q-181.8 282.5-209 220Q-236.3 157.5-236.3 80L-236.3 80Q-236.3 22.5-224.3-30Q-212.3-82.5-184.5-129.3Q-156.8-176-110.5-216.8Q-64.3-257.5 3.8-292.5Q71.8-327.5 164.8-355.5ZM-129.8 66.5L-129.8 66.5Q-129.8 69.5-129.8 72.5L-129.8 72.5Q-129.8 143.5-114.8 195.8Q-99.8 248-69.3 276.3Q-38.8 304.5 7.8 304.5L7.8 304.5Q49.3 304.5 77.8 287Q106.3 269.5 121 236.8Q135.8 204 135.8 158L135.8 158Q135.8 86.5 105 49.8Q74.3 13 15.3 13L15.3 13Q-7.3 13-29.3 17.5Q-51.3 22-72.3 30.8Q-93.3 39.5-111.8 52.5L-111.8 52.5Q-121.3 59-129.8 66.5Z",
    "7": "M158.8-233.3L-152.8-233.3L-209.3-127.8L-237.8-127.8L-223.8-346.8L-206.8-346.8L-148.3-329.3L237.8-329.3L237.8-318.3L-4.8 346.8L-120.3 346.8L158.8-233.3Z",
    "8": "M10.3-349L10.3-349Q73.3-349 117.5-329.3Q161.8-309.5 185.3-274Q208.8-238.5 208.8-191.5L208.8-191.5Q208.8-130.5 161.3-88L161.3-88Q129.3-59.5 78.8-41.5L78.8-41.5Q87.8-38 96.8-34.5L96.8-34.5Q135.3-19 167 3.8Q198.8 26.5 218.3 62.8Q237.8 99 237.8 154L237.8 154Q237.8 215 205.5 258.8Q173.3 302.5 119.3 325.8Q65.3 349-0.8 349L-0.8 349Q-69.3 349-123 328.8Q-176.8 308.5-207.3 270Q-237.8 231.5-237.8 176.5L-237.8 176.5Q-237.8 136-221.8 105Q-205.8 74-177.5 51Q-149.3 28-111.3 11L-111.3 11Q-101.3 7-91.3 3L-91.3 3Q-116.8-9-139.3-24.5L-139.3-24.5Q-171.3-46.5-190.5-81Q-209.8-115.5-209.8-167.5L-209.8-167.5Q-209.8-221-182.5-261.8Q-155.3-302.5-105.8-325.8Q-56.3-349 10.3-349ZM-52.3 19.5L-52.3 19.5Q-73.8 30.5-89.3 42.5L-89.3 42.5Q-118.3 65.5-131.3 96.3Q-144.3 127-144.3 169L-144.3 169Q-144.3 210-126.8 239Q-109.3 268-76.5 283.5Q-43.8 299 1.3 299L1.3 299Q48.3 299 80.5 283.5Q112.8 268 129.5 240.8Q146.3 213.5 146.3 178L146.3 178Q146.3 138.5 127 113.3Q107.8 88 76 71.3Q44.3 54.5 6.3 41L6.3 41Q-22.8 31-52.3 19.5ZM91.8-98L91.8-98Q122.3-131.5 122.3-184L122.3-184Q122.3-217.5 108.8-243.3Q95.3-269 68.8-284Q42.3-299 2.8-299L2.8-299Q-55.8-299-88.3-269Q-120.8-239-120.8-195L-120.8-195Q-120.8-156-101.3-131.8Q-81.8-107.5-50-91.5Q-18.3-75.5 20.3-62.5L20.3-62.5Q28.3-60 35.8-57L35.8-57Q70.8-75 91.8-98Z"
  };
  const V = {
    dark: {
      bg0: '#120A03',
      bg1: '#000',
      line: '#2E1C0B',
      ink: '#5E3A16',
      ring: '#C77A33',
      proof: '#E9A060',
      a0: '#FFD495',
      a1: '#E9832B',
      glow: [240, 138, 46, 0.4]
    },
    light: {
      bg0: '#FBF8F1',
      bg1: '#EAE2D1',
      line: '#D3C6AE',
      ink: '#A8997F',
      ring: '#B9772F',
      proof: '#9A5712',
      a0: '#B86C1E',
      a1: '#8A4A0C',
      glow: [214, 150, 70, 0.22]
    },
    tinted: {
      bg0: '#141414',
      bg1: '#000',
      line: '#333',
      ink: '#555',
      ring: '#9A9A9A',
      proof: '#BDBDBD',
      a0: '#FFFFFF',
      a1: '#D2D2D2',
      glow: [255, 255, 255, 0.14]
    }
  };
  // Dashed rounded square built from explicit segments so every dash is the same
  // length and all four corners get the same curved dash.
  function dashedRing(x0, y0, w, r, gap) {
    const L = w - 2 * r; // straight run per side
    // Solve so corner dash (quarter arc + 2 ext) equals the straight dash: πr/2 + 2e = L − 2e − 2gap
    const ext = Math.max(0, (L - 2 * gap - Math.PI * r / 2) / 4);
    const mid = L - 2 * ext - 2 * gap; // middle dash length (== corner dash length)
    const x1 = x0 + w,
      y1 = y0 + w,
      d = [];
    d.push(`M${x0} ${y0 + r + ext}V${y0 + r}A${r} ${r} 0 0 1 ${x0 + r} ${y0}H${x0 + r + ext}`);
    d.push(`M${x1 - r - ext} ${y0}H${x1 - r}A${r} ${r} 0 0 1 ${x1} ${y0 + r}V${y0 + r + ext}`);
    d.push(`M${x1} ${y1 - r - ext}V${y1 - r}A${r} ${r} 0 0 1 ${x1 - r} ${y1}H${x1 - r - ext}`);
    d.push(`M${x0 + r + ext} ${y1}H${x0 + r}A${r} ${r} 0 0 1 ${x0} ${y1 - r}V${y1 - r - ext}`);
    const a = r + ext + gap;
    d.push(`M${x0 + a} ${y0}h${mid}`, `M${x1} ${y0 + a}v${mid}`, `M${x1 - a} ${y1}h${-mid}`, `M${x0} ${y1 - a}v${-mid}`);
    return d.join('');
  }
  // Refined hierarchy: answer > proof > solved ink > lines
  const R2 = {
    dark: {
      line: '#24160A',
      ink: '#4A2E12',
      ring: '#9C5E27',
      proof: '#CF8A4D'
    },
    light: {
      line: '#DCD1BC',
      ink: '#B6A88E',
      ring: '#C99A62',
      proof: '#A86A2A'
    },
    tinted: {
      line: '#2A2A2A',
      ink: '#484848',
      ring: '#7A7A7A',
      proof: '#A8A8A8'
    }
  };
  let uid = 0;
  window.PSIcon = function (variant = 'dark', px = 1024, opt = {}) {
    const base = V[variant] || V.dark,
      ref = opt.refined !== false;
    const c = ref ? {
      ...base,
      ...(R2[variant] || {})
    } : base;
    const P = ref ? {
      proofW: 9,
      ansW: 16,
      ansSize: 168,
      glowR: 280,
      inkSize: 132
    } : {
      proofW: 12,
      ansW: 14,
      ansSize: 170,
      glowR: 250,
      inkSize: 140
    };
    const _ = 0,
      id = 'psi' + uid++,
      o = 140,
      s = 248;
    const g = c.glow,
      rgba = a => `rgba(${g[0]},${g[1]},${g[2]},${a})`;
    let t = `<rect width="1024" height="1024" fill="url(#${id}b)"/>`;
    t += `<g stroke="${c.line}" stroke-width="10"><path d="M${o + s} ${o}V${o + 3 * s}M${o + 2 * s} ${o}V${o + 3 * s}M${o} ${o + s}H${o + 3 * s}M${o} ${o + 2 * s}H${o + 3 * s}"/></g>`;
    const txt = (k, d, fill, size) => {
      const x = o + k % 3 * s + s / 2,
        y = o + Math.floor(k / 3) * s + s / 2;
      return `<path transform="translate(${x} ${y}) scale(${size / 1000})" d="${GLYPHS[d]}" fill="${fill}"/>`;
    };
    [[0, 3], [2, 8], [6, 1], [8, 6]].forEach(([k, d]) => {
      t += txt(k, d, c.ink, P.inkSize);
    });
    [[1, 2], [3, 7]].forEach(([k, d]) => {
      const x = o + k % 3 * s,
        y = o + Math.floor(k / 3) * s;
      t += `<rect x="${x + 30}" y="${y + 30}" width="${s - 60}" height="${s - 60}" rx="26" fill="none" stroke="${c.ring}" stroke-width="${P.proofW}"/>` + txt(k, d, c.proof, P.inkSize);
    });
    const cx = o + s,
      cy = o + s;
    t += `<circle cx="${cx + s / 2}" cy="${cy + s / 2}" r="${P.glowR}" fill="url(#${id}g)"/>`;
    t += `<path d="${dashedRing(cx + 24, cy + 24, s - 48, 32, 30)}" fill="none" stroke="url(#${id}w)" stroke-width="${P.ansW}" stroke-linecap="round" stroke-linejoin="round"/>`;
    t += txt(4, 5, `url(#${id}w)`, P.ansSize);
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${px}" height="${px}" viewBox="0 0 1024 1024"><defs>
<radialGradient id="${id}b" cx="50%" cy="50%" r="70%"><stop offset="0" stop-color="${c.bg0}"/><stop offset="1" stop-color="${c.bg1}"/></radialGradient>
<radialGradient id="${id}g"><stop offset="0" stop-color="${rgba(g[3])}"/><stop offset="1" stop-color="${rgba(0)}"/></radialGradient>
<linearGradient id="${id}w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c.a0}"/><stop offset="1" stop-color="${c.a1}"/></linearGradient>
<clipPath id="${id}m"><rect width="1024" height="1024" rx="${opt.mask === false ? 0 : 229}"/></clipPath></defs><g clip-path="url(#${id}m)">${t}</g></svg>`;
  };
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "assets/app-icon/icon.js", error: String((e && e.message) || e) }); }

// components/Board/Board.jsx
try { (() => {
const UNIT_BOX = b => {
  const r0 = Math.floor(b / 3) * 3,
    c0 = b % 3 * 3,
    u = [];
  for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) u.push((r0 + r) * 9 + c0 + c);
  return u;
};
const rowOf = i => Math.floor(i / 9),
  colOf = i => i % 9,
  boxOf = i => Math.floor(rowOf(i) / 3) * 3 + Math.floor(colOf(i) / 3);
function Board({
  values = [],
  givens = [],
  notes = [],
  selected = -1,
  width = 366,
  clarity = 0,
  marks = {},
  errors = [],
  onSelect
}) {
  const type = {
    digit: [1, 1.1, 1.2][clarity],
    given: [600, 700, 760][clarity],
    user: [400, 500, 600][clarity],
    cand: [1, 1.12, 1.25][clarity],
    line: [1, 1.5, 2][clarity]
  };
  const cs = (width - 8) / 9,
    lw = Math.max(1, Math.round(type.line)),
    mj = 1 + Math.round(type.line);
  const sv = selected >= 0 ? values[selected] : 0;
  const has = (arr, i) => Array.isArray(arr) && arr.includes(i);
  const cell = i => {
    const v = values[i],
      g = givens[i],
      isSel = i === selected;
    const peer = selected >= 0 && !isSel && (rowOf(i) === rowOf(selected) || colOf(i) === colOf(selected) || boxOf(i) === boxOf(selected));
    const same = sv && v === sv && !isSel;
    const dim = marks.focus && !has(marks.focus, i);
    let bg = 'var(--bg)';
    if (has(marks.pattern, i)) bg = 'var(--same)';else if (isSel) bg = 'var(--sel)';else if (same) bg = 'var(--same)';else if (peer && !marks.focus) bg = 'var(--peer)';
    const sh = [];
    if (isSel) sh.push('inset 0 0 0 2px var(--accent)');
    if (has(marks.evidence, i)) sh.push('inset 0 0 0 1.5px var(--accent)');
    const err = has(errors, i),
      n = notes[i] || 0;
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      onClick: () => onSelect && onSelect(i),
      style: {
        background: bg,
        boxShadow: sh.join(','),
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: onSelect ? 'pointer' : 'default'
      }
    }, marks.target === i && /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        inset: 3,
        border: '1.5px dashed var(--accent)',
        borderRadius: 4
      }
    }), v ? /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: cs * 0.6 * type.digit,
        lineHeight: 1,
        fontWeight: g ? type.given : type.user,
        color: err ? 'var(--err)' : g ? 'var(--ink)' : 'var(--accent)',
        opacity: dim ? 0.25 : 1,
        position: 'relative',
        fontVariantNumeric: 'tabular-nums'
      }
    }, v, err && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        left: '-10%',
        right: '-10%',
        bottom: -cs * 0.1,
        height: 2,
        borderRadius: 1,
        background: 'var(--err)'
      }
    })) : marks.target === i && marks.ghost ? /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: cs * 0.6 * type.digit,
        lineHeight: 1,
        color: 'var(--accent)',
        opacity: 0.55
      }
    }, marks.ghost) : n ? /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        inset: cs * 0.06,
        display: 'grid',
        gridTemplateColumns: 'repeat(3,1fr)',
        gridTemplateRows: 'repeat(3,1fr)',
        opacity: dim ? 0.25 : 1
      }
    }, [1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => /*#__PURE__*/React.createElement("span", {
      key: d,
      style: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: cs * 0.25 * type.cand,
        lineHeight: 1,
        fontWeight: sv === d ? 700 : 500,
        color: sv === d ? 'var(--accent)' : 'var(--ink2)'
      }
    }, n & 1 << d ? d : ''))) : null);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      height: width,
      boxSizing: 'border-box',
      padding: mj,
      background: 'var(--lineMajor)',
      borderRadius: 6,
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      gridTemplateRows: 'repeat(3,1fr)',
      gap: mj
    }
  }, [0, 1, 2, 3, 4, 5, 6, 7, 8].map(b => /*#__PURE__*/React.createElement("div", {
    key: b,
    style: {
      background: 'var(--line)',
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      gridTemplateRows: 'repeat(3,1fr)',
      gap: lw
    }
  }, UNIT_BOX(b).map(cell))));
}
Object.assign(__ds_scope, { Board });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/Board/Board.jsx", error: String((e && e.message) || e) }); }

// components/HintCard/HintCard.jsx
try { (() => {
const LABELS = ['', 'Where to look', 'Technique', 'Why'];
function HintCard({
  level = 1,
  technique,
  tier,
  text,
  cta,
  onNext,
  onClose,
  onLesson,
  night = false
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: night ? 'transparent' : 'var(--surface)',
      border: '1px solid var(--hair)',
      borderRadius: 18,
      padding: '12px 14px 12px 16px',
      display: 'flex',
      flexDirection: 'column',
      gap: 6,
      minHeight: 124,
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 4
    }
  }, [1, 2, 3].map(n => /*#__PURE__*/React.createElement("span", {
    key: n,
    style: {
      width: n === level ? 14 : 5,
      height: 5,
      borderRadius: 3,
      background: n <= level ? 'var(--accent)' : 'var(--hair)'
    }
  }))), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--ink3)'
    }
  }, LABELS[level]), level >= 2 && tier && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--ink3)'
    }
  }, "\xB7 ", tier), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), onClose && /*#__PURE__*/React.createElement("button", {
    onClick: onClose,
    "aria-label": "Close hint",
    style: {
      border: 0,
      background: 'none',
      color: 'var(--ink3)',
      cursor: 'pointer',
      fontSize: 16
    }
  }, "\xD7")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, level === 2 && technique && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 500,
      fontSize: 21,
      color: 'var(--ink)',
      marginBottom: 2
    }
  }, technique), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: level === 1 ? 16 : 14,
      lineHeight: 1.35,
      color: level === 1 ? 'var(--ink)' : 'var(--ink2)',
      textWrap: 'pretty'
    }
  }, text)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      alignItems: 'center',
      justifyContent: 'flex-end'
    }
  }, onLesson && level >= 2 && /*#__PURE__*/React.createElement("button", {
    onClick: onLesson,
    style: {
      border: 0,
      background: 'none',
      fontSize: 13,
      color: 'var(--ink2)',
      marginRight: 'auto',
      cursor: 'pointer',
      fontFamily: 'inherit'
    }
  }, "Lesson \u2192"), /*#__PURE__*/React.createElement("button", {
    onClick: onNext,
    style: {
      height: 34,
      padding: '0 14px',
      borderRadius: 17,
      border: 0,
      cursor: 'pointer',
      fontFamily: 'inherit',
      fontSize: 14,
      fontWeight: 600,
      background: night ? 'transparent' : 'var(--accent)',
      color: night ? 'var(--accent)' : 'var(--bg)',
      boxShadow: night ? 'inset 0 0 0 1.5px var(--accentDim)' : 'none'
    }
  }, cta)));
}
Object.assign(__ds_scope, { HintCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/HintCard/HintCard.jsx", error: String((e && e.message) || e) }); }

// components/Keypad/Keypad.jsx
try { (() => {
function Keypad({
  remaining = {},
  notesMode = false,
  clarity = 0,
  onDigit
}) {
  const ui = [1, 1.06, 1.12][clarity];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(9,1fr)',
      gap: 4
    }
  }, [1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => {
    const left = remaining[d] ?? 9,
      done = left <= 0;
    return /*#__PURE__*/React.createElement("button", {
      key: d,
      disabled: done,
      onClick: () => onDigit && onDigit(d),
      style: {
        height: 64,
        border: 0,
        background: 'none',
        borderRadius: 12,
        padding: 0,
        cursor: 'pointer',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 3,
        opacity: done ? 0.28 : 1,
        fontFamily: 'inherit'
      }
    }, notesMode ? /*#__PURE__*/React.createElement("span", {
      style: {
        width: 30,
        height: 30,
        display: 'grid',
        gridTemplateColumns: 'repeat(3,1fr)',
        gridTemplateRows: 'repeat(3,1fr)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        gridColumn: (d - 1) % 3 + 1,
        gridRow: Math.floor((d - 1) / 3) + 1,
        fontSize: 13,
        fontWeight: 700,
        color: 'var(--accent)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }
    }, d)) : /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 30 * ui,
        color: 'var(--ink)',
        lineHeight: 1,
        height: 30,
        display: 'flex',
        alignItems: 'center'
      }
    }, d), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 10.5,
        color: 'var(--ink3)',
        fontWeight: 500,
        fontVariantNumeric: 'tabular-nums',
        minHeight: 12
      }
    }, done ? '' : left));
  }));
}
Object.assign(__ds_scope, { Keypad });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/Keypad/Keypad.jsx", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/Display.jsx
try { (() => {
/* global React, Ico, Seg, Toggle, Row, SectionLabel, Calibrate, SliderRow, PRESETS */
const {
  useState: useStD
} = React;
function SamplePreview() {
  const c = {
    width: 52,
    height: 52,
    borderRadius: 4,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
    boxShadow: 'inset 0 0 0 1px var(--line)'
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      justifyContent: 'center',
      padding: '18px 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: c
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 30,
      fontWeight: 600,
      color: 'var(--ink)'
    }
  }, "5")), /*#__PURE__*/React.createElement("div", {
    style: c
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 30,
      color: 'var(--accent)'
    }
  }, "3")), /*#__PURE__*/React.createElement("div", {
    style: {
      ...c,
      background: 'var(--sel)',
      boxShadow: 'inset 0 0 0 2px var(--accent)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 30,
      color: 'var(--accent)'
    }
  }, "7")), /*#__PURE__*/React.createElement("div", {
    style: c
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 30,
      color: 'var(--err)',
      position: 'relative'
    }
  }, "4", /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: -3,
      right: -3,
      bottom: -5,
      height: 2,
      background: 'var(--err)'
    }
  }))), /*#__PURE__*/React.createElement("div", {
    style: c
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      width: 42,
      fontSize: 11,
      lineHeight: '14px',
      textAlign: 'center',
      color: 'var(--ink2)'
    }
  }, /*#__PURE__*/React.createElement("span", null, "1"), /*#__PURE__*/React.createElement("span", null), /*#__PURE__*/React.createElement("span", null, "3"), /*#__PURE__*/React.createElement("span", null), /*#__PURE__*/React.createElement("span", null), /*#__PURE__*/React.createElement("span", null), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)',
      fontWeight: 700
    }
  }, "7"), /*#__PURE__*/React.createElement("span", null), /*#__PURE__*/React.createElement("span", null, "9"))));
}
const APPEARANCES = [['day', 'Day', 'Warm paper. For daylight and lamps.'], ['night', 'Night', 'Black screen, warm digits, silent.'], ['auto', 'After dark', 'Sunset to sunrise where you are.'], ['system', 'Match iPhone', 'Follows Light and Dark in iOS Settings.']];
function AfterDarkHours({
  settings,
  setS
}) {
  const loc = settings.location !== false;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      borderTop: '1px solid var(--hair)',
      padding: '12px 16px 14px',
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      color: 'var(--ink)',
      flex: 1
    }
  }, loc ? 'Tonight' : 'Hours'), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      color: 'var(--ink2)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, loc ? 'Sunset 6:12 PM → sunrise 6:41 AM' : '9:00 PM → 6:30 AM')), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)',
      lineHeight: 1.45,
      textWrap: 'pretty'
    }
  }, loc ? 'Worked out on this iPhone from your rough location and the date. Nothing leaves the phone.' : 'No location, so fixed hours are used. Tap a time to change it.'), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: () => setS({
      location: !loc
    }),
    style: {
      height: 32,
      padding: '0 12px',
      borderRadius: 16,
      fontSize: 13,
      color: 'var(--ink2)',
      boxShadow: 'inset 0 0 0 1px var(--hair)'
    }
  }, loc ? 'Use fixed hours instead' : 'Use sunset and sunrise')));
}
function DisplaySettings({
  settings,
  setS,
  pal,
  onBack,
  onCalibrate
}) {
  const K = pal.kelvin || 6500,
    N = window.PSNight;
  const warmTrack = `linear-gradient(90deg, ${[0, 25, 50, 75, 100].map(w => {
    const c = N.kelvinRGB(N.warmthToK(w)),
      s = (pal.s || 1) * 0.75;
    return `rgb(${c.map(x => Math.round(x * s)).join(',')})`;
  }).join(',')})`;
  return /*#__PURE__*/React.createElement("div", {
    className: "ps-scroll",
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 54,
      paddingBottom: 40
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 48,
      padding: '0 10px',
      display: 'flex',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: onBack,
    "aria-label": "Back"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "back"
  }))), /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 30,
      color: 'var(--ink)',
      padding: '0 22px 4px'
    }
  }, "Display & Night"), /*#__PURE__*/React.createElement("div", {
    className: "ps-card",
    style: {
      margin: '10px 16px 24px'
    }
  }, /*#__PURE__*/React.createElement(SamplePreview, null)), /*#__PURE__*/React.createElement(SectionLabel, null, "Appearance"), /*#__PURE__*/React.createElement("div", {
    className: "ps-card",
    style: {
      margin: '0 16px 24px'
    }
  }, APPEARANCES.map(([k, l, sub], i) => /*#__PURE__*/React.createElement("button", {
    key: k,
    onClick: () => setS({
      appearance: k
    }),
    style: {
      width: '100%',
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '12px 16px',
      textAlign: 'left',
      borderBottom: i < 3 ? '1px solid var(--hair)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: 16,
      color: 'var(--ink)'
    }
  }, l), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: 13,
      color: 'var(--ink3)',
      marginTop: 2
    }
  }, sub)), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 24,
      color: 'var(--accent)'
    }
  }, settings.appearance === k && /*#__PURE__*/React.createElement(Ico, {
    n: "check",
    s: 20,
    w: 2.2
  })))), settings.appearance === 'auto' && /*#__PURE__*/React.createElement(AfterDarkHours, {
    settings: settings,
    setS: setS
  })), /*#__PURE__*/React.createElement(SectionLabel, null, "Night screen"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      padding: '0 22px 18px'
    }
  }, PRESETS.map(p => {
    const on = Math.abs(settings.glow - p.glow) < 3 && Math.abs(settings.warmth - p.warmth) < 3;
    return /*#__PURE__*/React.createElement("button", {
      key: p.k,
      onClick: () => setS({
        glow: p.glow,
        warmth: p.warmth
      }),
      style: {
        flex: 1,
        height: 36,
        borderRadius: 18,
        fontSize: 13,
        fontWeight: 500,
        color: on ? 'var(--accent)' : 'var(--ink2)',
        boxShadow: `inset 0 0 0 1.5px ${on ? 'var(--accentDim)' : 'var(--hair)'}`
      }
    }, p.l);
  })), /*#__PURE__*/React.createElement(SliderRow, {
    label: "Glow",
    value: `${settings.glow}%`,
    sub: pal.mode === 'day' ? 'Applies when Night is on.' : settings.glow < 35 ? 'Below your iPhone’s lowest brightness.' : 'How much light the screen gives off.'
  }, /*#__PURE__*/React.createElement("input", {
    className: "ps-range",
    type: "range",
    min: "0",
    max: "100",
    value: settings.glow,
    onChange: e => setS({
      glow: +e.target.value
    }),
    "aria-label": "Glow"
  })), /*#__PURE__*/React.createElement(SliderRow, {
    label: "Warmth",
    value: `${N.warmthToK(settings.warmth).toLocaleString()} K`,
    sub: "Higher is warmer, with less blue light."
  }, /*#__PURE__*/React.createElement("input", {
    className: "ps-range",
    type: "range",
    min: "0",
    max: "100",
    value: settings.warmth,
    onChange: e => setS({
      warmth: +e.target.value
    }),
    "aria-label": "Warmth",
    style: {
      '--track': warmTrack
    }
  })), /*#__PURE__*/React.createElement(SectionLabel, {
    style: {
      paddingTop: 8
    }
  }, "Your eyes"), /*#__PURE__*/React.createElement("div", {
    className: "ps-card",
    style: {
      margin: '0 16px 24px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '12px 16px',
      borderBottom: '1px solid var(--hair)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      color: 'var(--ink)',
      marginBottom: 10
    }
  }, "Clarity"), /*#__PURE__*/React.createElement(Seg, {
    value: settings.clarity,
    onChange: v => setS({
      clarity: v
    }),
    options: [[0, 'Standard'], [1, 'Large'], [2, 'Bold']]
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)',
      marginTop: 8
    }
  }, "Bigger, heavier digits and stronger lines. Day and Night.")), /*#__PURE__*/React.createElement(Row, {
    label: "Lowest readable glow",
    sub: settings.glowFloor ? `Set at ${settings.glowFloor}%. Glow and Drift never go below it.` : 'Not set yet.',
    last: true
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onCalibrate,
    style: {
      color: 'var(--accent)',
      fontSize: 15,
      fontWeight: 500
    }
  }, "Check again"))), /*#__PURE__*/React.createElement(SectionLabel, null, "Quiet"), /*#__PURE__*/React.createElement("div", {
    className: "ps-card",
    style: {
      margin: '0 16px 24px'
    }
  }, /*#__PURE__*/React.createElement(Row, {
    label: "Drift",
    sub: "Over 30 minutes, glow eases down and warmth eases up."
  }, /*#__PURE__*/React.createElement(Toggle, {
    on: settings.drift,
    onChange: v => setS({
      drift: v
    }),
    label: "Drift"
  })), /*#__PURE__*/React.createElement(Row, {
    label: "Hide status bar in games",
    sub: "Clock and battery give off light too."
  }, /*#__PURE__*/React.createElement(Toggle, {
    on: settings.hideStatus !== false,
    onChange: v => setS({
      hideStatus: v
    }),
    label: "Hide status bar"
  })), /*#__PURE__*/React.createElement(Row, {
    label: "Sounds"
  }, /*#__PURE__*/React.createElement(Toggle, {
    on: !!settings.sounds,
    onChange: v => setS({
      sounds: v
    }),
    label: "Sounds"
  })), /*#__PURE__*/React.createElement(Row, {
    label: "Vibration",
    sub: "Night always keeps sound and vibration off.",
    last: true
  }, /*#__PURE__*/React.createElement(Toggle, {
    on: !!settings.haptics,
    onChange: v => setS({
      haptics: v
    }),
    label: "Vibration"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 22px',
      fontSize: 13,
      color: 'var(--ink3)',
      lineHeight: 1.5
    }
  }, "Hush: tap with two fingers anywhere in a game to turn the screen black. Tap again to come back."));
}
function FirstNight({
  settings,
  setS,
  onDone,
  initialStep = 'intro',
  initialPick = null,
  pal
}) {
  const [step, setStep] = useStD(initialStep);
  if (step === 'cal') return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 130
    }
  }, /*#__PURE__*/React.createElement(Calibrate, {
    settings: settings,
    setS: p => {
      const {
        calibrated,
        ...rest
      } = p;
      setS(rest);
    },
    done: () => setStep('done'),
    initialPick: initialPick,
    first: true
  }));
  const done = step === 'done';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      padding: '150px 30px 60px',
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "moon",
    s: 30
  })), /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 36,
      color: 'var(--ink)',
      margin: '22px 0 12px',
      lineHeight: 1.1
    }
  }, done ? `Glow set to ${settings.glow}%.` : 'Good evening.'), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 17,
      color: 'var(--ink2)',
      lineHeight: 1.45,
      textWrap: 'pretty'
    }
  }, done ? `Warmth is ${(pal.kelvin || 0).toLocaleString()} K. You can change both any time from the moon at the top of every screen.` : 'Before your first puzzle, let’s set the screen for your eyes and this room. It takes twenty seconds, and nothing will flash.'), done && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 28
    }
  }, /*#__PURE__*/React.createElement(SamplePreview, null)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("button", {
    className: "ps-btn",
    style: {
      width: '100%',
      height: 50
    },
    onClick: () => done ? onDone() : setStep('cal')
  }, done ? 'Start playing' : 'Find my lowest glow'), !done && /*#__PURE__*/React.createElement("button", {
    onClick: () => {
      setS({
        glow: 18,
        warmth: 75,
        calibrated: true
      });
      onDone();
    },
    style: {
      marginTop: 16,
      fontSize: 15,
      color: 'var(--ink3)',
      height: 44
    }
  }, "Skip for now \u2014 use Lights out"));
}
Object.assign(window, {
  DisplaySettings,
  FirstNight,
  SamplePreview
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/Display.jsx", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/GameScreen.jsx
try { (() => {
/* global React, GridBoard, Keypad, ToolBtn, Ico */
const {
  useState: useStG,
  useEffect: useEfG,
  useMemo: useMemoG,
  useRef: useRefG
} = React;
const LEVEL_NAMES = {
  easy: 'Easy',
  medium: 'Medium',
  hard: 'Hard',
  expert: 'Expert',
  master: 'Master'
};
const TIER_NAMES = ['Beginner', 'Intermediate', 'Advanced', 'Expert', 'Esoteric'];
const fmtTime = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
function newGame(diff) {
  const E = window.PSEngine,
    start = E.parse(E.PUZZLES[diff]),
    sol = E.solve(start);
  return {
    diff,
    start,
    sol,
    vals: start.slice(),
    notes: Array(81).fill(0),
    elapsed: 0,
    history: [],
    hints: 0,
    placedByHint: 0,
    checked: false,
    done: false
  };
}
function GameScreen({
  game,
  setGame,
  settings,
  pal,
  onBack,
  openNight,
  onHush,
  onLesson,
  onGoodnight,
  onNew,
  demo
}) {
  const E = window.PSEngine;
  const [sel, setSel] = useStG(() => game.vals.findIndex(v => !v));
  const [notesMode, setNotesMode] = useStG(!!(demo && demo.notes));
  const [hint, setHint] = useStG(() => {
    if (demo && demo.hint) {
      E.setNotation(settings.notation);
      return {
        h: E.findHint(game.vals, game.sol),
        level: demo.hint
      };
    }
    return null;
  });
  const [paused, setPaused] = useStG(!!(demo && demo.paused));
  const [menu, setMenu] = useStG(!!(demo && demo.menu));
  const givens = useMemoG(() => game.start.map(v => !!v), [game.start]);
  useEfG(() => {
    if (paused || game.done || demo && demo.frozen) return;
    const id = setInterval(() => setGame(g => ({
      ...g,
      elapsed: g.elapsed + 1
    })), 1000);
    return () => clearInterval(id);
  }, [paused, game.done]);
  const errors = useMemoG(() => {
    if (settings.mistakes === 'never' || settings.mistakes === 'check' && !game.checked) return new Set();
    return new Set(game.vals.map((v, i) => v && !givens[i] && v !== game.sol[i] ? i : -1).filter(i => i >= 0));
  }, [game.vals, game.checked, settings.mistakes]);
  const remaining = useMemoG(() => {
    const r = {};
    for (let d = 1; d <= 9; d++) r[d] = 9 - game.vals.filter(v => v === d).length;
    return r;
  }, [game.vals]);
  function commit(mut) {
    setGame(g => {
      const n = {
        ...g,
        vals: g.vals.slice(),
        notes: g.notes.slice(),
        history: [...g.history.slice(-80), {
          vals: g.vals,
          notes: g.notes
        }],
        checked: false
      };
      mut(n);
      n.done = n.vals.every((v, i) => v === n.sol[i]);
      return n;
    });
  }
  function place(d) {
    if (sel < 0 || givens[sel] || game.done) return;
    commit(n => {
      if (notesMode) {
        if (!n.vals[sel]) n.notes[sel] ^= 1 << d;
        return;
      }
      n.vals[sel] = n.vals[sel] === d ? 0 : d;
      n.notes[sel] = 0;
      if (n.vals[sel] && settings.autoRemove) E.PEERS[sel].forEach(p => {
        n.notes[p] &= ~(1 << d);
      });
    });
    if (hint && !notesMode && hint.h.cell === sel && hint.h.digit === d) setHint(null);
  }
  function erase() {
    if (sel < 0 || givens[sel]) return;
    commit(n => {
      n.vals[sel] = 0;
      n.notes[sel] = 0;
    });
  }
  function undo() {
    setGame(g => {
      if (!g.history.length) return g;
      const last = g.history[g.history.length - 1];
      return {
        ...g,
        vals: last.vals,
        notes: last.notes,
        history: g.history.slice(0, -1),
        done: false
      };
    });
  }
  function fillNotes() {
    commit(n => {
      for (let i = 0; i < 81; i++) n.notes[i] = n.vals[i] ? 0 : E.candMask(n.vals, i);
    });
    setMenu(false);
  }
  function hintStep() {
    if (!hint) {
      E.setNotation(settings.notation);
      const h = E.findHint(game.vals, game.sol);
      if (h) {
        setHint({
          h,
          level: 1
        });
        setGame(g => ({
          ...g,
          hints: g.hints + 1
        }));
      }
      return;
    }
    if (hint.level < 3) {
      setHint({
        ...hint,
        level: hint.level + 1
      });
      return;
    }
    const h = hint.h;
    if (h.kind === 'mistake') commit(n => {
      n.vals[h.cell] = 0;
    });else commit(n => {
      n.vals[h.cell] = h.digit;
      n.notes[h.cell] = 0;
      if (settings.autoRemove) E.PEERS[h.cell].forEach(p => {
        n.notes[p] &= ~(1 << h.digit);
      });
    });
    setGame(g => ({
      ...g,
      placedByHint: g.placedByHint + 1,
      assisted: h.kind !== 'mistake' ? true : g.assisted
    }));
    setSel(h.cell);
    setHint(null);
  }
  const marks = useMemoG(() => {
    if (!hint) return {};
    const h = hint.h,
      L = hint.level;
    const focus = new Set([...h.focus, ...(L >= 2 ? h.pattern : []), ...(L >= 3 ? h.evidence : []), h.cell]);
    return {
      spotlight: true,
      focus,
      pattern: L >= 2 ? new Set(h.pattern) : null,
      elim: L >= 3 ? new Set(h.elim) : null,
      evidence: L >= 3 ? new Set(h.evidence) : null,
      target: L >= 3 ? h.cell : -1,
      ghost: L >= 3 && h.kind !== 'mistake' ? h.digit : 0
    };
  }, [hint]);
  const needed = useMemoG(() => game.done ? E.techniquesNeeded(game.start, game.sol) : null, [game.done]);
  const twoFinger = e => {
    if (e.touches && e.touches.length >= 2) onHush();
  };
  return /*#__PURE__*/React.createElement("div", {
    onTouchStart: twoFinger,
    style: {
      position: 'absolute',
      inset: 0,
      display: 'flex',
      flexDirection: 'column',
      paddingTop: 54
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 48,
      display: 'flex',
      alignItems: 'center',
      padding: '0 10px',
      gap: 4
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: onBack,
    "aria-label": "Back"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "back"
  })), /*#__PURE__*/React.createElement("button", {
    onClick: () => setPaused(p => !p),
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 1,
      color: 'var(--ink2)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--ink3)'
    }
  }, LEVEL_NAMES[game.diff]), settings.showTimer && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      fontWeight: 500,
      fontVariantNumeric: 'tabular-nums',
      display: 'flex',
      alignItems: 'center',
      gap: 5
    }
  }, fmtTime(game.elapsed), paused && /*#__PURE__*/React.createElement(Ico, {
    n: "pause",
    s: 12
  }))), /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: openNight,
    "aria-label": "Night settings"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "moon"
  })), /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: () => setMenu(m => !m),
    "aria-label": "More"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "more",
    w: 3
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center',
      marginTop: 6,
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      opacity: game.done ? 0.3 : 1,
      transition: 'opacity .6s ease'
    }
  }, paused ? /*#__PURE__*/React.createElement("div", {
    style: {
      width: 366,
      height: 366,
      border: '1px solid var(--hair)',
      borderRadius: 6,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "ps-serif",
    style: {
      fontSize: 28,
      color: 'var(--ink)'
    }
  }, "Paused"), /*#__PURE__*/React.createElement("button", {
    className: "ps-btn",
    onClick: () => setPaused(false)
  }, "Resume")) : /*#__PURE__*/React.createElement(GridBoard, {
    vals: game.vals,
    givens: givens,
    notes: game.notes,
    sel: hint ? -1 : sel,
    type: pal.type,
    marks: marks,
    errors: errors,
    onSelect: i => {
      setSel(i);
    }
  })), game.done && /*#__PURE__*/React.createElement(SolvedPanel, {
    game: game,
    needed: needed,
    onGoodnight: onGoodnight,
    onNew: onNew
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 124,
      margin: '12px 12px 0',
      display: 'flex',
      alignItems: 'stretch'
    }
  }, hint && !game.done && /*#__PURE__*/React.createElement(HintCard, {
    hint: hint,
    onNext: hintStep,
    onClose: () => setHint(null),
    onLesson: onLesson
  }), !hint && !game.done && notesMode && /*#__PURE__*/React.createElement("div", {
    style: {
      alignSelf: 'center',
      width: '100%',
      textAlign: 'center',
      fontSize: 13,
      color: 'var(--ink3)'
    }
  }, "Notes on \u2014 digits go in as pencil marks")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(4,1fr)',
      padding: '0 18px',
      opacity: game.done ? 0.3 : 1
    }
  }, /*#__PURE__*/React.createElement(ToolBtn, {
    icon: "undo",
    label: "Undo",
    onClick: undo,
    disabled: !game.history.length
  }), /*#__PURE__*/React.createElement(ToolBtn, {
    icon: "erase",
    label: "Erase",
    onClick: erase
  }), /*#__PURE__*/React.createElement(ToolBtn, {
    icon: "pencil",
    label: "Notes",
    onClick: () => setNotesMode(m => !m),
    active: notesMode,
    badge: notesMode ? 'ON' : 'OFF'
  }), /*#__PURE__*/React.createElement(ToolBtn, {
    icon: "hint",
    label: hint ? 'Next step' : 'Hint',
    onClick: hintStep,
    active: !!hint
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '6px 8px 30px',
      opacity: game.done ? 0.3 : 1
    }
  }, /*#__PURE__*/React.createElement(Keypad, {
    onDigit: place,
    notesMode: notesMode,
    remaining: remaining,
    type: pal.type
  })), menu && /*#__PURE__*/React.createElement("div", {
    onClick: () => setMenu(false),
    style: {
      position: 'absolute',
      inset: 0,
      zIndex: 40
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    className: "ps-pop",
    style: {
      position: 'absolute',
      top: 104,
      right: 12,
      width: 230
    }
  }, [['Check puzzle', () => {
    setGame(g => ({
      ...g,
      checked: true
    }));
    setMenu(false);
  }], ['Fill all notes', fillNotes], ['Restart puzzle', () => {
    setGame(() => newGame(game.diff));
    setMenu(false);
    setHint(null);
  }], ['Hush screen', () => {
    setMenu(false);
    onHush();
  }]].map(([l, f], k) => /*#__PURE__*/React.createElement("button", {
    key: l,
    onClick: f,
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      width: '100%',
      padding: '13px 16px',
      fontSize: 15,
      color: 'var(--ink)',
      borderTop: k ? '1px solid var(--hair)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("span", null, l), l === 'Hush screen' && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--ink3)'
    }
  }, "2-finger tap"))))));
}
function HintCard({
  hint,
  onNext,
  onClose,
  onLesson
}) {
  const {
      h,
      level
    } = hint,
    mistake = h.kind === 'mistake';
  const label = ['', 'Where to look', mistake ? 'Mistake' : 'Technique', 'Why'][level];
  const cta = level === 1 ? mistake ? 'Show me' : 'Which technique?' : level === 2 ? 'Show me why' : mistake ? 'Clear it' : `Place ${h.digit} · assisted`;
  const hasLesson = ['Hidden Single', 'Naked Pair', 'Naked Single', 'Full House', 'Pointing', 'Claiming'].includes(h.technique);
  return /*#__PURE__*/React.createElement("div", {
    className: "ps-card",
    style: {
      flex: 1,
      padding: '12px 14px 12px 16px',
      display: 'flex',
      flexDirection: 'column',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 4
    }
  }, [1, 2, 3].map(n => /*#__PURE__*/React.createElement("span", {
    key: n,
    style: {
      width: n === level ? 14 : 5,
      height: 5,
      borderRadius: 3,
      background: n <= level ? 'var(--accent)' : 'var(--hair)'
    }
  }))), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--ink3)'
    }
  }, label), level >= 2 && !mistake && h.tier >= 0 && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--ink3)'
    }
  }, "\xB7 ", TIER_NAMES[h.tier] || 'Advanced'), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("button", {
    onClick: onClose,
    "aria-label": "Close hint",
    style: {
      color: 'var(--ink3)',
      padding: 4,
      margin: -4
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "close",
    s: 16
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minHeight: 0
    }
  }, level === 2 && !mistake && /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 21,
      color: 'var(--ink)',
      marginBottom: 2
    }
  }, h.technique), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: level === 1 ? 16 : 14,
      lineHeight: 1.35,
      color: level === 1 ? 'var(--ink)' : 'var(--ink2)',
      textWrap: 'pretty'
    }
  }, level === 1 ? h.nudge : level === 2 ? mistake ? h.why : h.short : h.why)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      justifyContent: 'flex-end',
      alignItems: 'center'
    }
  }, level >= 2 && hasLesson && /*#__PURE__*/React.createElement("button", {
    onClick: () => onLesson(h.technique),
    style: {
      fontSize: 13,
      color: 'var(--ink2)',
      padding: '6px 4px',
      marginRight: 'auto'
    }
  }, "Lesson \u2192"), /*#__PURE__*/React.createElement("button", {
    className: "ps-btn ps-btn-sm",
    onClick: onNext
  }, cta)));
}
function SolvedPanel({
  game,
  needed,
  onGoodnight,
  onNew
}) {
  const list = needed ? Object.entries(needed).sort((a, b) => b[1] - a[1]) : [];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 10,
      textAlign: 'center',
      padding: '0 40px'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "ps-serif",
    style: {
      fontSize: 44,
      color: 'var(--ink)',
      lineHeight: 1
    }
  }, "Solved."), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      color: 'var(--ink2)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, LEVEL_NAMES[game.diff], " \xB7 ", fmtTime(game.elapsed), game.hints ? ` · ${game.hints} hint${game.hints > 1 ? 's' : ''}` : ''), game.assisted && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      color: 'var(--ink2)',
      padding: '4px 10px',
      borderRadius: 12,
      boxShadow: 'inset 0 0 0 1px var(--hair)'
    }
  }, "Assisted \xB7 counts for your streak, not best times"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)',
      lineHeight: 1.5,
      marginTop: 4
    }
  }, "This grid took ", list.map(([t, n]) => `${t} ×${n}`).join(', '), "."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      marginTop: 14
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "ps-btn ps-btn-ghost",
    onClick: onNew
  }, "Another"), /*#__PURE__*/React.createElement("button", {
    className: "ps-btn",
    onClick: onGoodnight
  }, "Goodnight")));
}
Object.assign(window, {
  GameScreen,
  newGame,
  fmtTime,
  LEVEL_NAMES,
  TIER_NAMES
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/GameScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/Import.jsx
try { (() => {
/* global React, Ico, GridBoard */
const {
  useState: useStI
} = React;
function ImportSource({
  onBack
}) {
  const opt = (icon, title, sub) => /*#__PURE__*/React.createElement("button", {
    className: "ps-card",
    style: {
      width: '100%',
      padding: '18px 18px',
      display: 'flex',
      gap: 16,
      alignItems: 'center',
      textAlign: 'left'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: icon,
    s: 26
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: 17,
      color: 'var(--ink)'
    }
  }, title), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: 13,
      color: 'var(--ink3)',
      marginTop: 3
    }
  }, sub)), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--ink3)'
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "chev",
    s: 16
  })));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 54
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 48,
      padding: '0 10px',
      display: 'flex',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: onBack,
    "aria-label": "Back"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "close",
    s: 20
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '6px 22px 22px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 32,
      color: 'var(--ink)',
      lineHeight: 1.1
    }
  }, "Import a puzzle"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      color: 'var(--ink2)',
      marginTop: 8,
      lineHeight: 1.4,
      textWrap: 'pretty'
    }
  }, "From a newspaper, a book or a screenshot. The photo is read on this iPhone and never uploaded.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      padding: '0 16px'
    }
  }, opt('camera', 'Take a photo', 'Camera'), opt('grid', 'Choose from Photos', 'Screenshots work best'), opt('pencil', 'Type it in', 'Enter the givens by hand')), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '26px 22px 0',
      fontSize: 13,
      color: 'var(--ink3)',
      lineHeight: 1.6
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      marginBottom: 6
    }
  }, "For a clean read"), "Fill the frame with the grid \xB7 Good light, no glare \xB7 Pencil marks are ignored"));
}
function ImportReading() {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 54,
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 48
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '0 24px',
      height: 420,
      borderRadius: 16,
      position: 'relative',
      overflow: 'hidden',
      background: 'repeating-linear-gradient(135deg, var(--surface) 0 10px, var(--surface2) 10px 20px)',
      border: '1px solid var(--hair)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 12,
      left: 14,
      fontSize: 11,
      fontFamily: 'ui-monospace, monospace',
      color: 'var(--ink3)'
    }
  }, "photo"), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 38,
      top: 62,
      width: 266,
      height: 266,
      border: '2px solid var(--accent)',
      borderRadius: 4,
      transform: 'rotate(-3deg)',
      boxShadow: '0 0 0 2000px rgba(0,0,0,.35)'
    }
  }, [1, 2].map(k => /*#__PURE__*/React.createElement("span", {
    key: 'v' + k,
    style: {
      position: 'absolute',
      top: 0,
      bottom: 0,
      left: `${k * 100 / 3}%`,
      width: 1.5,
      background: 'var(--accentDim)'
    }
  })), [1, 2].map(k => /*#__PURE__*/React.createElement("span", {
    key: 'h' + k,
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      top: `${k * 100 / 3}%`,
      height: 1.5,
      background: 'var(--accentDim)'
    }
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '28px 24px 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 26,
      color: 'var(--ink)'
    }
  }, "Reading digits\u2026"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      color: 'var(--ink2)',
      marginTop: 6,
      fontVariantNumeric: 'tabular-nums'
    }
  }, "Grid found \xB7 61 of 81 cells checked"), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 3,
      borderRadius: 2,
      background: 'var(--hair)',
      marginTop: 16,
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: '75%',
      height: '100%',
      background: 'var(--accentDim)'
    }
  }))));
}
function ImportReview({
  pal,
  onBack
}) {
  const E = window.PSEngine;
  const vals = E.parse(E.PUZZLES.medium);
  vals[30] = 4; // misread: creates a conflict
  const unsure = new Set([5, 47, 57]);
  const conflict = new Set([30, 34]);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 54,
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 48,
      padding: '0 10px',
      display: 'flex',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: onBack,
    "aria-label": "Discard"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "close",
    s: 20
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      textAlign: 'center',
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--ink3)'
    }
  }, "Check the grid"), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 44
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center',
      marginTop: 6
    }
  }, /*#__PURE__*/React.createElement(GridBoard, {
    vals: vals,
    givens: vals.map(Boolean),
    type: pal.type,
    sel: 5,
    errors: conflict,
    marks: {
      evidence: unsure
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '14px 16px 0',
      display: 'flex',
      flexDirection: 'column',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      alignItems: 'flex-start',
      fontSize: 14,
      color: 'var(--ink2)',
      lineHeight: 1.4
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 14,
      height: 14,
      borderRadius: 3,
      boxShadow: 'inset 0 0 0 1.5px var(--accent)',
      marginTop: 2,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("b", {
    style: {
      color: 'var(--ink)',
      fontWeight: 600
    }
  }, "3 unsure."), " Ringed cells were hard to read \u2014 tap to confirm or fix.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      alignItems: 'flex-start',
      fontSize: 14,
      color: 'var(--ink2)',
      lineHeight: 1.4
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 14,
      height: 2,
      background: 'var(--err)',
      marginTop: 9,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("b", {
    style: {
      color: 'var(--ink)',
      fontWeight: 600
    }
  }, "Two 4s in row 4."), " Fix one before starting."))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(9,1fr)',
      gap: 4,
      padding: '0 8px 10px'
    }
  }, [1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => /*#__PURE__*/React.createElement("button", {
    key: d,
    className: "ps-key",
    style: {
      height: 52,
      fontSize: 26,
      color: 'var(--ink)'
    }
  }, d))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      padding: '0 16px 40px'
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "ps-btn ps-btn-ghost",
    style: {
      flex: 1,
      height: 46
    }
  }, "Clear cell"), /*#__PURE__*/React.createElement("button", {
    className: "ps-btn",
    style: {
      flex: 2,
      height: 46,
      opacity: 0.4
    },
    disabled: true
  }, "Start puzzle")));
}
Object.assign(window, {
  ImportSource,
  ImportReading,
  ImportReview
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/Import.jsx", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/Learn.jsx
try { (() => {
/* global React, GridBoard, Ico, ScreenHead, SectionLabel, TIER_NAMES */
const {
  useState: useStL
} = React;
const TECHNIQUES = [['Full House', 0, 'The last empty cell in a row, column or box.', 'mastered', 31], ['Naked Single', 0, 'A cell that can only hold one digit.', 'mastered', 58], ['Hidden Single', 0, 'A digit with only one home in a unit.', 'mastered', 112], ['Pointing', 1, 'A box confines a digit to one line.', 'learning', 4], ['Claiming', 1, 'A line confines a digit to one box.', 'new', 0], ['Naked Pair', 1, 'Two cells, two candidates, locked together.', 'new', 0], ['Naked Triple', 1, 'The same idea with three cells and three digits.', 'new', 0], ['Naked Quad', 1, 'Four cells holding exactly four digits.', 'new', 0], ['X-Wing', 2, 'One digit, two rows, the same two columns.', 'new', 0], ['Y-Wing', 2, 'A pivot cell and two pincers that share a digit.', 'new', 0], ['Swordfish', 2, 'X-Wing stretched across three rows.', 'new', 0], ['XY-Chain', 3, 'A chain of two-candidate cells that forces a result.', 'new', 0], ['Unique Rectangle', 3, 'Avoiding a pattern that would allow two solutions.', 'new', 0], ['3D Medusa', 3, 'Colouring candidates across many digits at once.', 'new', 0], ['Exocet', 4, 'A rare base-and-target pattern in two boxes.', 'new', 0], ['Sue de Coq', 4, 'Two overlapping sets that split their digits.', 'new', 0], ["Bowman's Bingo", 4, 'Follow a guess until it contradicts itself.', 'new', 0]];
const G = obj => {
  const v = Array(81).fill(0);
  Object.entries(obj).forEach(([i, d]) => v[+i] = d);
  return v;
};
const BOX1 = [0, 1, 2, 9, 10, 11, 18, 19, 20];
const ROW = r => [...Array(9)].map((_, c) => r * 9 + c);
const COLC = c => [...Array(9)].map((_, r) => r * 9 + c);
const LESSONS = {
  'Hidden Single': {
    intro: 'The most useful move in Sudoku. Instead of asking “what goes in this cell?”, ask “where does this digit go?”',
    vals: G({
      0: 7,
      9: 3,
      20: 8,
      13: 5,
      25: 5,
      37: 5,
      6: 2,
      50: 9,
      60: 4,
      75: 6,
      31: 3,
      66: 1
    }),
    steps: [{
      t: 'Pick one box and one digit. Where can 5 go in box 1?',
      focus: BOX1
    }, {
      t: 'The 5 in row 2 covers all of row 2 — so not the middle row of this box.',
      focus: [...BOX1, 13],
      ev: [13],
      elim: [10, 11]
    }, {
      t: 'The 5 in row 3 rules out the bottom row as well.',
      focus: [...BOX1, 13, 25],
      ev: [13, 25],
      elim: [10, 11, 18, 19]
    }, {
      t: 'And the 5 in column 2 rules out the top-middle cell.',
      focus: [...BOX1, 13, 25, 37],
      ev: [13, 25, 37],
      elim: [10, 11, 18, 19, 1]
    }, {
      t: 'One cell is left. 5 must go here — the digit was hidden among other possibilities, but it has only one home.',
      focus: [...BOX1, 13, 25, 37],
      ev: [13, 25, 37],
      target: 2,
      ghost: 5
    }],
    practice: 'easy'
  },
  'Pointing': {
    intro: 'Your first elimination. It doesn’t place a digit on its own — it removes candidates so a single appears.',
    vals: G({
      0: 5,
      1: 8,
      10: 4,
      18: 6,
      19: 2,
      20: 9,
      6: 3,
      12: 7,
      14: 1,
      17: 6
    }),
    steps: [{
      t: 'Look at 3 in box 1. It has two possible cells — and both sit in row 2.',
      focus: BOX1,
      cands: {
        9: {
          3: 'key'
        },
        11: {
          3: 'key'
        }
      }
    }, {
      t: 'Whichever cell it takes, box 1’s 3 lives in row 2. That claims row 2’s 3.',
      focus: [...BOX1, ...ROW(1)],
      pattern: [9, 11],
      cands: {
        9: {
          3: 'key'
        },
        11: {
          3: 'key'
        },
        13: {
          3: ''
        },
        16: {
          3: ''
        }
      }
    }, {
      t: 'So 3 can’t go anywhere else in row 2. Cross it off.',
      focus: [...BOX1, ...ROW(1)],
      pattern: [9, 11],
      cands: {
        9: {
          3: 'key'
        },
        11: {
          3: 'key'
        },
        13: {
          3: 'elim'
        },
        16: {
          3: 'elim'
        }
      }
    }, {
      t: 'The box points along a line. Its mirror image, Claiming, is when a line confines a digit to one box.',
      focus: [...BOX1, ...ROW(1)],
      pattern: [9, 11],
      cands: {
        9: {
          3: 'key'
        },
        11: {
          3: 'key'
        }
      }
    }],
    practice: 'medium'
  },
  'Naked Pair': {
    intro: 'When two cells in a unit can only be the same two digits, those digits are taken — even before you know which is which.',
    vals: G({
      36: 9,
      39: 1,
      42: 8
    }),
    steps: [{
      t: 'Row 5, with its candidates pencilled in.',
      focus: ROW(4),
      cands: {
        37: {
          2: '',
          7: ''
        },
        38: {
          2: '',
          4: '',
          7: ''
        },
        40: {
          2: '',
          7: ''
        },
        41: {
          3: '',
          4: '',
          5: '',
          7: ''
        },
        43: {
          3: '',
          6: ''
        },
        44: {
          2: '',
          4: '',
          5: '',
          6: ''
        }
      }
    }, {
      t: 'Two cells can only be 2 or 7. Between them, they’ll use both.',
      focus: ROW(4),
      pattern: [37, 40],
      cands: {
        37: {
          2: 'key',
          7: 'key'
        },
        38: {
          2: '',
          4: '',
          7: ''
        },
        40: {
          2: 'key',
          7: 'key'
        },
        41: {
          3: '',
          4: '',
          5: '',
          7: ''
        },
        43: {
          3: '',
          6: ''
        },
        44: {
          2: '',
          4: '',
          5: '',
          6: ''
        }
      }
    }, {
      t: 'So no other cell in row 5 can be 2 or 7. Cross them out.',
      focus: ROW(4),
      pattern: [37, 40],
      cands: {
        37: {
          2: 'key',
          7: 'key'
        },
        38: {
          2: 'elim',
          4: '',
          7: 'elim'
        },
        40: {
          2: 'key',
          7: 'key'
        },
        41: {
          3: '',
          4: '',
          5: '',
          7: 'elim'
        },
        43: {
          3: '',
          6: ''
        },
        44: {
          2: 'elim',
          4: '',
          5: '',
          6: ''
        }
      }
    }, {
      t: 'The third cell is left with only 4. A Naked Single drops out.',
      focus: ROW(4),
      pattern: [37, 40],
      target: 38,
      ghost: 4,
      cands: {
        37: {
          2: 'key',
          7: 'key'
        },
        40: {
          2: 'key',
          7: 'key'
        },
        41: {
          3: '',
          4: '',
          5: ''
        },
        43: {
          3: '',
          6: ''
        },
        44: {
          4: '',
          5: '',
          6: ''
        }
      }
    }],
    practice: 'hard'
  },
  'X-Wing': {
    intro: 'Your first “fish”. One digit, two lines, and a rectangle that locks it in place.',
    vals: G({
      9: 6,
      10: 1,
      12: 8,
      14: 2,
      15: 9,
      17: 5,
      54: 3,
      55: 9,
      57: 5,
      59: 7,
      60: 1,
      62: 8
    }),
    steps: [{
      t: 'Follow one digit: 4. In row 2 it has only two possible cells.',
      focus: ROW(1),
      cands: {
        11: {
          4: 'key'
        },
        16: {
          4: 'key'
        }
      }
    }, {
      t: 'Row 7 is the same — two cells, and in the same two columns.',
      focus: [...ROW(1), ...ROW(6)],
      cands: {
        11: {
          4: 'key'
        },
        16: {
          4: 'key'
        },
        56: {
          4: 'key'
        },
        61: {
          4: 'key'
        }
      }
    }, {
      t: 'Whichever way they fall, one 4 lands in each column at these corners. That’s the X.',
      focus: [...ROW(1), ...ROW(6)],
      pattern: [11, 16, 56, 61],
      cands: {
        11: {
          4: 'key'
        },
        16: {
          4: 'key'
        },
        56: {
          4: 'key'
        },
        61: {
          4: 'key'
        }
      }
    }, {
      t: 'So every other 4 in columns 3 and 8 can go.',
      focus: [...COLC(2), ...COLC(7)],
      pattern: [11, 16, 56, 61],
      cands: {
        11: {
          4: 'key'
        },
        16: {
          4: 'key'
        },
        56: {
          4: 'key'
        },
        61: {
          4: 'key'
        },
        29: {
          4: 'elim'
        },
        74: {
          4: 'elim'
        },
        43: {
          4: 'elim'
        },
        25: {
          4: 'elim'
        },
        32: {
          4: ''
        },
        48: {
          4: ''
        }
      }
    }],
    practice: 'expert'
  }
};
LESSONS['Full House'] = LESSONS['Naked Single'] = null;
function StatusDot({
  s
}) {
  if (s === 'mastered') return /*#__PURE__*/React.createElement("span", {
    style: {
      width: 12,
      height: 12,
      borderRadius: 6,
      background: 'var(--accent)'
    }
  });
  if (s === 'learning') return /*#__PURE__*/React.createElement("span", {
    style: {
      width: 12,
      height: 12,
      borderRadius: 6,
      boxShadow: 'inset 0 0 0 1.5px var(--accent)',
      background: 'linear-gradient(90deg, var(--accent) 50%, transparent 50%)'
    }
  });
  return /*#__PURE__*/React.createElement("span", {
    style: {
      width: 12,
      height: 12,
      borderRadius: 6,
      boxShadow: 'inset 0 0 0 1.5px var(--ink3)'
    }
  });
}
function LearnScreen({
  openNight,
  openLesson
}) {
  const used = TECHNIQUES.filter(t => t[3] !== 'new').length;
  return /*#__PURE__*/React.createElement("div", {
    className: "ps-scroll",
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 54,
      paddingBottom: 100
    }
  }, /*#__PURE__*/React.createElement(ScreenHead, {
    title: "Learn",
    openNight: openNight
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 22px 18px',
      fontSize: 14,
      color: 'var(--ink3)'
    }
  }, used, " of ", TECHNIQUES.length, " techniques in your hands"), /*#__PURE__*/React.createElement("button", {
    onClick: () => openLesson('Pointing'),
    className: "ps-card",
    style: {
      margin: '0 16px 28px',
      width: 'calc(100% - 32px)',
      padding: '16px 16px 16px 18px',
      textAlign: 'left',
      display: 'flex',
      gap: 14,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--ink3)'
    }
  }, "Up next \xB7 3 min"), /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 24,
      color: 'var(--ink)',
      margin: '4px 0 4px'
    }
  }, "Pointing"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--ink2)',
      textWrap: 'pretty'
    }
  }, "What unlocks Medium. You\u2019ve met it in 4 hints so far.")), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "chev"
  }))), TIER_NAMES.map((tier, ti) => /*#__PURE__*/React.createElement("div", {
    key: tier,
    style: {
      marginBottom: 22
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, null, tier), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '0 16px',
      borderTop: '1px solid var(--hair)'
    }
  }, TECHNIQUES.filter(t => t[1] === ti).map(([name,, short, st, seen]) => {
    const has = !!LESSONS[name];
    return /*#__PURE__*/React.createElement("button", {
      key: name,
      onClick: () => openLesson(name),
      style: {
        width: '100%',
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        padding: '12px 6px',
        borderBottom: '1px solid var(--hair)',
        textAlign: 'left'
      }
    }, /*#__PURE__*/React.createElement(StatusDot, {
      s: st
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        display: 'block',
        fontSize: 16,
        color: 'var(--ink)'
      }
    }, name), /*#__PURE__*/React.createElement("span", {
      style: {
        display: 'block',
        fontSize: 13,
        color: 'var(--ink3)',
        marginTop: 2
      }
    }, short)), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 12,
        color: 'var(--ink3)',
        whiteSpace: 'nowrap'
      }
    }, seen ? `${seen}×` : has ? 'Lesson' : ''));
  })))));
}
function LessonScreen({
  name,
  onBack,
  pal,
  onPractice,
  initialStep = 0
}) {
  const L = LESSONS[name],
    meta = TECHNIQUES.find(t => t[0] === name);
  const [k, setK] = useStL(initialStep);
  if (!L) {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        inset: 0,
        paddingTop: 54
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        height: 48,
        padding: '0 10px',
        display: 'flex',
        alignItems: 'center'
      }
    }, /*#__PURE__*/React.createElement("button", {
      className: "ps-icon",
      onClick: onBack
    }, /*#__PURE__*/React.createElement(Ico, {
      n: "back"
    }))), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '8px 24px'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 12,
        fontWeight: 600,
        letterSpacing: '.08em',
        textTransform: 'uppercase',
        color: 'var(--ink3)'
      }
    }, TIER_NAMES[meta[1]]), /*#__PURE__*/React.createElement("div", {
      className: "ps-serif",
      style: {
        fontSize: 34,
        color: 'var(--ink)',
        margin: '6px 0 10px'
      }
    }, name), /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 16,
        color: 'var(--ink2)',
        lineHeight: 1.45,
        textWrap: 'pretty'
      }
    }, meta[2]), /*#__PURE__*/React.createElement("div", {
      className: "ps-card",
      style: {
        marginTop: 24,
        padding: 16,
        fontSize: 14,
        color: 'var(--ink3)',
        lineHeight: 1.45
      }
    }, "Step-by-step lesson in progress. Uses the same lesson template as Hidden Single, Pointing, Naked Pair and X-Wing.")));
  }
  const s = L.steps[k],
    last = k === L.steps.length - 1;
  const marks = {
    spotlight: true,
    focus: new Set(s.focus || []),
    evidence: new Set(s.ev || []),
    elim: new Set(s.elim || []),
    pattern: new Set(s.pattern || []),
    target: s.target ?? -1,
    ghost: s.ghost || 0
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 54,
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 48,
      padding: '0 10px',
      display: 'flex',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: onBack,
    "aria-label": "Back"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "back"
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      textAlign: 'center',
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--ink3)'
    }
  }, TIER_NAMES[meta[1]], " \xB7 Lesson"), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 44
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '4px 24px 14px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 34,
      color: 'var(--ink)',
      lineHeight: 1.1
    }
  }, name), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      color: 'var(--ink2)',
      lineHeight: 1.4,
      marginTop: 8,
      textWrap: 'pretty'
    }
  }, L.intro)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(GridBoard, {
    vals: L.vals,
    givens: L.vals.map(Boolean),
    width: 342,
    type: pal.type,
    marks: marks,
    candMarks: s.cands
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '18px 24px 0',
      minHeight: 92,
      fontSize: 17,
      lineHeight: 1.4,
      color: 'var(--ink)',
      textWrap: 'pretty'
    }
  }, s.t), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '0 20px 44px'
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    disabled: !k,
    style: {
      opacity: k ? 1 : 0.3,
      boxShadow: 'inset 0 0 0 1px var(--hair)'
    },
    onClick: () => setK(k - 1),
    "aria-label": "Previous step"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "back"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      justifyContent: 'center',
      gap: 5
    }
  }, L.steps.map((_, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      width: i === k ? 16 : 6,
      height: 6,
      borderRadius: 3,
      background: i <= k ? 'var(--accent)' : 'var(--hair)'
    }
  }))), last ? /*#__PURE__*/React.createElement("button", {
    className: "ps-btn",
    onClick: () => onPractice(L.practice)
  }, "Practise") : /*#__PURE__*/React.createElement("button", {
    className: "ps-btn",
    onClick: () => setK(k + 1)
  }, "Next")));
}
Object.assign(window, {
  LearnScreen,
  LessonScreen,
  TECHNIQUES
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/Learn.jsx", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/NightSheet.jsx
try { (() => {
/* global React, Ico, Seg, Toggle, Row */
const {
  useState: useStN
} = React;
const PRESETS = [{
  k: 'lamp',
  l: 'Reading lamp',
  glow: 55,
  warmth: 45
}, {
  k: 'out',
  l: 'Lights out',
  glow: 18,
  warmth: 75
}, {
  k: 'red',
  l: 'Red light',
  glow: 10,
  warmth: 100
}];
function NightSheet({
  settings,
  setS,
  pal,
  onClose,
  initialCal
}) {
  const [cal, setCal] = useStN(!!initialCal);
  const night = settings.appearance !== 'day';
  const K = pal.kelvin || 6500;
  const N = window.PSNight;
  const warmTrack = `linear-gradient(90deg, ${[0, 25, 50, 75, 100].map(w => {
    const c = N.kelvinRGB(N.warmthToK(w)),
      s = (pal.s || 1) * 0.75;
    return `rgb(${c.map(x => Math.round(x * s)).join(',')})`;
  }).join(',')})`;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: 'absolute',
      inset: 0,
      zIndex: 60,
      background: night ? 'rgba(0,0,0,.55)' : 'rgba(40,30,10,.18)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      background: night ? 'var(--bg)' : 'var(--bg)',
      borderTop: '1px solid var(--hair)',
      borderRadius: '28px 28px 0 0',
      padding: '8px 0 34px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 5,
      borderRadius: 3,
      background: 'var(--hair)',
      margin: '0 auto 6px'
    }
  }), cal ? /*#__PURE__*/React.createElement(Calibrate, {
    settings: settings,
    setS: setS,
    done: () => setCal(false)
  }) : /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      padding: '4px 12px 10px 22px'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "ps-serif",
    style: {
      fontSize: 26,
      flex: 1,
      color: 'var(--ink)'
    }
  }, "Night"), /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: onClose,
    "aria-label": "Close"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "close",
    s: 20
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 22px 16px'
    }
  }, /*#__PURE__*/React.createElement(Seg, {
    value: settings.appearance === 'system' ? 'day' : settings.appearance,
    onChange: v => setS({
      appearance: v
    }),
    options: [['day', 'Day'], ['night', 'Night'], ['auto', 'After dark']]
  }), settings.appearance === 'auto' && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)',
      marginTop: 8
    }
  }, "Night from sunset (6:12 PM) to sunrise, worked out on this iPhone. Without location: 9:00 PM to 6:30 AM.")), night && /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      padding: '0 22px 18px'
    }
  }, PRESETS.map(p => {
    const on = Math.abs(settings.glow - p.glow) < 3 && Math.abs(settings.warmth - p.warmth) < 3;
    return /*#__PURE__*/React.createElement("button", {
      key: p.k,
      onClick: () => setS({
        glow: p.glow,
        warmth: p.warmth
      }),
      style: {
        flex: 1,
        height: 36,
        borderRadius: 18,
        fontSize: 13,
        fontWeight: 500,
        color: on ? 'var(--accent)' : 'var(--ink2)',
        boxShadow: `inset 0 0 0 1.5px ${on ? 'var(--accentDim)' : 'var(--hair)'}`
      }
    }, p.l);
  })), /*#__PURE__*/React.createElement(SliderRow, {
    label: "Glow",
    value: `${settings.glow}%`,
    sub: settings.glow < 35 ? 'Below your iPhone’s lowest brightness.' : 'How much light the screen gives off.'
  }, /*#__PURE__*/React.createElement("input", {
    className: "ps-range",
    type: "range",
    min: "0",
    max: "100",
    value: settings.glow,
    onChange: e => setS({
      glow: +e.target.value
    }),
    "aria-label": "Glow"
  })), /*#__PURE__*/React.createElement(SliderRow, {
    label: "Warmth",
    value: `${K.toLocaleString()} K`,
    sub: `Blue light about ${pal.blueCut}% lower than daylight white.`
  }, /*#__PURE__*/React.createElement("input", {
    className: "ps-range",
    type: "range",
    min: "0",
    max: "100",
    value: settings.warmth,
    onChange: e => setS({
      warmth: +e.target.value
    }),
    "aria-label": "Warmth",
    style: {
      '--track': warmTrack
    }
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '4px 22px 14px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      marginBottom: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 16,
      color: 'var(--ink)',
      flex: 1
    }
  }, "Clarity")), /*#__PURE__*/React.createElement(Seg, {
    value: settings.clarity,
    onChange: v => setS({
      clarity: v
    }),
    options: [[0, 'Standard'], [1, 'Large'], [2, 'Bold']]
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)',
      marginTop: 8,
      textWrap: 'pretty'
    }
  }, "Bigger, heavier digits and stronger lines. Readable at lower glow.")), night && /*#__PURE__*/React.createElement("div", {
    style: {
      borderTop: '1px solid var(--hair)',
      margin: '4px 0 0'
    }
  }, /*#__PURE__*/React.createElement(Row, {
    label: "Drift",
    sub: "Over 30 minutes, glow eases down and warmth eases up."
  }, /*#__PURE__*/React.createElement(Toggle, {
    on: settings.drift,
    onChange: v => setS({
      drift: v
    }),
    label: "Drift"
  })), /*#__PURE__*/React.createElement(Row, {
    label: "Find my lowest glow",
    sub: "A 20-second check of what your eyes can read tonight.",
    last: true
  }, /*#__PURE__*/React.createElement("button", {
    onClick: () => setCal(true),
    style: {
      color: 'var(--accent)',
      fontSize: 15,
      fontWeight: 500
    }
  }, "Start"))))));
}
function SliderRow({
  label,
  value,
  sub,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 22px 16px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 16,
      color: 'var(--ink)',
      flex: 1
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      color: 'var(--ink2)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, value)), children, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)'
    }
  }, sub));
}
function Calibrate({
  settings,
  setS,
  done,
  initialPick = null,
  first
}) {
  const N = window.PSNight,
    levels = [0, 6, 14, 24, 38, 56];
  const [pick, setPick] = useStN(initialPick);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '6px 22px 8px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 24,
      color: 'var(--ink)'
    }
  }, "Which is the faintest you can read?"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--ink3)',
      margin: '6px 0 22px',
      textWrap: 'pretty'
    }
  }, "Give your eyes a moment in the dark first. Tap the dimmest digit you can read without effort."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(6,1fr)',
      gap: 8
    }
  }, levels.map((g, i) => {
    const ink = N.palette({
      ...settings,
      appearance: 'night',
      glow: g
    }).vars['--ink'];
    return /*#__PURE__*/React.createElement("button", {
      key: g,
      onClick: () => setPick(g),
      style: {
        height: 76,
        borderRadius: 12,
        boxShadow: `inset 0 0 0 ${pick === g ? 2 : 1}px ${pick === g ? 'var(--accent)' : 'var(--hair)'}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 30,
        color: ink,
        fontWeight: 500
      }
    }, [8, 3, 6, 5, 9, 2][i]));
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'flex-end',
      gap: 10,
      marginTop: 22
    }
  }, !first && /*#__PURE__*/React.createElement("button", {
    className: "ps-btn ps-btn-ghost",
    onClick: done
  }, "Cancel"), /*#__PURE__*/React.createElement("button", {
    className: "ps-btn",
    disabled: pick === null,
    style: {
      opacity: pick === null ? 0.4 : 1
    },
    onClick: () => {
      setS({
        glow: Math.min(100, pick + 4),
        glowFloor: pick,
        calibrated: true
      });
      done();
    }
  }, "Use this")));
}
Object.assign(window, {
  NightSheet,
  Calibrate,
  SliderRow,
  PRESETS
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/NightSheet.jsx", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/Primitives.jsx
try { (() => {
/* global React */
// Shared primitives: icons, phone frame, board, keypad, tool row.
const PSI = {
  undo: 'M9 14 4 9l5-5M4 9h10.5a5.5 5.5 0 0 1 0 11H11',
  erase: 'M7 21h10M5.6 15.4l7.8-7.8a2 2 0 0 1 2.8 0l2.2 2.2a2 2 0 0 1 0 2.8L13 18H8.2a2 2 0 0 1-1.4-.6l-1.2-1.2a.8.8 0 0 1 0-.8ZM10 10l5 5',
  pencil: 'M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z',
  hint: 'M9 18h6M10 22h4M12 2a7 7 0 0 0-4 12.7V16h8v-1.3A7 7 0 0 0 12 2Z',
  moon: 'M20.5 14.5A8.5 8.5 0 0 1 9.5 3.5a8.5 8.5 0 1 0 11 11Z',
  back: 'M15 18l-6-6 6-6',
  more: 'M5 12h.01M12 12h.01M19 12h.01',
  pause: 'M9 6v12M15 6v12',
  play: 'M8 5v14l11-7Z',
  grid: 'M4 4h16v16H4zM4 9.3h16M4 14.6h16M9.3 4v16M14.6 4v16',
  book: 'M4 19.5V5a2 2 0 0 1 2-2h13v16H6.5A2.5 2.5 0 0 0 4 21.5ZM19 19v3H6.5',
  journal: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
  camera: 'M3 8h3l2-3h8l2 3h3v12H3ZM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  close: 'M6 6l12 12M18 6 6 18',
  chev: 'M9 6l6 6-6 6',
  eye: 'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12ZM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z'
};
function Ico({
  n,
  s = 22,
  c = 'currentColor',
  w = 1.7,
  fill
}) {
  return /*#__PURE__*/React.createElement("svg", {
    width: s,
    height: s,
    viewBox: "0 0 24 24",
    fill: fill || 'none',
    stroke: c,
    strokeWidth: w,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: {
      flexShrink: 0,
      display: 'block'
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: PSI[n]
  }));
}
function PhoneFrame({
  children,
  hideStatus,
  dimChrome
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 414,
      height: 868,
      borderRadius: 66,
      padding: 12,
      boxSizing: 'border-box',
      background: '#0a0a0a',
      boxShadow: '0 0 0 1.5px #2a2a2a, 0 30px 80px rgba(0,0,0,.5)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ps-screen",
    style: {
      width: 390,
      height: 844,
      borderRadius: 54,
      overflow: 'hidden',
      position: 'relative',
      background: 'var(--bg)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 11,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 122,
      height: 35,
      borderRadius: 20,
      background: '#000',
      zIndex: 80
    }
  }), !hideStatus && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      height: 54,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '4px 34px 0 44px',
      zIndex: 70,
      color: 'var(--status)',
      fontSize: 16,
      fontWeight: 600,
      pointerEvents: 'none'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontVariantNumeric: 'tabular-nums'
    }
  }, "11:42"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      gap: 6,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "18",
    height: "12",
    viewBox: "0 0 18 12",
    fill: "currentColor"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0",
    y: "8",
    width: "3",
    height: "4",
    rx: "1"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "5",
    y: "5.5",
    width: "3",
    height: "6.5",
    rx: "1"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "10",
    y: "3",
    width: "3",
    height: "9",
    rx: "1"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "15",
    y: "0",
    width: "3",
    height: "12",
    rx: "1"
  })), /*#__PURE__*/React.createElement("svg", {
    width: "26",
    height: "12",
    viewBox: "0 0 26 12",
    fill: "none",
    stroke: "currentColor"
  }, /*#__PURE__*/React.createElement("rect", {
    x: ".5",
    y: ".5",
    width: "22",
    height: "11",
    rx: "3.5",
    opacity: ".5"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "2.5",
    y: "2.5",
    width: "12",
    height: "7",
    rx: "1.8",
    fill: "currentColor",
    stroke: "none"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M24.5 4v4",
    opacity: ".5"
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0
    }
  }, children), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 8,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 134,
      height: 5,
      borderRadius: 3,
      background: 'var(--ink3)',
      opacity: dimChrome ? 0.35 : 0.9,
      zIndex: 90,
      pointerEvents: 'none'
    }
  })));
}

// Board. marks: { focus:Set, evidence:Set, pattern:Set, elim:Set, target:idx, ghost:digit, spotlight:bool }
// candMarks (lessons): { [cell]: { [digit]: 'key'|'elim' } }
function GridBoard({
  vals,
  givens,
  notes,
  sel = -1,
  width = 366,
  type,
  marks = {},
  errors,
  candMarks,
  onSelect,
  showPeers = true
}) {
  const E = window.PSEngine,
    cs = (width - 8) / 9;
  const lw = Math.max(1, Math.round(type.line)),
    mj = 2 + Math.round(type.line) - 1;
  const sv = sel >= 0 ? vals[sel] : 0;
  const cell = i => {
    const v = vals[i],
      g = givens && givens[i];
    const isSel = i === sel;
    const peer = showPeers && sel >= 0 && !isSel && (E.ROW(i) === E.ROW(sel) || E.COL(i) === E.COL(sel) || E.BOX(i) === E.BOX(sel));
    const same = sv && v === sv && !isSel;
    const m = marks;
    const inFocus = !m.spotlight || m.focus && m.focus.has(i);
    let bg = 'var(--bg)';
    if (m.pattern && m.pattern.has(i)) bg = 'var(--same)';else if (isSel) bg = 'var(--sel)';else if (same) bg = 'var(--same)';else if (peer && !m.spotlight) bg = 'var(--peer)';
    const shadows = [];
    if (isSel) shadows.push('inset 0 0 0 2px var(--accent)');
    if (m.evidence && m.evidence.has(i)) shadows.push('inset 0 0 0 1.5px var(--accent)');
    const err = errors && errors.has(i);
    const cm = candMarks && candMarks[i];
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      onClick: () => onSelect && onSelect(i),
      style: {
        background: bg,
        boxShadow: shadows.join(','),
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: onSelect ? 'pointer' : 'default'
      }
    }, m.target === i && /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        inset: 3,
        border: '1.5px dashed var(--accent)',
        borderRadius: 4
      }
    }), m.elim && m.elim.has(i) && /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        inset: 4,
        border: '1px dotted var(--ink3)',
        borderRadius: 4
      }
    }), v ? /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: cs * 0.6 * type.digit,
        lineHeight: 1,
        fontWeight: g ? type.given : type.user,
        color: err ? 'var(--err)' : g ? 'var(--ink)' : 'var(--accent)',
        opacity: inFocus ? 1 : 'var(--focusDim)',
        fontVariantNumeric: 'tabular-nums',
        position: 'relative'
      }
    }, v, err && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        left: '-10%',
        right: '-10%',
        bottom: -cs * 0.1,
        height: 2,
        borderRadius: 1,
        background: 'var(--err)'
      }
    })) : m.target === i && m.ghost ? /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: cs * 0.6 * type.digit,
        lineHeight: 1,
        fontWeight: type.user,
        color: 'var(--accent)',
        opacity: 0.55
      }
    }, m.ghost) : notes && notes[i] || cm ? /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        inset: cs * 0.06,
        display: 'grid',
        gridTemplateColumns: 'repeat(3,1fr)',
        gridTemplateRows: 'repeat(3,1fr)',
        opacity: inFocus ? 1 : 'var(--focusDim)'
      }
    }, [1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => {
      const on = cm ? d in cm : notes[i] & 1 << d;
      const st = cm && cm[d];
      const hot = !cm && sv === d;
      return /*#__PURE__*/React.createElement("span", {
        key: d,
        style: {
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: cs * 0.25 * type.cand,
          lineHeight: 1,
          fontWeight: st === 'key' || hot ? 700 : 500,
          color: st === 'key' || hot ? 'var(--accent)' : st === 'elim' ? 'var(--ink3)' : 'var(--ink2)',
          textDecoration: st === 'elim' ? 'line-through' : 'none',
          textDecorationColor: 'var(--err)',
          textDecorationThickness: 1.5
        }
      }, on ? d : '');
    })) : null);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      height: width,
      boxSizing: 'border-box',
      padding: mj,
      background: 'var(--lineMajor)',
      borderRadius: 6,
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      gridTemplateRows: 'repeat(3,1fr)',
      gap: mj
    }
  }, [0, 1, 2, 3, 4, 5, 6, 7, 8].map(b => /*#__PURE__*/React.createElement("div", {
    key: b,
    style: {
      background: 'var(--line)',
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      gridTemplateRows: 'repeat(3,1fr)',
      gap: lw
    }
  }, E.UNITS[18 + b].map(cell))));
}
function Keypad({
  onDigit,
  notesMode,
  remaining,
  type
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(9,1fr)',
      gap: 4
    }
  }, [1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => {
    const done = remaining[d] <= 0;
    const pos = {
      r: Math.floor((d - 1) / 3),
      c: (d - 1) % 3
    };
    return /*#__PURE__*/React.createElement("button", {
      key: d,
      className: "ps-key",
      disabled: done,
      onClick: () => onDigit(d),
      style: {
        height: 64,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 3,
        opacity: done ? 0.28 : 1
      }
    }, notesMode ? /*#__PURE__*/React.createElement("span", {
      style: {
        width: 30,
        height: 30,
        display: 'grid',
        gridTemplateColumns: 'repeat(3,1fr)',
        gridTemplateRows: 'repeat(3,1fr)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        gridColumn: pos.c + 1,
        gridRow: pos.r + 1,
        fontSize: 13 * type.cand,
        fontWeight: 700,
        color: 'var(--accent)',
        lineHeight: 1,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }
    }, d)) : /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 30 * type.ui,
        fontWeight: 400,
        color: 'var(--ink)',
        lineHeight: 1,
        height: 30,
        display: 'flex',
        alignItems: 'center'
      }
    }, d), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 10.5,
        color: 'var(--ink3)',
        fontVariantNumeric: 'tabular-nums',
        fontWeight: 500
      }
    }, done ? '' : remaining[d]));
  }));
}
function ToolBtn({
  icon,
  label,
  onClick,
  active,
  disabled,
  badge
}) {
  return /*#__PURE__*/React.createElement("button", {
    className: "ps-tool",
    onClick: onClick,
    disabled: disabled,
    style: {
      color: active ? 'var(--accent)' : 'var(--ink2)',
      opacity: disabled ? 0.35 : 1
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: icon,
    s: 23
  }), badge && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: -5,
      right: -12,
      fontSize: 9,
      fontWeight: 700,
      padding: '1px 4px',
      borderRadius: 6,
      background: active ? 'var(--accent)' : 'var(--surface2)',
      color: active ? 'var(--bg)' : 'var(--ink2)',
      letterSpacing: '.02em'
    }
  }, badge)), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: 500
    }
  }, label));
}
Object.assign(window, {
  Ico,
  PhoneFrame,
  GridBoard,
  Keypad,
  ToolBtn
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/Primitives.jsx", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/Screens.jsx
try { (() => {
/* global React, GridBoard, Ico, fmtTime, LEVEL_NAMES */
const LEVELS = [{
  k: 'easy',
  ceil: 'Singles only',
  n: 1
}, {
  k: 'medium',
  ceil: 'Pointing & claiming',
  n: 2
}, {
  k: 'hard',
  ceil: 'Pairs & triples',
  n: 3
}, {
  k: 'expert',
  ceil: 'Wings & fish',
  n: 4
}, {
  k: 'master',
  ceil: 'Chains & beyond',
  n: 5
}];
function TabBar({
  tab,
  setTab
}) {
  const items = [['play', 'Play', 'grid'], ['learn', 'Learn', 'book'], ['journal', 'Journal', 'journal']];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      height: 84,
      borderTop: '1px solid var(--hair)',
      background: 'var(--bg)',
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      paddingTop: 8,
      zIndex: 20
    }
  }, items.map(([k, l, ic]) => /*#__PURE__*/React.createElement("button", {
    key: k,
    onClick: () => setTab(k),
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 4,
      color: tab === k ? 'var(--accent)' : 'var(--ink3)'
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: ic,
    s: 22,
    w: tab === k ? 2 : 1.6
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: tab === k ? 600 : 500
    }
  }, l))));
}
function ScreenHead({
  title,
  openNight,
  right
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      padding: '0 12px 0 22px',
      height: 52
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "ps-serif",
    style: {
      fontSize: 30,
      color: 'var(--ink)',
      flex: 1
    }
  }, title), right, /*#__PURE__*/React.createElement("button", {
    className: "ps-icon",
    onClick: openNight,
    "aria-label": "Night settings"
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "moon"
  })));
}
function SectionLabel({
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--ink3)',
      padding: '0 22px 8px',
      ...style
    }
  }, children);
}
function HomeScreen({
  games,
  onPlay,
  openNight,
  pal,
  stats
}) {
  const live = Object.values(games).filter(g => g && !g.done).sort((a, b) => (b.touched || 0) - (a.touched || 0))[0];
  const filled = live ? live.vals.filter(Boolean).length : 0;
  return /*#__PURE__*/React.createElement("div", {
    className: "ps-scroll",
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 54,
      paddingBottom: 96
    }
  }, /*#__PURE__*/React.createElement(ScreenHead, {
    title: "Pure Sudoku",
    openNight: openNight
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 22px 20px',
      fontSize: 14,
      color: 'var(--ink3)'
    }
  }, "Saturday night \xB7 ", stats.streak, "-night streak"), live && /*#__PURE__*/React.createElement("button", {
    onClick: () => onPlay(live.diff),
    className: "ps-card",
    style: {
      margin: '0 16px 26px',
      width: 'calc(100% - 32px)',
      padding: 14,
      display: 'flex',
      gap: 16,
      alignItems: 'center',
      textAlign: 'left'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      pointerEvents: 'none'
    }
  }, /*#__PURE__*/React.createElement(GridBoard, {
    vals: live.vals,
    givens: live.start.map(Boolean),
    width: 112,
    type: {
      ...pal.type,
      digit: 1,
      line: 1
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--ink3)'
    }
  }, "Continue"), /*#__PURE__*/React.createElement("span", {
    className: "ps-serif",
    style: {
      fontSize: 24,
      color: 'var(--ink)'
    }
  }, LEVEL_NAMES[live.diff]), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 14,
      color: 'var(--ink2)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, fmtTime(live.elapsed), " \xB7 ", filled, " of 81"), /*#__PURE__*/React.createElement("span", {
    style: {
      height: 3,
      borderRadius: 2,
      background: 'var(--hair)',
      marginTop: 4,
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      height: '100%',
      width: `${filled / 81 * 100}%`,
      background: 'var(--accentDim)'
    }
  })))), /*#__PURE__*/React.createElement(SectionLabel, null, "New puzzle"), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '0 16px',
      borderTop: '1px solid var(--hair)'
    }
  }, LEVELS.map(L => /*#__PURE__*/React.createElement("button", {
    key: L.k,
    onClick: () => onPlay(L.k, true),
    style: {
      width: '100%',
      display: 'flex',
      alignItems: 'center',
      gap: 14,
      padding: '0 6px',
      height: 64,
      borderBottom: '1px solid var(--hair)',
      textAlign: 'left'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      gap: 3,
      alignItems: 'flex-end',
      width: 26
    }
  }, [1, 2, 3, 4, 5].map(n => /*#__PURE__*/React.createElement("span", {
    key: n,
    style: {
      width: 3,
      height: 4 + n * 2.6,
      borderRadius: 1,
      background: n <= L.n ? 'var(--accent)' : 'var(--hair)'
    }
  }))), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      gap: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 17,
      color: 'var(--ink)',
      fontWeight: 500
    }
  }, LEVEL_NAMES[L.k]), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)'
    }
  }, L.ceil)), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, stats.best[L.k] ? `Best ${fmtTime(stats.best[L.k])}` : ''), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--ink3)'
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "chev",
    s: 16
  }))))), /*#__PURE__*/React.createElement("button", {
    style: {
      margin: '18px 22px 0',
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      color: 'var(--ink2)',
      fontSize: 15,
      height: 44
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "camera",
    s: 20
  }), "Import a puzzle from a photo"));
}
function Toggle({
  on,
  onChange,
  label
}) {
  return /*#__PURE__*/React.createElement("button", {
    role: "switch",
    "aria-checked": on,
    "aria-label": label,
    className: "ps-tog",
    "data-on": on ? '1' : '0',
    onClick: () => onChange(!on)
  }, /*#__PURE__*/React.createElement("span", null));
}
function Seg({
  value,
  options,
  onChange
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "ps-seg"
  }, options.map(([v, l]) => /*#__PURE__*/React.createElement("button", {
    key: v,
    "aria-pressed": value === v,
    onClick: () => onChange(v)
  }, l)));
}
function Row({
  label,
  sub,
  children,
  last
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '12px 16px',
      minHeight: 52,
      boxSizing: 'border-box',
      borderBottom: last ? 'none' : '1px solid var(--hair)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      color: 'var(--ink)'
    }
  }, label), sub && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)',
      marginTop: 2,
      textWrap: 'pretty'
    }
  }, sub)), children);
}
function JournalScreen({
  stats,
  settings,
  setS,
  openNight,
  onOpenDisplay
}) {
  const week = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return /*#__PURE__*/React.createElement("div", {
    className: "ps-scroll",
    style: {
      position: 'absolute',
      inset: 0,
      paddingTop: 54,
      paddingBottom: 100
    }
  }, /*#__PURE__*/React.createElement(ScreenHead, {
    title: "Journal",
    openNight: openNight
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '6px 22px 26px',
      display: 'flex',
      alignItems: 'flex-end',
      gap: 18
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    className: "ps-serif",
    style: {
      fontSize: 56,
      lineHeight: 1,
      color: 'var(--ink)'
    }
  }, stats.streak), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--ink3)',
      marginTop: 4
    }
  }, "nights in a row")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'grid',
      gridTemplateColumns: 'repeat(7,1fr)',
      gap: 4,
      paddingBottom: 4
    }
  }, week.map((d, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 10,
      height: 10,
      borderRadius: 5,
      background: i < 6 ? 'var(--accent)' : 'transparent',
      boxShadow: i < 6 ? 'none' : 'inset 0 0 0 1.5px var(--ink3)'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--ink3)'
    }
  }, d))))), /*#__PURE__*/React.createElement(SectionLabel, null, "Solved"), /*#__PURE__*/React.createElement("div", {
    className: "ps-card",
    style: {
      margin: '0 16px 26px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 60px 70px 70px',
      padding: '10px 16px',
      fontSize: 12,
      color: 'var(--ink3)',
      borderBottom: '1px solid var(--hair)'
    }
  }, /*#__PURE__*/React.createElement("span", null), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: 'right'
    }
  }, "Solved"), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: 'right'
    }
  }, "Best"), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: 'right'
    }
  }, "Typical")), LEVELS.map((L, i) => /*#__PURE__*/React.createElement("div", {
    key: L.k,
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 60px 70px 70px',
      padding: '12px 16px',
      fontSize: 15,
      color: 'var(--ink2)',
      fontVariantNumeric: 'tabular-nums',
      borderBottom: i < 4 ? '1px solid var(--hair)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--ink)'
    }
  }, LEVEL_NAMES[L.k]), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: 'right'
    }
  }, stats.solved[L.k] || '—'), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: 'right'
    }
  }, stats.best[L.k] ? fmtTime(stats.best[L.k]) : '—'), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: 'right'
    }
  }, stats.typical[L.k] ? fmtTime(stats.typical[L.k]) : '—'))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '10px 16px',
      fontSize: 13,
      color: 'var(--ink3)',
      borderTop: '1px solid var(--hair)'
    }
  }, stats.assisted || 0, " assisted solves kept your streak but don\u2019t set best times.")), /*#__PURE__*/React.createElement(SectionLabel, null, "Settings"), /*#__PURE__*/React.createElement("div", {
    className: "ps-card",
    style: {
      margin: '0 16px 26px'
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onOpenDisplay,
    style: {
      width: '100%',
      textAlign: 'left'
    }
  }, /*#__PURE__*/React.createElement(Row, {
    label: "Display & Night",
    sub: "Day, Night, glow, warmth, clarity, quiet",
    last: true
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--ink3)'
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    n: "chev",
    s: 16
  }))))), /*#__PURE__*/React.createElement(SectionLabel, null, "Assists"), /*#__PURE__*/React.createElement("div", {
    className: "ps-card",
    style: {
      margin: '0 16px 26px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '12px 16px',
      borderBottom: '1px solid var(--hair)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      color: 'var(--ink)',
      marginBottom: 10
    }
  }, "Show mistakes"), /*#__PURE__*/React.createElement(Seg, {
    value: settings.mistakes,
    onChange: v => setS({
      mistakes: v
    }),
    options: [['immediate', 'Right away'], ['check', 'When I check'], ['never', 'Never']]
  })), /*#__PURE__*/React.createElement(Row, {
    label: "Tidy notes",
    sub: "Placing a digit removes it from notes in the same row, column and box."
  }, /*#__PURE__*/React.createElement(Toggle, {
    on: settings.autoRemove,
    onChange: v => setS({
      autoRemove: v
    }),
    label: "Tidy notes"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '12px 16px',
      borderBottom: '1px solid var(--hair)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 16,
      color: 'var(--ink)',
      marginBottom: 10
    }
  }, "Cell names in hints"), /*#__PURE__*/React.createElement(Seg, {
    value: settings.notation || 'plain',
    onChange: v => setS({
      notation: v
    }),
    options: [['plain', 'row 5, column 2'], ['grid', 'R5C2']]
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--ink3)',
      marginTop: 8
    }
  }, settings.notation === 'grid' ? 'Short grid codes: R for row, C for column, B for box.' : 'Written out in words.')), /*#__PURE__*/React.createElement(Row, {
    label: "Show timer",
    last: true
  }, /*#__PURE__*/React.createElement(Toggle, {
    on: settings.showTimer,
    onChange: v => setS({
      showTimer: v
    }),
    label: "Show timer"
  }))), /*#__PURE__*/React.createElement(SectionLabel, null, "Privacy"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 22px',
      fontSize: 14,
      lineHeight: 1.5,
      color: 'var(--ink3)',
      textWrap: 'pretty'
    }
  }, "Everything stays on this iPhone. No account, no network, no analytics. Silent by design \u2014 no sounds or vibration unless you turn them on."));
}
Object.assign(window, {
  HomeScreen,
  JournalScreen,
  TabBar,
  ScreenHead,
  SectionLabel,
  Toggle,
  Seg,
  Row,
  LEVELS
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/Screens.jsx", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/engine.js
try { (() => {
// PureSudoku prototype engine: solver, candidates, and a human-style hint finder.
// Mirrors HINT_STRATEGIES.md ordering (singles -> locked candidates -> naked pairs -> fallback).
(function () {
  const ROW = i => Math.floor(i / 9),
    COL = i => i % 9,
    BOX = i => Math.floor(ROW(i) / 3) * 3 + Math.floor(COL(i) / 3);
  const UNITS = [];
  for (let r = 0; r < 9; r++) UNITS.push([...Array(9)].map((_, c) => r * 9 + c));
  for (let c = 0; c < 9; c++) UNITS.push([...Array(9)].map((_, r) => r * 9 + c));
  for (let b = 0; b < 9; b++) {
    const r0 = Math.floor(b / 3) * 3,
      c0 = b % 3 * 3,
      u = [];
    for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) u.push((r0 + r) * 9 + c0 + c);
    UNITS.push(u);
  }
  const PEERS = [...Array(81)].map((_, i) => {
    const s = new Set([...UNITS[ROW(i)], ...UNITS[9 + COL(i)], ...UNITS[18 + BOX(i)]]);
    s.delete(i);
    return [...s];
  });
  let NOTATION = 'plain';
  const setNotation = n => {
    NOTATION = n === 'grid' ? 'grid' : 'plain';
  };
  const unitName = u => NOTATION === 'grid' ? u < 9 ? `R${u + 1}` : u < 18 ? `C${u - 8}` : `B${u - 17}` : u < 9 ? `row ${u + 1}` : u < 18 ? `column ${u - 8}` : `box ${u - 17}`;
  const cellName = i => NOTATION === 'grid' ? `R${ROW(i) + 1}C${COL(i) + 1}` : `row ${ROW(i) + 1}, column ${COL(i) + 1}`;
  const boxName = b => NOTATION === 'grid' ? `B${b + 1}` : `box ${b + 1}`;
  const pop = m => {
    let c = 0;
    while (m) {
      m &= m - 1;
      c++;
    }
    return c;
  };
  const bits = m => {
    const a = [];
    for (let d = 1; d <= 9; d++) if (m & 1 << d) a.push(d);
    return a;
  };
  const parse = s => [...s].map(ch => ch >= '1' && ch <= '9' ? +ch : 0);
  function candMask(v, i) {
    if (v[i]) return 0;
    let m = 0x3FE;
    for (const p of PEERS[i]) if (v[p]) m &= ~(1 << v[p]);
    return m;
  }
  function solve(vals) {
    const g = vals.slice();
    function rec() {
      let best = -1,
        bm = 0,
        bc = 10;
      for (let i = 0; i < 81; i++) if (!g[i]) {
        const m = candMask(g, i),
          c = pop(m);
        if (!c) return false;
        if (c < bc) {
          bc = c;
          best = i;
          bm = m;
          if (c === 1) break;
        }
      }
      if (best < 0) return true;
      for (const d of bits(bm)) {
        g[best] = d;
        if (rec()) return true;
      }
      g[best] = 0;
      return false;
    }
    return rec() ? g : null;
  }
  const TECH = {
    'Full House': {
      tier: 0,
      short: 'A row, column or box with one empty cell left.'
    },
    'Naked Single': {
      tier: 0,
      short: 'A cell that can only hold one digit.'
    },
    'Hidden Single': {
      tier: 0,
      short: 'A digit with only one possible home in a row, column or box.'
    },
    'Pointing': {
      tier: 1,
      short: 'In a box, a digit is confined to one line, so it leaves the rest of that line.'
    },
    'Claiming': {
      tier: 1,
      short: 'In a line, a digit is confined to one box, so it leaves the rest of that box.'
    },
    'Naked Pair': {
      tier: 1,
      short: 'Two cells share the same two candidates, so no other cell in the unit can use them.'
    }
  };
  function blockerFor(v, i, d) {
    for (const p of PEERS[i]) if (v[p] === d) return p;
    return -1;
  }
  function singles(v, cm, via) {
    // Full house
    if (!via) for (let u = 0; u < 27; u++) {
      const empt = UNITS[u].filter(i => !v[i]);
      if (empt.length === 1) {
        const have = new Set(UNITS[u].map(i => v[i]));
        let d = 1;
        while (have.has(d)) d++;
        return mk('Full House', empt[0], d, u, UNITS[u], [], `Look at ${unitName(u)}.`, `${cap(unitName(u))} has one empty cell left, and the only digit missing is ${d}.`);
      }
    }
    // Hidden singles — boxes first (how people scan), then rows, then columns
    for (const u of [...range(18, 27), ...range(0, 18)]) {
      for (let d = 1; d <= 9; d++) {
        if (UNITS[u].some(i => v[i] === d)) continue;
        const spots = UNITS[u].filter(i => cm[i] & 1 << d);
        if (spots.length !== 1) continue;
        const t = spots[0];
        const ev = new Set();
        UNITS[u].forEach(i => {
          if (!v[i] && i !== t) {
            const b = blockerFor(v, i, d);
            if (b >= 0) ev.add(b);
          }
        });
        const why = via ? `${via.why} With that removed, ${d} has only one home left in ${unitName(u)}.` : `Every other empty cell in ${unitName(u)} already sees ${d === 8 ? "an" : "a"} ${d}. So ${d} can only go in ${cellName(t)}.`;
        return mk(via ? via.technique : 'Hidden Single', t, d, u, UNITS[u], [...ev], `Look at ${unitName(u)}. Where can ${d} go?`, why, via);
      }
    }
    // Naked single
    for (let i = 0; i < 81; i++) if (!v[i] && pop(cm[i]) === 1) {
      const d = bits(cm[i])[0];
      const seen = {};
      PEERS[i].forEach(p => {
        if (v[p] && v[p] !== d && seen[v[p]] === undefined) seen[v[p]] = p;
      });
      const why = via ? `${via.why} That leaves ${cellName(i)} with a single candidate: ${d}.` : `${cap(cellName(i))} already sees ${Object.keys(seen).sort().join(', ')} in its row, column and box. Only ${d} is left.`;
      return mk(via ? via.technique : 'Naked Single', i, d, 18 + BOX(i), [...new Set([...UNITS[ROW(i)], ...UNITS[9 + COL(i)], ...UNITS[18 + BOX(i)]])], Object.values(seen), `One cell in ${boxName(BOX(i))} is nearly decided.`, why, via);
    }
    return null;
  }
  function locked(v, cm) {
    for (let b = 18; b < 27; b++) for (let d = 1; d <= 9; d++) {
      const cells = UNITS[b].filter(i => cm[i] & 1 << d);
      if (cells.length < 2) continue;
      for (const [kind, f, off] of [['row', ROW, 0], ['col', COL, 9]]) {
        const lines = new Set(cells.map(f));
        if (lines.size !== 1) continue;
        const line = off + [...lines][0];
        const el = UNITS[line].filter(i => BOX(i) !== b - 18 && cm[i] & 1 << d);
        if (el.length) {
          el.forEach(i => cm[i] &= ~(1 << d));
          return {
            technique: 'Pointing',
            pattern: cells,
            elim: el,
            digit: d,
            why: `In ${boxName(b - 18)}, every ${d} sits in ${unitName(line)}, so ${d} leaves the rest of that ${kind === 'row' ? 'row' : 'column'}.`
          };
        }
      }
    }
    for (let u = 0; u < 18; u++) for (let d = 1; d <= 9; d++) {
      const cells = UNITS[u].filter(i => cm[i] & 1 << d);
      if (cells.length < 2) continue;
      const boxes = new Set(cells.map(BOX));
      if (boxes.size !== 1) continue;
      const b = [...boxes][0];
      const el = UNITS[18 + b].filter(i => !UNITS[u].includes(i) && cm[i] & 1 << d);
      if (el.length) {
        el.forEach(i => cm[i] &= ~(1 << d));
        return {
          technique: 'Claiming',
          pattern: cells,
          elim: el,
          digit: d,
          why: `In ${unitName(u)}, every ${d} sits inside ${boxName(b)}, so ${d} leaves the rest of that box.`
        };
      }
    }
    return null;
  }
  function nakedPair(v, cm) {
    for (let u = 0; u < 27; u++) {
      const two = UNITS[u].filter(i => pop(cm[i]) === 2);
      for (let a = 0; a < two.length; a++) for (let b = a + 1; b < two.length; b++) {
        if (cm[two[a]] !== cm[two[b]]) continue;
        const m = cm[two[a]],
          ds = bits(m);
        const el = UNITS[u].filter(i => i !== two[a] && i !== two[b] && cm[i] & m);
        if (el.length) {
          el.forEach(i => cm[i] &= ~m);
          return {
            technique: 'Naked Pair',
            pattern: [two[a], two[b]],
            elim: el,
            digit: ds[0],
            why: `Two cells in ${unitName(u)} can only be ${ds[0]} or ${ds[1]}, so no other cell there can use them.`
          };
        }
      }
    }
    return null;
  }
  function mk(technique, cell, digit, unit, focus, evidence, nudge, why, via) {
    return {
      kind: 'place',
      technique,
      tier: (TECH[technique] || {
        tier: 3
      }).tier,
      short: (TECH[technique] || {}).short || '',
      cell,
      digit,
      unit,
      focus,
      evidence,
      pattern: via ? via.pattern : [],
      elim: via ? via.elim : [],
      nudge,
      why
    };
  }
  const cap = s => NOTATION === 'grid' ? s : s[0].toUpperCase() + s.slice(1);
  const range = (a, b) => [...Array(b - a)].map((_, i) => a + i);
  function findHint(v, sol) {
    for (let i = 0; i < 81; i++) if (v[i] && v[i] !== sol[i]) return {
      kind: 'mistake',
      technique: 'Check this cell',
      tier: -1,
      short: '',
      cell: i,
      digit: sol[i],
      unit: 18 + BOX(i),
      focus: [i],
      evidence: [],
      pattern: [],
      elim: [],
      nudge: `Something in ${boxName(BOX(i))} doesn't fit.`,
      why: `The ${v[i]} in ${cellName(i)} can't be right — the puzzle doesn't solve with it.`
    };
    const cm = v.map((_, i) => candMask(v, i));
    let h = singles(v, cm, null);
    if (h) return h;
    for (const step of [locked, nakedPair]) {
      let via;
      while (via = step(v, cm)) {
        h = singles(v, cm, via);
        if (h) return h;
      }
    }
    const i = v.findIndex(x => !x);
    if (i < 0) return null;
    return mk('Advanced', i, sol[i], 18 + BOX(i), [i], [], `This step needs a technique beyond pairs.`, `Wings, fish or chains are needed here. The guide covers them in Learn → Advanced. Placing ${sol[i]} in ${cellName(i)}.`);
  }
  function techniquesNeeded(start, sol) {
    const v = start.slice(),
      tally = {};
    for (let n = 0; n < 81; n++) {
      const h = findHint(v, sol);
      if (!h) break;
      tally[h.technique] = (tally[h.technique] || 0) + 1;
      v[h.cell] = h.digit;
    }
    return tally;
  }
  const P = {
    easy: '53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79',
    medium: '..9748...7.........2.1.9.....7...24..64.1.59..98...3.....8.3.2.........6...2759..',
    hard: ['6....93..', '7..1..5..', '.4..53...', '....7....', '..7......', '2....4.73', '..23.8..4', '..5.6....', '.3......9'].join('')
  };
  P.expert = P.hard;
  P.master = P.hard;
  window.PSEngine = {
    ROW,
    COL,
    BOX,
    UNITS,
    PEERS,
    parse,
    solve,
    candMask,
    bits,
    pop,
    findHint,
    techniquesNeeded,
    PUZZLES: P,
    TECH,
    cellName,
    unitName,
    setNotation
  };
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/engine.js", error: String((e && e.message) || e) }); }

// ui_kits/puresudoku-2/night.js
try { (() => {
// Night palette model. Two continuous axes instead of theme toggles:
//   glow   0–100  how much light the screen emits (maps to ink luminance; app also lowers UIScreen.brightness)
//   warmth 0–100  colour temperature of every lit pixel, 6500 K → 1200 K, interpolated in mireds (perceptually even)
// plus clarity 0–2 (size, weight, line strength) for tired or older eyes.
// The canvas is always true black at night: on OLED those pixels are off.
(function () {
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  function kelvinRGB(k) {
    const t = k / 100;
    let r, g, b;
    if (t <= 66) {
      r = 255;
      g = 99.4708025861 * Math.log(t) - 161.1195681661;
    } else {
      r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
      g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
    }
    if (t >= 66) b = 255;else if (t <= 19) b = 0;else b = 138.5177312231 * Math.log(t - 10) - 305.0447927307;
    return [clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255)];
  }
  const M0 = 1e6 / 6500,
    M1 = 1e6 / 1200;
  const warmthToK = w => Math.round(1e6 / (M0 + (M1 - M0) * clamp(w, 0, 100) / 100) / 50) * 50;
  const rgb = (c, s) => `rgb(${c.map(x => Math.round(clamp(x * s, 0, 255))).join(',')})`;
  function typeScale(cl) {
    return {
      digit: [1, 1.1, 1.2][cl],
      given: [600, 700, 760][cl],
      user: [400, 500, 600][cl],
      cand: [1, 1.12, 1.25][cl],
      line: [1, 1.5, 2][cl],
      ui: [1, 1.06, 1.12][cl]
    };
  }
  function palette(st) {
    const cl = st.clarity || 0,
      type = typeScale(cl);
    if (st.appearance === 'day') {
      return {
        mode: 'day',
        type,
        kelvin: null,
        blueCut: 0,
        light: 100,
        vars: {
          '--bg': '#F4F1E9',
          '--surface': '#EBE6DA',
          '--surface2': '#E2DCCD',
          '--ink': '#1B1A17',
          '--ink2': '#57534B',
          '--ink3': '#8A857A',
          '--accent': '#9A5712',
          '--accentDim': '#C9A27A',
          '--line': cl ? '#B9B1A0' : '#CFC8B8',
          '--lineMajor': '#2E2B25',
          '--hair': '#D8D1C1',
          '--sel': '#EFD9B0',
          '--peer': '#ECE6D9',
          '--same': '#F1E2C6',
          '--err': '#B3261E',
          '--focusDim': '0.28',
          '--status': '#1B1A17'
        }
      };
    }
    const K = warmthToK(st.warmth),
      base = kelvinRGB(K);
    const acc = kelvinRGB(warmthToK(Math.min(100, st.warmth * 0.55 + 52)));
    const floor = [0.2, 0.3, 0.38][cl];
    const s = floor + (1 - floor) * Math.pow(clamp(st.glow, 0, 100) / 100, 1.15);
    const lift = [1, 1.25, 1.5][cl];
    const errc = [255, 70, 64];
    return {
      mode: 'night',
      type,
      kelvin: K,
      s,
      blueCut: Math.round((1 - base[2] / 255 * s) * 100),
      light: Math.round(s * 100),
      vars: {
        '--bg': '#000',
        '--surface': rgb(base, s * 0.07),
        '--surface2': rgb(base, s * 0.11),
        '--ink': rgb(base, s),
        '--ink2': rgb(base, s * 0.7),
        '--ink3': rgb(base, s * 0.5),
        '--accent': rgb(acc, s * 0.96),
        '--accentDim': rgb(acc, s * 0.5),
        '--line': rgb(base, s * 0.17 * lift),
        '--lineMajor': rgb(base, s * 0.42 * lift),
        '--hair': rgb(base, s * 0.15),
        '--sel': rgb(acc, s * 0.2),
        '--peer': rgb(base, s * 0.055),
        '--same': rgb(acc, s * 0.12),
        '--err': rgb(errc, s * 0.95),
        '--focusDim': '0.22',
        '--status': rgb(base, s * 0.44)
      }
    };
  }
  window.PSNight = {
    palette,
    kelvinRGB,
    warmthToK
  };
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/puresudoku-2/night.js", error: String((e && e.message) || e) }); }

__ds_ns.Board = __ds_scope.Board;

__ds_ns.HintCard = __ds_scope.HintCard;

__ds_ns.Keypad = __ds_scope.Keypad;

})();
