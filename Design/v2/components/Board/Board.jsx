const UNIT_BOX = b => { const r0 = Math.floor(b / 3) * 3, c0 = (b % 3) * 3, u = []; for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) u.push((r0 + r) * 9 + c0 + c); return u; };
const rowOf = i => Math.floor(i / 9), colOf = i => i % 9, boxOf = i => Math.floor(rowOf(i) / 3) * 3 + Math.floor(colOf(i) / 3);

export function Board({ values = [], givens = [], notes = [], selected = -1, width = 366, clarity = 0, marks = {}, errors = [], onSelect }) {
  const type = { digit: [1, 1.1, 1.2][clarity], given: [600, 700, 760][clarity], user: [400, 500, 600][clarity], cand: [1, 1.12, 1.25][clarity], line: [1, 1.5, 2][clarity] };
  const cs = (width - 8) / 9, lw = Math.max(1, Math.round(type.line)), mj = 1 + Math.round(type.line);
  const sv = selected >= 0 ? values[selected] : 0;
  const has = (arr, i) => Array.isArray(arr) && arr.includes(i);
  const cell = i => {
    const v = values[i], g = givens[i], isSel = i === selected;
    const peer = selected >= 0 && !isSel && (rowOf(i) === rowOf(selected) || colOf(i) === colOf(selected) || boxOf(i) === boxOf(selected));
    const same = sv && v === sv && !isSel;
    const dim = marks.focus && !has(marks.focus, i);
    let bg = 'var(--bg)';
    if (has(marks.pattern, i)) bg = 'var(--same)'; else if (isSel) bg = 'var(--sel)'; else if (same) bg = 'var(--same)'; else if (peer && !marks.focus) bg = 'var(--peer)';
    const sh = []; if (isSel) sh.push('inset 0 0 0 2px var(--accent)'); if (has(marks.evidence, i)) sh.push('inset 0 0 0 1.5px var(--accent)');
    const err = has(errors, i), n = notes[i] || 0;
    return (
      <div key={i} onClick={() => onSelect && onSelect(i)} style={{ background: bg, boxShadow: sh.join(','), position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: onSelect ? 'pointer' : 'default' }}>
        {marks.target === i && <div style={{ position: 'absolute', inset: 3, border: '1.5px dashed var(--accent)', borderRadius: 4 }}></div>}
        {v ? (
          <span style={{ fontSize: cs * 0.6 * type.digit, lineHeight: 1, fontWeight: g ? type.given : type.user, color: err ? 'var(--err)' : g ? 'var(--ink)' : 'var(--accent)', opacity: dim ? 0.25 : 1, position: 'relative', fontVariantNumeric: 'tabular-nums' }}>
            {v}{err && <span style={{ position: 'absolute', left: '-10%', right: '-10%', bottom: -cs * 0.1, height: 2, borderRadius: 1, background: 'var(--err)' }}></span>}
          </span>
        ) : marks.target === i && marks.ghost ? (
          <span style={{ fontSize: cs * 0.6 * type.digit, lineHeight: 1, color: 'var(--accent)', opacity: 0.55 }}>{marks.ghost}</span>
        ) : n ? (
          <div style={{ position: 'absolute', inset: cs * 0.06, display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gridTemplateRows: 'repeat(3,1fr)', opacity: dim ? 0.25 : 1 }}>
            {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => <span key={d} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: cs * 0.25 * type.cand, lineHeight: 1, fontWeight: sv === d ? 700 : 500, color: sv === d ? 'var(--accent)' : 'var(--ink2)' }}>{n & (1 << d) ? d : ''}</span>)}
          </div>
        ) : null}
      </div>
    );
  };
  return (
    <div style={{ width, height: width, boxSizing: 'border-box', padding: mj, background: 'var(--lineMajor)', borderRadius: 6, display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gridTemplateRows: 'repeat(3,1fr)', gap: mj }}>
      {[0, 1, 2, 3, 4, 5, 6, 7, 8].map(b => <div key={b} style={{ background: 'var(--line)', display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gridTemplateRows: 'repeat(3,1fr)', gap: lw }}>{UNIT_BOX(b).map(cell)}</div>)}
    </div>
  );
}
