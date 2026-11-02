const LABELS = ['', 'Where to look', 'Technique', 'Why'];
export function HintCard({ level = 1, technique, tier, text, cta, onNext, onClose, onLesson, night = false }) {
  return (
    <div style={{ background: night ? 'transparent' : 'var(--surface)', border: '1px solid var(--hair)', borderRadius: 18, padding: '12px 14px 12px 16px', display: 'flex', flexDirection: 'column', gap: 6, minHeight: 124, boxSizing: 'border-box' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ display: 'flex', gap: 4 }}>{[1, 2, 3].map(n => <span key={n} style={{ width: n === level ? 14 : 5, height: 5, borderRadius: 3, background: n <= level ? 'var(--accent)' : 'var(--hair)' }}></span>)}</div>
        <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)' }}>{LABELS[level]}</span>
        {level >= 2 && tier && <span style={{ fontSize: 11, color: 'var(--ink3)' }}>· {tier}</span>}
        <span style={{ flex: 1 }}></span>
        {onClose && <button onClick={onClose} aria-label="Close hint" style={{ border: 0, background: 'none', color: 'var(--ink3)', cursor: 'pointer', fontSize: 16 }}>×</button>}
      </div>
      <div style={{ flex: 1 }}>
        {level === 2 && technique && <div style={{ fontFamily: 'var(--font-display)', fontWeight: 500, fontSize: 21, color: 'var(--ink)', marginBottom: 2 }}>{technique}</div>}
        <div style={{ fontSize: level === 1 ? 16 : 14, lineHeight: 1.35, color: level === 1 ? 'var(--ink)' : 'var(--ink2)', textWrap: 'pretty' }}>{text}</div>
      </div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'flex-end' }}>
        {onLesson && level >= 2 && <button onClick={onLesson} style={{ border: 0, background: 'none', fontSize: 13, color: 'var(--ink2)', marginRight: 'auto', cursor: 'pointer', fontFamily: 'inherit' }}>Lesson →</button>}
        <button onClick={onNext} style={{ height: 34, padding: '0 14px', borderRadius: 17, border: 0, cursor: 'pointer', fontFamily: 'inherit', fontSize: 14, fontWeight: 600, background: night ? 'transparent' : 'var(--accent)', color: night ? 'var(--accent)' : 'var(--bg)', boxShadow: night ? 'inset 0 0 0 1.5px var(--accentDim)' : 'none' }}>{cta}</button>
      </div>
    </div>
  );
}
