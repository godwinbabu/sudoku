export function Keypad({ remaining = {}, notesMode = false, clarity = 0, onDigit }) {
  const ui = [1, 1.06, 1.12][clarity];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(9,1fr)', gap: 4 }}>
      {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => {
        const left = remaining[d] ?? 9, done = left <= 0;
        return (
          <button key={d} disabled={done} onClick={() => onDigit && onDigit(d)} style={{ height: 64, border: 0, background: 'none', borderRadius: 12, padding: 0, cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 3, opacity: done ? 0.28 : 1, fontFamily: 'inherit' }}>
            {notesMode ? (
              <span style={{ width: 30, height: 30, display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gridTemplateRows: 'repeat(3,1fr)' }}>
                <span style={{ gridColumn: ((d - 1) % 3) + 1, gridRow: Math.floor((d - 1) / 3) + 1, fontSize: 13, fontWeight: 700, color: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{d}</span>
              </span>
            ) : <span style={{ fontSize: 30 * ui, color: 'var(--ink)', lineHeight: 1, height: 30, display: 'flex', alignItems: 'center' }}>{d}</span>}
            <span style={{ fontSize: 10.5, color: 'var(--ink3)', fontWeight: 500, fontVariantNumeric: 'tabular-nums', minHeight: 12 }}>{done ? '' : left}</span>
          </button>
        );
      })}
    </div>
  );
}
