/* global React, Ico, GridBoard */
const { useState: useStI } = React;

function ImportSource({ onBack }) {
  const opt = (icon, title, sub) => (
    <button className="ps-card" style={{ width: '100%', padding: '18px 18px', display: 'flex', gap: 16, alignItems: 'center', textAlign: 'left' }}>
      <span style={{ color: 'var(--accent)' }}><Ico n={icon} s={26} /></span>
      <span style={{ flex: 1 }}><span style={{ display: 'block', fontSize: 17, color: 'var(--ink)' }}>{title}</span><span style={{ display: 'block', fontSize: 13, color: 'var(--ink3)', marginTop: 3 }}>{sub}</span></span>
      <span style={{ color: 'var(--ink3)' }}><Ico n="chev" s={16} /></span>
    </button>
  );
  return (
    <div style={{ position: 'absolute', inset: 0, paddingTop: 54 }}>
      <div style={{ height: 48, padding: '0 10px', display: 'flex', alignItems: 'center' }}><button className="ps-icon" onClick={onBack} aria-label="Back"><Ico n="close" s={20} /></button></div>
      <div style={{ padding: '6px 22px 22px' }}>
        <div className="ps-serif" style={{ fontSize: 32, color: 'var(--ink)', lineHeight: 1.1 }}>Import a puzzle</div>
        <div style={{ fontSize: 15, color: 'var(--ink2)', marginTop: 8, lineHeight: 1.4, textWrap: 'pretty' }}>From a newspaper, a book or a screenshot. The photo is read on this iPhone and never uploaded.</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 16px' }}>
        {opt('camera', 'Take a photo', 'Camera')}
        {opt('grid', 'Choose from Photos', 'Screenshots work best')}
        {opt('pencil', 'Type it in', 'Enter the givens by hand')}
      </div>
      <div style={{ padding: '26px 22px 0', fontSize: 13, color: 'var(--ink3)', lineHeight: 1.6 }}>
        <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', marginBottom: 6 }}>For a clean read</div>
        Fill the frame with the grid · Good light, no glare · Pencil marks are ignored
      </div>
    </div>
  );
}

function ImportReading() {
  return (
    <div style={{ position: 'absolute', inset: 0, paddingTop: 54, display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 48 }}></div>
      <div style={{ margin: '0 24px', height: 420, borderRadius: 16, position: 'relative', overflow: 'hidden', background: 'repeating-linear-gradient(135deg, var(--surface) 0 10px, var(--surface2) 10px 20px)', border: '1px solid var(--hair)' }}>
        <span style={{ position: 'absolute', top: 12, left: 14, fontSize: 11, fontFamily: 'ui-monospace, monospace', color: 'var(--ink3)' }}>photo</span>
        <div style={{ position: 'absolute', left: 38, top: 62, width: 266, height: 266, border: '2px solid var(--accent)', borderRadius: 4, transform: 'rotate(-3deg)', boxShadow: '0 0 0 2000px rgba(0,0,0,.35)' }}>
          {[1, 2].map(k => <span key={'v' + k} style={{ position: 'absolute', top: 0, bottom: 0, left: `${(k * 100) / 3}%`, width: 1.5, background: 'var(--accentDim)' }}></span>)}
          {[1, 2].map(k => <span key={'h' + k} style={{ position: 'absolute', left: 0, right: 0, top: `${(k * 100) / 3}%`, height: 1.5, background: 'var(--accentDim)' }}></span>)}
        </div>
      </div>
      <div style={{ padding: '28px 24px 0' }}>
        <div className="ps-serif" style={{ fontSize: 26, color: 'var(--ink)' }}>Reading digits…</div>
        <div style={{ fontSize: 15, color: 'var(--ink2)', marginTop: 6, fontVariantNumeric: 'tabular-nums' }}>Grid found · 61 of 81 cells checked</div>
        <div style={{ height: 3, borderRadius: 2, background: 'var(--hair)', marginTop: 16, overflow: 'hidden' }}><div style={{ width: '75%', height: '100%', background: 'var(--accentDim)' }}></div></div>
      </div>
    </div>
  );
}

function ImportReview({ pal, onBack }) {
  const E = window.PSEngine;
  const vals = E.parse(E.PUZZLES.medium);
  vals[30] = 4; // misread: creates a conflict
  const unsure = new Set([5, 47, 57]);
  const conflict = new Set([30, 34]);
  return (
    <div style={{ position: 'absolute', inset: 0, paddingTop: 54, display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 48, padding: '0 10px', display: 'flex', alignItems: 'center' }}>
        <button className="ps-icon" onClick={onBack} aria-label="Discard"><Ico n="close" s={20} /></button>
        <span style={{ flex: 1, textAlign: 'center', fontSize: 12, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)' }}>Check the grid</span>
        <span style={{ width: 44 }}></span>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 6 }}>
        <GridBoard vals={vals} givens={vals.map(Boolean)} type={pal.type} sel={5} errors={conflict} marks={{ evidence: unsure }} />
      </div>
      <div style={{ margin: '14px 16px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 14, color: 'var(--ink2)', lineHeight: 1.4 }}><span style={{ width: 14, height: 14, borderRadius: 3, boxShadow: 'inset 0 0 0 1.5px var(--accent)', marginTop: 2, flexShrink: 0 }}></span><span><b style={{ color: 'var(--ink)', fontWeight: 600 }}>3 unsure.</b> Ringed cells were hard to read — tap to confirm or fix.</span></div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 14, color: 'var(--ink2)', lineHeight: 1.4 }}><span style={{ width: 14, height: 2, background: 'var(--err)', marginTop: 9, flexShrink: 0 }}></span><span><b style={{ color: 'var(--ink)', fontWeight: 600 }}>Two 4s in row 4.</b> Fix one before starting.</span></div>
      </div>
      <div style={{ flex: 1 }}></div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(9,1fr)', gap: 4, padding: '0 8px 10px' }}>
        {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => <button key={d} className="ps-key" style={{ height: 52, fontSize: 26, color: 'var(--ink)' }}>{d}</button>)}
      </div>
      <div style={{ display: 'flex', gap: 10, padding: '0 16px 40px' }}>
        <button className="ps-btn ps-btn-ghost" style={{ flex: 1, height: 46 }}>Clear cell</button>
        <button className="ps-btn" style={{ flex: 2, height: 46, opacity: 0.4 }} disabled>Start puzzle</button>
      </div>
    </div>
  );
}

Object.assign(window, { ImportSource, ImportReading, ImportReview });
