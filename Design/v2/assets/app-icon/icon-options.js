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
      return wrap(px, id, warm(id) + glow(id, 0.22) + `<mask id="${id}c"><rect width="1024" height="1024" fill="#000"/><circle cx="500" cy="520" r="300" fill="#fff"/><circle cx="640" cy="430" r="268" fill="#000"/></mask>`,
        `<circle cx="470" cy="560" r="420" fill="url(#${id}g)"/>
<g stroke="#3B230C" stroke-width="10" stroke-linecap="round"><path d="M398 180V860M626 180V860M170 408H850M170 636H850"/></g>
<rect width="1024" height="1024" fill="url(#${id}w)" mask="url(#${id}c)"/>`);
    },
    lastcell(px) {
      const id = 'pa' + n++, o = 150, s = 226, g = 22;
      let t = '';
      const digits = [3, 8, 1, 6, 4, 9, 2, 5, 0];
      for (let k = 0; k < 9; k++) {
        const x = o + (k % 3) * (s + g), y = o + Math.floor(k / 3) * (s + g);
        if (k === 8) t += `<rect x="${x - 40}" y="${y - 40}" width="${s + 80}" height="${s + 80}" rx="70" fill="url(#${id}g)"/><rect x="${x}" y="${y}" width="${s}" height="${s}" rx="34" fill="url(#${id}w)"/>`;
        else t += `<rect x="${x}" y="${y}" width="${s}" height="${s}" rx="34" fill="#140C05"/><text x="${x + s / 2}" y="${y + s / 2}" dy=".35em" text-anchor="middle" font-family="${SERIF}" font-size="128" font-weight="500" fill="#5E3A16">${digits[k]}</text>`;
      }
      return wrap(px, id, warm(id) + glow(id, 0.55), t);
    },
    numeral(px) {
      const id = 'pa' + n++;
      return wrap(px, id, warm(id) + glow(id, 0.3),
        `<circle cx="600" cy="640" r="520" fill="url(#${id}g)"/>
<g stroke="#2E1B0A" stroke-width="8"><path d="M341 0V1024M683 0V1024M0 341H1024M0 683H1024"/></g>
<text x="590" y="1010" text-anchor="middle" font-family="${SERIF}" font-size="1040" font-weight="500" fill="url(#${id}w)">9</text>`);
    },
    ember(px) {
      const id = 'pa' + n++;
      let d = '';
      for (let k = 0; k < 9; k++) { if (k === 4) continue; d += `<circle cx="${282 + (k % 3) * 230}" cy="${282 + Math.floor(k / 3) * 230}" r="30" fill="#5A3614"/>`; }
      return wrap(px, id, `<radialGradient id="${id}c"><stop offset="0" stop-color="#FFF1D6"/><stop offset=".35" stop-color="#FFC06A"/><stop offset=".75" stop-color="#EE8530"/><stop offset="1" stop-color="#C9601A"/></radialGradient>` + glow(id, 0.5),
        `<circle cx="512" cy="512" r="330" fill="url(#${id}g)"/>${d}<circle cx="512" cy="512" r="112" fill="url(#${id}c)"/>`, '#050302');
    },
    window(px) {
      const id = 'pa' + n++, x = 252, s = 520, p = s / 3;
      return wrap(px, id, warm(id) + glow(id, 0.45) + `<linearGradient id="${id}s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0C0906"/><stop offset="1" stop-color="#000"/></linearGradient>`,
        `<rect width="1024" height="1024" fill="url(#${id}s)"/>
<path d="M214 196a54 54 0 1 0 50 74a44 44 0 1 1 -50 -74Z" fill="#B9753A" opacity=".75"/>
<circle cx="${x + p * 2.5}" cy="${x + p * 0.5}" r="300" fill="url(#${id}g)"/>
<rect x="${x}" y="${x}" width="${s}" height="${s}" rx="10" fill="#080604"/>
<rect x="${x + p * 2}" y="${x}" width="${p}" height="${p}" fill="url(#${id}w)"/>
<g stroke="#2C1C0D" stroke-width="18"><rect x="${x}" y="${x}" width="${s}" height="${s}" rx="10" fill="none" stroke-width="26"/><path d="M${x + p} ${x}V${x + s}M${x + 2 * p} ${x}V${x + s}M${x} ${x + p}H${x + s}M${x} ${x + 2 * p}H${x + s}"/></g>
<rect x="${x - 40}" y="${x + s + 6}" width="${s + 80}" height="22" rx="11" fill="#2C1C0D"/>`, '#000');
    },
  };
  // Learning-led concepts
  Object.assign(ICONS, {
    xwing(px) {
      const id = 'pa' + n++, c = [300, 724];
      let t = `<g stroke="#2E1C0B" stroke-width="8"><path d="M371 120V904M653 120V904M120 371H904M120 653H904"/></g>`;
      t += `<g stroke="#F0A34B" stroke-width="10" stroke-linecap="round" opacity=".55"><path d="M${c[0]} ${c[0]}L${c[1]} ${c[1]}M${c[1]} ${c[0]}L${c[0]} ${c[1]}"/></g>`;
      t += `<g stroke="#8A5520" stroke-width="6" stroke-dasharray="4 18" stroke-linecap="round"><path d="M${c[0]} ${c[0]}H${c[1]}M${c[0]} ${c[1]}H${c[1]}M${c[0]} ${c[0]}V${c[1]}M${c[1]} ${c[0]}V${c[1]}"/></g>`;
      c.forEach(x => c.forEach(y => { t += `<circle cx="${x}" cy="${y}" r="120" fill="url(#${id}g)"/><circle cx="${x}" cy="${y}" r="62" fill="url(#${id}w)"/>`; }));
      return wrap(px, id, warm(id) + glow(id, 0.4), t);
    },
    resolve(px) {
      const id = 'pa' + n++;
      const pos = d => [212 + ((d - 1) % 3) * 300, 212 + Math.floor((d - 1) / 3) * 300];
      let t = `<rect x="92" y="92" width="840" height="840" rx="60" fill="none" stroke="#2E1C0B" stroke-width="10"/>`;
      [1, 3, 7, 9].forEach(d => { const [x, y] = pos(d); t += `<text x="${x}" y="${y}" dy=".35em" text-anchor="middle" font-family="${SERIF}" font-size="150" font-weight="500" fill="#4F3112">${d}</text><path d="M${x - 70} ${y + 70}L${x + 70} ${y - 70}" stroke="#7A2E1E" stroke-width="12" stroke-linecap="round"/>`; });
      t += `<circle cx="512" cy="512" r="330" fill="url(#${id}g)"/><text x="512" y="512" dy=".35em" text-anchor="middle" font-family="${SERIF}" font-size="430" font-weight="500" fill="url(#${id}w)">5</text>`;
      return wrap(px, id, warm(id) + glow(id, 0.38), t);
    },
    hintring(px) { return window.PSIcon('dark', px); },
    ladder(px) {
      const id = 'pa' + n++;
      let t = '';
      [0, 1, 2, 3, 4].forEach(i => { const h = 150 + i * 120, x = 190 + i * 140; t += `<rect x="${x}" y="${860 - h}" width="92" height="${h}" rx="22" fill="${i === 4 ? `url(#${id}w)` : ['#2A190A', '#3A230D', '#4F3112', '#6E4419'][i]}"/>`; });
      t = `<circle cx="796" cy="300" r="300" fill="url(#${id}g)"/>` + t;
      t += `<g fill="#B9753A">${[[286, 640], [426, 520], [566, 400]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="12"/>`).join('')}</g>`;
      return wrap(px, id, warm(id) + glow(id, 0.42), t);
    },
    book(px) {
      const id = 'pa' + n++;
      const page = (x0, lit) => { let s = `<path d="M${x0} 300Q${x0 + 170} 270 ${x0 + 340} 300V760Q${x0 + 170} 730 ${x0} 760Z" fill="#120B05" stroke="#3A230D" stroke-width="8"/>`; for (let k = 0; k < 9; k++) { const x = x0 + 50 + (k % 3) * 82, y = 360 + Math.floor(k / 3) * 112; s += k === lit ? `<rect x="${x}" y="${y}" width="74" height="96" rx="12" fill="url(#${id}w)"/>` : `<rect x="${x}" y="${y}" width="74" height="96" rx="12" fill="#21150A"/>`; } return s; };
      return wrap(px, id, warm(id) + glow(id, 0.38), `<circle cx="512" cy="520" r="420" fill="url(#${id}g)"/>${page(160, -1)}${page(524, 4)}<path d="M512 290V780" stroke="#5A3614" stroke-width="10" stroke-linecap="round"/>`);
    },
  });
  ICONS.current = null;
  window.PSIconAlt = (k, px = 1024) => ICONS[k](px);
})();
