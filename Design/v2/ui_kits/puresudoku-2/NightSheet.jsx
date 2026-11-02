/* global React, Ico, Seg, Toggle, Row */
const { useState: useStN } = React;
const PRESETS = [
  { k: 'lamp', l: 'Reading lamp', glow: 55, warmth: 45 },
  { k: 'out', l: 'Lights out', glow: 18, warmth: 75 },
  { k: 'red', l: 'Red light', glow: 10, warmth: 100 },
];

function NightSheet({ settings, setS, pal, onClose, initialCal }) {
  const [cal, setCal] = useStN(!!initialCal);
  const night = settings.appearance !== 'day';
  const K = pal.kelvin || 6500;
  const N = window.PSNight;
  const warmTrack = `linear-gradient(90deg, ${[0, 25, 50, 75, 100].map(w => { const c = N.kelvinRGB(N.warmthToK(w)), s = (pal.s || 1) * 0.75; return `rgb(${c.map(x => Math.round(x * s)).join(',')})`; }).join(',')})`;
  return (
    <div onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 60, background: night ? 'rgba(0,0,0,.55)' : 'rgba(40,30,10,.18)' }}>
      <div onClick={e => e.stopPropagation()} style={{ position: 'absolute', left: 0, right: 0, bottom: 0, background: night ? 'var(--bg)' : 'var(--bg)', borderTop: '1px solid var(--hair)', borderRadius: '28px 28px 0 0', padding: '8px 0 34px' }}>
        <div style={{ width: 36, height: 5, borderRadius: 3, background: 'var(--hair)', margin: '0 auto 6px' }}></div>
        {cal ? <Calibrate settings={settings} setS={setS} done={() => setCal(false)} /> : (
          <div>
            <div style={{ display: 'flex', alignItems: 'center', padding: '4px 12px 10px 22px' }}>
              <span className="ps-serif" style={{ fontSize: 26, flex: 1, color: 'var(--ink)' }}>Night</span>
              <button className="ps-icon" onClick={onClose} aria-label="Close"><Ico n="close" s={20} /></button>
            </div>
            <div style={{ padding: '0 22px 16px' }}>
              <Seg value={settings.appearance === 'system' ? 'day' : settings.appearance} onChange={v => setS({ appearance: v })} options={[['day', 'Day'], ['night', 'Night'], ['auto', 'After dark']]} />
              {settings.appearance === 'auto' && <div style={{ fontSize: 13, color: 'var(--ink3)', marginTop: 8 }}>Night from sunset (6:12 PM) to sunrise, worked out on this iPhone. Without location: 9:00 PM to 6:30 AM.</div>}
            </div>
            {night && (
              <div>
                <div style={{ display: 'flex', gap: 8, padding: '0 22px 18px' }}>
                  {PRESETS.map(p => {
                    const on = Math.abs(settings.glow - p.glow) < 3 && Math.abs(settings.warmth - p.warmth) < 3;
                    return <button key={p.k} onClick={() => setS({ glow: p.glow, warmth: p.warmth })} style={{ flex: 1, height: 36, borderRadius: 18, fontSize: 13, fontWeight: 500, color: on ? 'var(--accent)' : 'var(--ink2)', boxShadow: `inset 0 0 0 1.5px ${on ? 'var(--accentDim)' : 'var(--hair)'}` }}>{p.l}</button>;
                  })}
                </div>
                <SliderRow label="Glow" value={`${settings.glow}%`} sub={settings.glow < 35 ? 'Below your iPhone’s lowest brightness.' : 'How much light the screen gives off.'}>
                  <input className="ps-range" type="range" min="0" max="100" value={settings.glow} onChange={e => setS({ glow: +e.target.value })} aria-label="Glow" />
                </SliderRow>
                <SliderRow label="Warmth" value={`${K.toLocaleString()} K`} sub={`Blue light about ${pal.blueCut}% lower than daylight white.`}>
                  <input className="ps-range" type="range" min="0" max="100" value={settings.warmth} onChange={e => setS({ warmth: +e.target.value })} aria-label="Warmth" style={{ '--track': warmTrack }} />
                </SliderRow>
              </div>
            )}
            <div style={{ padding: '4px 22px 14px' }}>
              <div style={{ display: 'flex', alignItems: 'baseline', marginBottom: 8 }}><span style={{ fontSize: 16, color: 'var(--ink)', flex: 1 }}>Clarity</span></div>
              <Seg value={settings.clarity} onChange={v => setS({ clarity: v })} options={[[0, 'Standard'], [1, 'Large'], [2, 'Bold']]} />
              <div style={{ fontSize: 13, color: 'var(--ink3)', marginTop: 8, textWrap: 'pretty' }}>Bigger, heavier digits and stronger lines. Readable at lower glow.</div>
            </div>
            {night && (
              <div style={{ borderTop: '1px solid var(--hair)', margin: '4px 0 0' }}>
                <Row label="Drift" sub="Over 30 minutes, glow eases down and warmth eases up."><Toggle on={settings.drift} onChange={v => setS({ drift: v })} label="Drift" /></Row>
                <Row label="Find my lowest glow" sub="A 20-second check of what your eyes can read tonight." last><button onClick={() => setCal(true)} style={{ color: 'var(--accent)', fontSize: 15, fontWeight: 500 }}>Start</button></Row>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

function SliderRow({ label, value, sub, children }) {
  return (
    <div style={{ padding: '0 22px 16px' }}>
      <div style={{ display: 'flex', alignItems: 'baseline' }}><span style={{ fontSize: 16, color: 'var(--ink)', flex: 1 }}>{label}</span><span style={{ fontSize: 15, color: 'var(--ink2)', fontVariantNumeric: 'tabular-nums' }}>{value}</span></div>
      {children}
      <div style={{ fontSize: 13, color: 'var(--ink3)' }}>{sub}</div>
    </div>
  );
}

function Calibrate({ settings, setS, done, initialPick = null, first }) {
  const N = window.PSNight, levels = [0, 6, 14, 24, 38, 56];
  const [pick, setPick] = useStN(initialPick);
  return (
    <div style={{ padding: '6px 22px 8px' }}>
      <div className="ps-serif" style={{ fontSize: 24, color: 'var(--ink)' }}>Which is the faintest you can read?</div>
      <div style={{ fontSize: 14, color: 'var(--ink3)', margin: '6px 0 22px', textWrap: 'pretty' }}>Give your eyes a moment in the dark first. Tap the dimmest digit you can read without effort.</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6,1fr)', gap: 8 }}>
        {levels.map((g, i) => {
          const ink = N.palette({ ...settings, appearance: 'night', glow: g }).vars['--ink'];
          return (
            <button key={g} onClick={() => setPick(g)} style={{ height: 76, borderRadius: 12, boxShadow: `inset 0 0 0 ${pick === g ? 2 : 1}px ${pick === g ? 'var(--accent)' : 'var(--hair)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span style={{ fontSize: 30, color: ink, fontWeight: 500 }}>{[8, 3, 6, 5, 9, 2][i]}</span>
            </button>
          );
        })}
      </div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 22 }}>
        {!first && <button className="ps-btn ps-btn-ghost" onClick={done}>Cancel</button>}
        <button className="ps-btn" disabled={pick === null} style={{ opacity: pick === null ? 0.4 : 1 }} onClick={() => { setS({ glow: Math.min(100, pick + 4), glowFloor: pick, calibrated: true }); done(); }}>Use this</button>
      </div>
    </div>
  );
}

Object.assign(window, { NightSheet, Calibrate, SliderRow, PRESETS });
