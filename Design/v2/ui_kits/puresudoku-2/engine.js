// PureSudoku prototype engine: solver, candidates, and a human-style hint finder.
// Mirrors HINT_STRATEGIES.md ordering (singles -> locked candidates -> naked pairs -> fallback).
(function () {
  const ROW = i => Math.floor(i / 9), COL = i => i % 9, BOX = i => Math.floor(ROW(i) / 3) * 3 + Math.floor(COL(i) / 3);
  const UNITS = [];
  for (let r = 0; r < 9; r++) UNITS.push([...Array(9)].map((_, c) => r * 9 + c));
  for (let c = 0; c < 9; c++) UNITS.push([...Array(9)].map((_, r) => r * 9 + c));
  for (let b = 0; b < 9; b++) { const r0 = Math.floor(b / 3) * 3, c0 = (b % 3) * 3, u = []; for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) u.push((r0 + r) * 9 + c0 + c); UNITS.push(u); }
  const PEERS = [...Array(81)].map((_, i) => { const s = new Set([...UNITS[ROW(i)], ...UNITS[9 + COL(i)], ...UNITS[18 + BOX(i)]]); s.delete(i); return [...s]; });
  let NOTATION = 'plain';
  const setNotation = n => { NOTATION = n === 'grid' ? 'grid' : 'plain'; };
  const unitName = u => NOTATION === 'grid' ? (u < 9 ? `R${u + 1}` : u < 18 ? `C${u - 8}` : `B${u - 17}`) : u < 9 ? `row ${u + 1}` : u < 18 ? `column ${u - 8}` : `box ${u - 17}`;
  const cellName = i => NOTATION === 'grid' ? `R${ROW(i) + 1}C${COL(i) + 1}` : `row ${ROW(i) + 1}, column ${COL(i) + 1}`;
  const boxName = b => NOTATION === 'grid' ? `B${b + 1}` : `box ${b + 1}`;
  const pop = m => { let c = 0; while (m) { m &= m - 1; c++; } return c; };
  const bits = m => { const a = []; for (let d = 1; d <= 9; d++) if (m & (1 << d)) a.push(d); return a; };
  const parse = s => [...s].map(ch => (ch >= '1' && ch <= '9' ? +ch : 0));
  function candMask(v, i) { if (v[i]) return 0; let m = 0x3FE; for (const p of PEERS[i]) if (v[p]) m &= ~(1 << v[p]); return m; }

  function solve(vals) {
    const g = vals.slice();
    function rec() {
      let best = -1, bm = 0, bc = 10;
      for (let i = 0; i < 81; i++) if (!g[i]) { const m = candMask(g, i), c = pop(m); if (!c) return false; if (c < bc) { bc = c; best = i; bm = m; if (c === 1) break; } }
      if (best < 0) return true;
      for (const d of bits(bm)) { g[best] = d; if (rec()) return true; }
      g[best] = 0; return false;
    }
    return rec() ? g : null;
  }

  const TECH = {
    'Full House': { tier: 0, short: 'A row, column or box with one empty cell left.' },
    'Naked Single': { tier: 0, short: 'A cell that can only hold one digit.' },
    'Hidden Single': { tier: 0, short: 'A digit with only one possible home in a row, column or box.' },
    'Pointing': { tier: 1, short: 'In a box, a digit is confined to one line, so it leaves the rest of that line.' },
    'Claiming': { tier: 1, short: 'In a line, a digit is confined to one box, so it leaves the rest of that box.' },
    'Naked Pair': { tier: 1, short: 'Two cells share the same two candidates, so no other cell in the unit can use them.' },
  };

  function blockerFor(v, i, d) { for (const p of PEERS[i]) if (v[p] === d) return p; return -1; }

  function singles(v, cm, via) {
    // Full house
    if (!via) for (let u = 0; u < 27; u++) {
      const empt = UNITS[u].filter(i => !v[i]);
      if (empt.length === 1) {
        const have = new Set(UNITS[u].map(i => v[i])); let d = 1; while (have.has(d)) d++;
        return mk('Full House', empt[0], d, u, UNITS[u], [], `Look at ${unitName(u)}.`, `${cap(unitName(u))} has one empty cell left, and the only digit missing is ${d}.`);
      }
    }
    // Hidden singles — boxes first (how people scan), then rows, then columns
    for (const u of [...range(18, 27), ...range(0, 18)]) {
      for (let d = 1; d <= 9; d++) {
        if (UNITS[u].some(i => v[i] === d)) continue;
        const spots = UNITS[u].filter(i => cm[i] & (1 << d));
        if (spots.length !== 1) continue;
        const t = spots[0];
        const ev = new Set();
        UNITS[u].forEach(i => { if (!v[i] && i !== t) { const b = blockerFor(v, i, d); if (b >= 0) ev.add(b); } });
        const why = via
          ? `${via.why} With that removed, ${d} has only one home left in ${unitName(u)}.`
          : `Every other empty cell in ${unitName(u)} already sees ${d === 8 ? "an" : "a"} ${d}. So ${d} can only go in ${cellName(t)}.`;
        return mk(via ? via.technique : 'Hidden Single', t, d, u, UNITS[u], [...ev], `Look at ${unitName(u)}. Where can ${d} go?`, why, via);
      }
    }
    // Naked single
    for (let i = 0; i < 81; i++) if (!v[i] && pop(cm[i]) === 1) {
      const d = bits(cm[i])[0]; const seen = {};
      PEERS[i].forEach(p => { if (v[p] && v[p] !== d && seen[v[p]] === undefined) seen[v[p]] = p; });
      const why = via ? `${via.why} That leaves ${cellName(i)} with a single candidate: ${d}.` : `${cap(cellName(i))} already sees ${Object.keys(seen).sort().join(', ')} in its row, column and box. Only ${d} is left.`;
      return mk(via ? via.technique : 'Naked Single', i, d, 18 + BOX(i), [...new Set([...UNITS[ROW(i)], ...UNITS[9 + COL(i)], ...UNITS[18 + BOX(i)]])], Object.values(seen), `One cell in ${boxName(BOX(i))} is nearly decided.`, why, via);
    }
    return null;
  }

  function locked(v, cm) {
    for (let b = 18; b < 27; b++) for (let d = 1; d <= 9; d++) {
      const cells = UNITS[b].filter(i => cm[i] & (1 << d)); if (cells.length < 2) continue;
      for (const [kind, f, off] of [['row', ROW, 0], ['col', COL, 9]]) {
        const lines = new Set(cells.map(f)); if (lines.size !== 1) continue;
        const line = off + [...lines][0];
        const el = UNITS[line].filter(i => BOX(i) !== b - 18 && cm[i] & (1 << d));
        if (el.length) { el.forEach(i => cm[i] &= ~(1 << d)); return { technique: 'Pointing', pattern: cells, elim: el, digit: d, why: `In ${boxName(b - 18)}, every ${d} sits in ${unitName(line)}, so ${d} leaves the rest of that ${kind === 'row' ? 'row' : 'column'}.` }; }
      }
    }
    for (let u = 0; u < 18; u++) for (let d = 1; d <= 9; d++) {
      const cells = UNITS[u].filter(i => cm[i] & (1 << d)); if (cells.length < 2) continue;
      const boxes = new Set(cells.map(BOX)); if (boxes.size !== 1) continue;
      const b = [...boxes][0];
      const el = UNITS[18 + b].filter(i => !UNITS[u].includes(i) && cm[i] & (1 << d));
      if (el.length) { el.forEach(i => cm[i] &= ~(1 << d)); return { technique: 'Claiming', pattern: cells, elim: el, digit: d, why: `In ${unitName(u)}, every ${d} sits inside ${boxName(b)}, so ${d} leaves the rest of that box.` }; }
    }
    return null;
  }

  function nakedPair(v, cm) {
    for (let u = 0; u < 27; u++) {
      const two = UNITS[u].filter(i => pop(cm[i]) === 2);
      for (let a = 0; a < two.length; a++) for (let b = a + 1; b < two.length; b++) {
        if (cm[two[a]] !== cm[two[b]]) continue;
        const m = cm[two[a]], ds = bits(m);
        const el = UNITS[u].filter(i => i !== two[a] && i !== two[b] && (cm[i] & m));
        if (el.length) { el.forEach(i => cm[i] &= ~m); return { technique: 'Naked Pair', pattern: [two[a], two[b]], elim: el, digit: ds[0], why: `Two cells in ${unitName(u)} can only be ${ds[0]} or ${ds[1]}, so no other cell there can use them.` }; }
      }
    }
    return null;
  }

  function mk(technique, cell, digit, unit, focus, evidence, nudge, why, via) {
    return { kind: 'place', technique, tier: (TECH[technique] || { tier: 3 }).tier, short: (TECH[technique] || {}).short || '', cell, digit, unit, focus, evidence, pattern: via ? via.pattern : [], elim: via ? via.elim : [], nudge, why };
  }
  const cap = s => (NOTATION === 'grid' ? s : s[0].toUpperCase() + s.slice(1));
  const range = (a, b) => [...Array(b - a)].map((_, i) => a + i);

  function findHint(v, sol) {
    for (let i = 0; i < 81; i++) if (v[i] && v[i] !== sol[i]) return { kind: 'mistake', technique: 'Check this cell', tier: -1, short: '', cell: i, digit: sol[i], unit: 18 + BOX(i), focus: [i], evidence: [], pattern: [], elim: [], nudge: `Something in ${boxName(BOX(i))} doesn't fit.`, why: `The ${v[i]} in ${cellName(i)} can't be right — the puzzle doesn't solve with it.` };
    const cm = v.map((_, i) => candMask(v, i));
    let h = singles(v, cm, null); if (h) return h;
    for (const step of [locked, nakedPair]) {
      let via; while ((via = step(v, cm))) { h = singles(v, cm, via); if (h) return h; }
    }
    const i = v.findIndex(x => !x); if (i < 0) return null;
    return mk('Advanced', i, sol[i], 18 + BOX(i), [i], [], `This step needs a technique beyond pairs.`, `Wings, fish or chains are needed here. The guide covers them in Learn → Advanced. Placing ${sol[i]} in ${cellName(i)}.`);
  }

  function techniquesNeeded(start, sol) {
    const v = start.slice(), tally = {};
    for (let n = 0; n < 81; n++) { const h = findHint(v, sol); if (!h) break; tally[h.technique] = (tally[h.technique] || 0) + 1; v[h.cell] = h.digit; }
    return tally;
  }

  const P = {
    easy: '53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79',
    medium: '..9748...7.........2.1.9.....7...24..64.1.59..98...3.....8.3.2.........6...2759..',
    hard: ['6....93..', '7..1..5..', '.4..53...', '....7....', '..7......', '2....4.73', '..23.8..4', '..5.6....', '.3......9'].join(''),
  };
  P.expert = P.hard; P.master = P.hard;

  window.PSEngine = { ROW, COL, BOX, UNITS, PEERS, parse, solve, candMask, bits, pop, findHint, techniquesNeeded, PUZZLES: P, TECH, cellName, unitName, setNotation };
})();
