/* global React, GridBoard, Ico, fmtTime, LEVEL_NAMES */
const LEVELS = [
  { k: 'easy', ceil: 'Singles only', n: 1 },
  { k: 'medium', ceil: 'Pointing & claiming', n: 2 },
  { k: 'hard', ceil: 'Pairs & triples', n: 3 },
  { k: 'expert', ceil: 'Wings & fish', n: 4 },
  { k: 'master', ceil: 'Chains & beyond', n: 5 },
];

function TabBar({ tab, setTab }) {
  const items = [['play', 'Play', 'grid'], ['learn', 'Learn', 'book'], ['journal', 'Journal', 'journal']];
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 84, borderTop: '1px solid var(--hair)', background: 'var(--bg)', display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', paddingTop: 8, zIndex: 20 }}>
      {items.map(([k, l, ic]) => (
        <button key={k} onClick={() => setTab(k)} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, color: tab === k ? 'var(--accent)' : 'var(--ink3)' }}>
          <Ico n={ic} s={22} w={tab === k ? 2 : 1.6} /><span style={{ fontSize: 11, fontWeight: tab === k ? 600 : 500 }}>{l}</span>
        </button>
      ))}
    </div>
  );
}

function ScreenHead({ title, openNight, right }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '0 12px 0 22px', height: 52 }}>
      <span className="ps-serif" style={{ fontSize: 30, color: 'var(--ink)', flex: 1 }}>{title}</span>
      {right}
      <button className="ps-icon" onClick={openNight} aria-label="Night settings"><Ico n="moon" /></button>
    </div>
  );
}

function SectionLabel({ children, style }) {
  return <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)', padding: '0 22px 8px', ...style }}>{children}</div>;
}

function HomeScreen({ games, onPlay, openNight, pal, stats }) {
  const live = Object.values(games).filter(g => g && !g.done).sort((a, b) => (b.touched || 0) - (a.touched || 0))[0];
  const filled = live ? live.vals.filter(Boolean).length : 0;
  return (
    <div className="ps-scroll" style={{ position: 'absolute', inset: 0, paddingTop: 54, paddingBottom: 96 }}>
      <ScreenHead title="Pure Sudoku" openNight={openNight} />
      <div style={{ padding: '0 22px 20px', fontSize: 14, color: 'var(--ink3)' }}>Saturday night · {stats.streak}-night streak</div>

      {live && (
        <button onClick={() => onPlay(live.diff)} className="ps-card" style={{ margin: '0 16px 26px', width: 'calc(100% - 32px)', padding: 14, display: 'flex', gap: 16, alignItems: 'center', textAlign: 'left' }}>
          <div style={{ pointerEvents: 'none' }}><GridBoard vals={live.vals} givens={live.start.map(Boolean)} width={112} type={{ ...pal.type, digit: 1, line: 1 }} /></div>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span style={{ fontSize: 12, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)' }}>Continue</span>
            <span className="ps-serif" style={{ fontSize: 24, color: 'var(--ink)' }}>{LEVEL_NAMES[live.diff]}</span>
            <span style={{ fontSize: 14, color: 'var(--ink2)', fontVariantNumeric: 'tabular-nums' }}>{fmtTime(live.elapsed)} · {filled} of 81</span>
            <span style={{ height: 3, borderRadius: 2, background: 'var(--hair)', marginTop: 4, overflow: 'hidden' }}><span style={{ display: 'block', height: '100%', width: `${(filled / 81) * 100}%`, background: 'var(--accentDim)' }}></span></span>
          </div>
        </button>
      )}

      <SectionLabel>New puzzle</SectionLabel>
      <div style={{ margin: '0 16px', borderTop: '1px solid var(--hair)' }}>
        {LEVELS.map(L => (
          <button key={L.k} onClick={() => onPlay(L.k, true)} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 14, padding: '0 6px', height: 64, borderBottom: '1px solid var(--hair)', textAlign: 'left' }}>
            <span style={{ display: 'flex', gap: 3, alignItems: 'flex-end', width: 26 }}>{[1, 2, 3, 4, 5].map(n => <span key={n} style={{ width: 3, height: 4 + n * 2.6, borderRadius: 1, background: n <= L.n ? 'var(--accent)' : 'var(--hair)' }}></span>)}</span>
            <span style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
              <span style={{ fontSize: 17, color: 'var(--ink)', fontWeight: 500 }}>{LEVEL_NAMES[L.k]}</span>
              <span style={{ fontSize: 13, color: 'var(--ink3)' }}>{L.ceil}</span>
            </span>
            <span style={{ fontSize: 13, color: 'var(--ink3)', fontVariantNumeric: 'tabular-nums' }}>{stats.best[L.k] ? `Best ${fmtTime(stats.best[L.k])}` : ''}</span>
            <span style={{ color: 'var(--ink3)' }}><Ico n="chev" s={16} /></span>
          </button>
        ))}
      </div>
      <button style={{ margin: '18px 22px 0', display: 'flex', alignItems: 'center', gap: 10, color: 'var(--ink2)', fontSize: 15, height: 44 }}><Ico n="camera" s={20} />Import a puzzle from a photo</button>
    </div>
  );
}

function Toggle({ on, onChange, label }) {
  return <button role="switch" aria-checked={on} aria-label={label} className="ps-tog" data-on={on ? '1' : '0'} onClick={() => onChange(!on)}><span></span></button>;
}
function Seg({ value, options, onChange }) {
  return <div className="ps-seg">{options.map(([v, l]) => <button key={v} aria-pressed={value === v} onClick={() => onChange(v)}>{l}</button>)}</div>;
}
function Row({ label, sub, children, last }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', minHeight: 52, boxSizing: 'border-box', borderBottom: last ? 'none' : '1px solid var(--hair)' }}>
      <div style={{ flex: 1 }}><div style={{ fontSize: 16, color: 'var(--ink)' }}>{label}</div>{sub && <div style={{ fontSize: 13, color: 'var(--ink3)', marginTop: 2, textWrap: 'pretty' }}>{sub}</div>}</div>
      {children}
    </div>
  );
}

function JournalScreen({ stats, settings, setS, openNight, onOpenDisplay }) {
  const week = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return (
    <div className="ps-scroll" style={{ position: 'absolute', inset: 0, paddingTop: 54, paddingBottom: 100 }}>
      <ScreenHead title="Journal" openNight={openNight} />
      <div style={{ padding: '6px 22px 26px', display: 'flex', alignItems: 'flex-end', gap: 18 }}>
        <div><div className="ps-serif" style={{ fontSize: 56, lineHeight: 1, color: 'var(--ink)' }}>{stats.streak}</div><div style={{ fontSize: 14, color: 'var(--ink3)', marginTop: 4 }}>nights in a row</div></div>
        <div style={{ flex: 1, display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 4, paddingBottom: 4 }}>
          {week.map((d, i) => <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}><span style={{ width: 10, height: 10, borderRadius: 5, background: i < 6 ? 'var(--accent)' : 'transparent', boxShadow: i < 6 ? 'none' : 'inset 0 0 0 1.5px var(--ink3)' }}></span><span style={{ fontSize: 11, color: 'var(--ink3)' }}>{d}</span></div>)}
        </div>
      </div>

      <SectionLabel>Solved</SectionLabel>
      <div className="ps-card" style={{ margin: '0 16px 26px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 60px 70px 70px', padding: '10px 16px', fontSize: 12, color: 'var(--ink3)', borderBottom: '1px solid var(--hair)' }}><span></span><span style={{ textAlign: 'right' }}>Solved</span><span style={{ textAlign: 'right' }}>Best</span><span style={{ textAlign: 'right' }}>Typical</span></div>
        {LEVELS.map((L, i) => (
          <div key={L.k} style={{ display: 'grid', gridTemplateColumns: '1fr 60px 70px 70px', padding: '12px 16px', fontSize: 15, color: 'var(--ink2)', fontVariantNumeric: 'tabular-nums', borderBottom: i < 4 ? '1px solid var(--hair)' : 'none' }}>
            <span style={{ color: 'var(--ink)' }}>{LEVEL_NAMES[L.k]}</span><span style={{ textAlign: 'right' }}>{stats.solved[L.k] || '—'}</span><span style={{ textAlign: 'right' }}>{stats.best[L.k] ? fmtTime(stats.best[L.k]) : '—'}</span><span style={{ textAlign: 'right' }}>{stats.typical[L.k] ? fmtTime(stats.typical[L.k]) : '—'}</span>
          </div>
        ))}
        <div style={{ padding: '10px 16px', fontSize: 13, color: 'var(--ink3)', borderTop: '1px solid var(--hair)' }}>{stats.assisted || 0} assisted solves kept your streak but don’t set best times.</div>
      </div>

      <SectionLabel>Settings</SectionLabel>
      <div className="ps-card" style={{ margin: '0 16px 26px' }}>
        <button onClick={onOpenDisplay} style={{ width: '100%', textAlign: 'left' }}><Row label="Display & Night" sub="Day, Night, glow, warmth, clarity, quiet" last><span style={{ color: 'var(--ink3)' }}><Ico n="chev" s={16} /></span></Row></button>
      </div>
      <SectionLabel>Assists</SectionLabel>
      <div className="ps-card" style={{ margin: '0 16px 26px' }}>
        <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--hair)' }}>
          <div style={{ fontSize: 16, color: 'var(--ink)', marginBottom: 10 }}>Show mistakes</div>
          <Seg value={settings.mistakes} onChange={v => setS({ mistakes: v })} options={[['immediate', 'Right away'], ['check', 'When I check'], ['never', 'Never']]} />
        </div>
        <Row label="Tidy notes" sub="Placing a digit removes it from notes in the same row, column and box."><Toggle on={settings.autoRemove} onChange={v => setS({ autoRemove: v })} label="Tidy notes" /></Row>
        <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--hair)' }}>
          <div style={{ fontSize: 16, color: 'var(--ink)', marginBottom: 10 }}>Cell names in hints</div>
          <Seg value={settings.notation || 'plain'} onChange={v => setS({ notation: v })} options={[['plain', 'row 5, column 2'], ['grid', 'R5C2']]} />
          <div style={{ fontSize: 13, color: 'var(--ink3)', marginTop: 8 }}>{settings.notation === 'grid' ? 'Short grid codes: R for row, C for column, B for box.' : 'Written out in words.'}</div>
        </div>
        <Row label="Show timer" last><Toggle on={settings.showTimer} onChange={v => setS({ showTimer: v })} label="Show timer" /></Row>
      </div>
      <SectionLabel>Privacy</SectionLabel>
      <div style={{ padding: '0 22px', fontSize: 14, lineHeight: 1.5, color: 'var(--ink3)', textWrap: 'pretty' }}>Everything stays on this iPhone. No account, no network, no analytics. Silent by design — no sounds or vibration unless you turn them on.</div>
    </div>
  );
}

Object.assign(window, { HomeScreen, JournalScreen, TabBar, ScreenHead, SectionLabel, Toggle, Seg, Row, LEVELS });
