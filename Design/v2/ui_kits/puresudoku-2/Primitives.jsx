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
  eye: 'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12ZM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z',
};
function Ico({ n, s = 22, c = 'currentColor', w = 1.7, fill }) {
  return <svg width={s} height={s} viewBox="0 0 24 24" fill={fill || 'none'} stroke={c} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0, display: 'block' }}><path d={PSI[n]} /></svg>;
}

function PhoneFrame({ children, hideStatus, dimChrome }) {
  return (
    <div style={{ width: 414, height: 868, borderRadius: 66, padding: 12, boxSizing: 'border-box', background: '#0a0a0a', boxShadow: '0 0 0 1.5px #2a2a2a, 0 30px 80px rgba(0,0,0,.5)' }}>
      <div className="ps-screen" style={{ width: 390, height: 844, borderRadius: 54, overflow: 'hidden', position: 'relative', background: 'var(--bg)' }}>
        <div style={{ position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)', width: 122, height: 35, borderRadius: 20, background: '#000', zIndex: 80 }}></div>
        {!hideStatus && (
          <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 54, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '4px 34px 0 44px', zIndex: 70, color: 'var(--status)', fontSize: 16, fontWeight: 600, pointerEvents: 'none' }}>
            <span style={{ fontVariantNumeric: 'tabular-nums' }}>11:42</span>
            <span style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" /><rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" /></svg>
              <svg width="26" height="12" viewBox="0 0 26 12" fill="none" stroke="currentColor"><rect x=".5" y=".5" width="22" height="11" rx="3.5" opacity=".5" /><rect x="2.5" y="2.5" width="12" height="7" rx="1.8" fill="currentColor" stroke="none" /><path d="M24.5 4v4" opacity=".5" /></svg>
            </span>
          </div>
        )}
        <div style={{ position: 'absolute', inset: 0 }}>{children}</div>
        <div style={{ position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)', width: 134, height: 5, borderRadius: 3, background: 'var(--ink3)', opacity: dimChrome ? 0.35 : 0.9, zIndex: 90, pointerEvents: 'none' }}></div>
      </div>
    </div>
  );
}

// Board. marks: { focus:Set, evidence:Set, pattern:Set, elim:Set, target:idx, ghost:digit, spotlight:bool }
// candMarks (lessons): { [cell]: { [digit]: 'key'|'elim' } }
function GridBoard({ vals, givens, notes, sel = -1, width = 366, type, marks = {}, errors, candMarks, onSelect, showPeers = true }) {
  const E = window.PSEngine, cs = (width - 8) / 9;
  const lw = Math.max(1, Math.round(type.line)), mj = 2 + Math.round(type.line) - 1;
  const sv = sel >= 0 ? vals[sel] : 0;
  const cell = i => {
    const v = vals[i], g = givens && givens[i];
    const isSel = i === sel;
    const peer = showPeers && sel >= 0 && !isSel && (E.ROW(i) === E.ROW(sel) || E.COL(i) === E.COL(sel) || E.BOX(i) === E.BOX(sel));
    const same = sv && v === sv && !isSel;
    const m = marks;
    const inFocus = !m.spotlight || (m.focus && m.focus.has(i));
    let bg = 'var(--bg)';
    if (m.pattern && m.pattern.has(i)) bg = 'var(--same)';
    else if (isSel) bg = 'var(--sel)';
    else if (same) bg = 'var(--same)';
    else if (peer && !m.spotlight) bg = 'var(--peer)';
    const shadows = [];
    if (isSel) shadows.push('inset 0 0 0 2px var(--accent)');
    if (m.evidence && m.evidence.has(i)) shadows.push('inset 0 0 0 1.5px var(--accent)');
    const err = errors && errors.has(i);
    const cm = candMarks && candMarks[i];
    return (
      <div key={i} onClick={() => onSelect && onSelect(i)} style={{ background: bg, boxShadow: shadows.join(','), position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: onSelect ? 'pointer' : 'default' }}>
        {m.target === i && <div style={{ position: 'absolute', inset: 3, border: '1.5px dashed var(--accent)', borderRadius: 4 }}></div>}
        {m.elim && m.elim.has(i) && <div style={{ position: 'absolute', inset: 4, border: '1px dotted var(--ink3)', borderRadius: 4 }}></div>}
        {v ? (
          <span style={{ fontSize: cs * 0.6 * type.digit, lineHeight: 1, fontWeight: g ? type.given : type.user, color: err ? 'var(--err)' : g ? 'var(--ink)' : 'var(--accent)', opacity: inFocus ? 1 : 'var(--focusDim)', fontVariantNumeric: 'tabular-nums', position: 'relative' }}>
            {v}
            {err && <span style={{ position: 'absolute', left: '-10%', right: '-10%', bottom: -cs * 0.1, height: 2, borderRadius: 1, background: 'var(--err)' }}></span>}
          </span>
        ) : m.target === i && m.ghost ? (
          <span style={{ fontSize: cs * 0.6 * type.digit, lineHeight: 1, fontWeight: type.user, color: 'var(--accent)', opacity: 0.55 }}>{m.ghost}</span>
        ) : (notes && notes[i]) || cm ? (
          <div style={{ position: 'absolute', inset: cs * 0.06, display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gridTemplateRows: 'repeat(3,1fr)', opacity: inFocus ? 1 : 'var(--focusDim)' }}>
            {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => {
              const on = cm ? d in cm : notes[i] & (1 << d);
              const st = cm && cm[d];
              const hot = !cm && sv === d;
              return <span key={d} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: cs * 0.25 * type.cand, lineHeight: 1, fontWeight: st === 'key' || hot ? 700 : 500, color: st === 'key' || hot ? 'var(--accent)' : st === 'elim' ? 'var(--ink3)' : 'var(--ink2)', textDecoration: st === 'elim' ? 'line-through' : 'none', textDecorationColor: 'var(--err)', textDecorationThickness: 1.5 }}>{on ? d : ''}</span>;
            })}
          </div>
        ) : null}
      </div>
    );
  };
  return (
    <div style={{ width, height: width, boxSizing: 'border-box', padding: mj, background: 'var(--lineMajor)', borderRadius: 6, display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gridTemplateRows: 'repeat(3,1fr)', gap: mj }}>
      {[0, 1, 2, 3, 4, 5, 6, 7, 8].map(b => (
        <div key={b} style={{ background: 'var(--line)', display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gridTemplateRows: 'repeat(3,1fr)', gap: lw }}>
          {E.UNITS[18 + b].map(cell)}
        </div>
      ))}
    </div>
  );
}

function Keypad({ onDigit, notesMode, remaining, type }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(9,1fr)', gap: 4 }}>
      {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => {
        const done = remaining[d] <= 0;
        const pos = { r: Math.floor((d - 1) / 3), c: (d - 1) % 3 };
        return (
          <button key={d} className="ps-key" disabled={done} onClick={() => onDigit(d)} style={{ height: 64, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 3, opacity: done ? 0.28 : 1 }}>
            {notesMode ? (
              <span style={{ width: 30, height: 30, display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gridTemplateRows: 'repeat(3,1fr)' }}>
                <span style={{ gridColumn: pos.c + 1, gridRow: pos.r + 1, fontSize: 13 * type.cand, fontWeight: 700, color: 'var(--accent)', lineHeight: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{d}</span>
              </span>
            ) : (
              <span style={{ fontSize: 30 * type.ui, fontWeight: 400, color: 'var(--ink)', lineHeight: 1, height: 30, display: 'flex', alignItems: 'center' }}>{d}</span>
            )}
            <span style={{ fontSize: 10.5, color: 'var(--ink3)', fontVariantNumeric: 'tabular-nums', fontWeight: 500 }}>{done ? '' : remaining[d]}</span>
          </button>
        );
      })}
    </div>
  );
}

function ToolBtn({ icon, label, onClick, active, disabled, badge }) {
  return (
    <button className="ps-tool" onClick={onClick} disabled={disabled} style={{ color: active ? 'var(--accent)' : 'var(--ink2)', opacity: disabled ? 0.35 : 1 }}>
      <span style={{ position: 'relative' }}>
        <Ico n={icon} s={23} />
        {badge && <span style={{ position: 'absolute', top: -5, right: -12, fontSize: 9, fontWeight: 700, padding: '1px 4px', borderRadius: 6, background: active ? 'var(--accent)' : 'var(--surface2)', color: active ? 'var(--bg)' : 'var(--ink2)', letterSpacing: '.02em' }}>{badge}</span>}
      </span>
      <span style={{ fontSize: 11, fontWeight: 500 }}>{label}</span>
    </button>
  );
}

Object.assign(window, { Ico, PhoneFrame, GridBoard, Keypad, ToolBtn });
