/* global React, Ico, Seg, Toggle, Row, SectionLabel, Calibrate, SliderRow, PRESETS */
const { useState: useStD } = React;

function SamplePreview() {
  const c = { width: 52, height: 52, borderRadius: 4, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', boxShadow: 'inset 0 0 0 1px var(--line)' };
  return (
    <div style={{ display: 'flex', gap: 10, justifyContent: 'center', padding: '18px 0' }}>
      <div style={c}><span style={{ fontSize: 30, fontWeight: 600, color: 'var(--ink)' }}>5</span></div>
      <div style={c}><span style={{ fontSize: 30, color: 'var(--accent)' }}>3</span></div>
      <div style={{ ...c, background: 'var(--sel)', boxShadow: 'inset 0 0 0 2px var(--accent)' }}><span style={{ fontSize: 30, color: 'var(--accent)' }}>7</span></div>
      <div style={c}><span style={{ fontSize: 30, color: 'var(--err)', position: 'relative' }}>4<span style={{ position: 'absolute', left: -3, right: -3, bottom: -5, height: 2, background: 'var(--err)' }}></span></span></div>
      <div style={c}><div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', width: 42, fontSize: 11, lineHeight: '14px', textAlign: 'center', color: 'var(--ink2)' }}><span>1</span><span></span><span>3</span><span></span><span></span><span></span><span style={{ color: 'var(--accent)', fontWeight: 700 }}>7</span><span></span><span>9</span></div></div>
    </div>
  );
}

const APPEARANCES = [
  ['day', 'Day', 'Warm paper. For daylight and lamps.'],
  ['night', 'Night', 'Black screen, warm digits, silent.'],
  ['auto', 'After dark', 'Sunset to sunrise where you are.'],
  ['system', 'Match iPhone', 'Follows Light and Dark in iOS Settings.'],
];

function AfterDarkHours({ settings, setS }) {
  const loc = settings.location !== false;
  return (
    <div style={{ borderTop: '1px solid var(--hair)', padding: '12px 16px 14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ display: 'flex', alignItems: 'baseline' }}>
        <span style={{ fontSize: 15, color: 'var(--ink)', flex: 1 }}>{loc ? 'Tonight' : 'Hours'}</span>
        <span style={{ fontSize: 15, color: 'var(--ink2)', fontVariantNumeric: 'tabular-nums' }}>{loc ? 'Sunset 6:12 PM → sunrise 6:41 AM' : '9:00 PM → 6:30 AM'}</span>
      </div>
      <div style={{ fontSize: 13, color: 'var(--ink3)', lineHeight: 1.45, textWrap: 'pretty' }}>{loc ? 'Worked out on this iPhone from your rough location and the date. Nothing leaves the phone.' : 'No location, so fixed hours are used. Tap a time to change it.'}</div>
      <div style={{ display: 'flex', gap: 8 }}>
        <button onClick={() => setS({ location: !loc })} style={{ height: 32, padding: '0 12px', borderRadius: 16, fontSize: 13, color: 'var(--ink2)', boxShadow: 'inset 0 0 0 1px var(--hair)' }}>{loc ? 'Use fixed hours instead' : 'Use sunset and sunrise'}</button>
      </div>
    </div>
  );
}

function DisplaySettings({ settings, setS, pal, onBack, onCalibrate }) {
  const K = pal.kelvin || 6500, N = window.PSNight;
  const warmTrack = `linear-gradient(90deg, ${[0, 25, 50, 75, 100].map(w => { const c = N.kelvinRGB(N.warmthToK(w)), s = (pal.s || 1) * 0.75; return `rgb(${c.map(x => Math.round(x * s)).join(',')})`; }).join(',')})`;
  return (
    <div className="ps-scroll" style={{ position: 'absolute', inset: 0, paddingTop: 54, paddingBottom: 40 }}>
      <div style={{ height: 48, padding: '0 10px', display: 'flex', alignItems: 'center' }}><button className="ps-icon" onClick={onBack} aria-label="Back"><Ico n="back" /></button></div>
      <div className="ps-serif" style={{ fontSize: 30, color: 'var(--ink)', padding: '0 22px 4px' }}>Display &amp; Night</div>
      <div className="ps-card" style={{ margin: '10px 16px 24px' }}><SamplePreview /></div>

      <SectionLabel>Appearance</SectionLabel>
      <div className="ps-card" style={{ margin: '0 16px 24px' }}>
        {APPEARANCES.map(([k, l, sub], i) => (
          <button key={k} onClick={() => setS({ appearance: k })} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', textAlign: 'left', borderBottom: i < 3 ? '1px solid var(--hair)' : 'none' }}>
            <span style={{ flex: 1 }}><span style={{ display: 'block', fontSize: 16, color: 'var(--ink)' }}>{l}</span><span style={{ display: 'block', fontSize: 13, color: 'var(--ink3)', marginTop: 2 }}>{sub}</span></span>
            <span style={{ width: 24, color: 'var(--accent)' }}>{settings.appearance === k && <Ico n="check" s={20} w={2.2} />}</span>
          </button>
        ))}
        {settings.appearance === 'auto' && <AfterDarkHours settings={settings} setS={setS} />}
      </div>

      <SectionLabel>Night screen</SectionLabel>
      <div style={{ display: 'flex', gap: 8, padding: '0 22px 18px' }}>
        {PRESETS.map(p => { const on = Math.abs(settings.glow - p.glow) < 3 && Math.abs(settings.warmth - p.warmth) < 3; return <button key={p.k} onClick={() => setS({ glow: p.glow, warmth: p.warmth })} style={{ flex: 1, height: 36, borderRadius: 18, fontSize: 13, fontWeight: 500, color: on ? 'var(--accent)' : 'var(--ink2)', boxShadow: `inset 0 0 0 1.5px ${on ? 'var(--accentDim)' : 'var(--hair)'}` }}>{p.l}</button>; })}
      </div>
      <SliderRow label="Glow" value={`${settings.glow}%`} sub={pal.mode === 'day' ? 'Applies when Night is on.' : settings.glow < 35 ? 'Below your iPhone’s lowest brightness.' : 'How much light the screen gives off.'}>
        <input className="ps-range" type="range" min="0" max="100" value={settings.glow} onChange={e => setS({ glow: +e.target.value })} aria-label="Glow" />
      </SliderRow>
      <SliderRow label="Warmth" value={`${(N.warmthToK(settings.warmth)).toLocaleString()} K`} sub="Higher is warmer, with less blue light.">
        <input className="ps-range" type="range" min="0" max="100" value={settings.warmth} onChange={e => setS({ warmth: +e.target.value })} aria-label="Warmth" style={{ '--track': warmTrack }} />
      </SliderRow>

      <SectionLabel style={{ paddingTop: 8 }}>Your eyes</SectionLabel>
      <div className="ps-card" style={{ margin: '0 16px 24px' }}>
        <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--hair)' }}>
          <div style={{ fontSize: 16, color: 'var(--ink)', marginBottom: 10 }}>Clarity</div>
          <Seg value={settings.clarity} onChange={v => setS({ clarity: v })} options={[[0, 'Standard'], [1, 'Large'], [2, 'Bold']]} />
          <div style={{ fontSize: 13, color: 'var(--ink3)', marginTop: 8 }}>Bigger, heavier digits and stronger lines. Day and Night.</div>
        </div>
        <Row label="Lowest readable glow" sub={settings.glowFloor ? `Set at ${settings.glowFloor}%. Glow and Drift never go below it.` : 'Not set yet.'} last><button onClick={onCalibrate} style={{ color: 'var(--accent)', fontSize: 15, fontWeight: 500 }}>Check again</button></Row>
      </div>

      <SectionLabel>Quiet</SectionLabel>
      <div className="ps-card" style={{ margin: '0 16px 24px' }}>
        <Row label="Drift" sub="Over 30 minutes, glow eases down and warmth eases up."><Toggle on={settings.drift} onChange={v => setS({ drift: v })} label="Drift" /></Row>
        <Row label="Hide status bar in games" sub="Clock and battery give off light too."><Toggle on={settings.hideStatus !== false} onChange={v => setS({ hideStatus: v })} label="Hide status bar" /></Row>
        <Row label="Sounds"><Toggle on={!!settings.sounds} onChange={v => setS({ sounds: v })} label="Sounds" /></Row>
        <Row label="Vibration" sub="Night always keeps sound and vibration off." last><Toggle on={!!settings.haptics} onChange={v => setS({ haptics: v })} label="Vibration" /></Row>
      </div>
      <div style={{ padding: '0 22px', fontSize: 13, color: 'var(--ink3)', lineHeight: 1.5 }}>Hush: tap with two fingers anywhere in a game to turn the screen black. Tap again to come back.</div>
    </div>
  );
}

function FirstNight({ settings, setS, onDone, initialStep = 'intro', initialPick = null, pal }) {
  const [step, setStep] = useStD(initialStep);
  if (step === 'cal') return <div style={{ position: 'absolute', inset: 0, paddingTop: 130 }}><Calibrate settings={settings} setS={p => { const { calibrated, ...rest } = p; setS(rest); }} done={() => setStep('done')} initialPick={initialPick} first /></div>;
  const done = step === 'done';
  return (
    <div style={{ position: 'absolute', inset: 0, padding: '150px 30px 60px', display: 'flex', flexDirection: 'column' }}>
      <span style={{ color: 'var(--accent)' }}><Ico n="moon" s={30} /></span>
      <div className="ps-serif" style={{ fontSize: 36, color: 'var(--ink)', margin: '22px 0 12px', lineHeight: 1.1 }}>{done ? `Glow set to ${settings.glow}%.` : 'Good evening.'}</div>
      <div style={{ fontSize: 17, color: 'var(--ink2)', lineHeight: 1.45, textWrap: 'pretty' }}>
        {done ? `Warmth is ${(pal.kelvin || 0).toLocaleString()} K. You can change both any time from the moon at the top of every screen.` : 'Before your first puzzle, let’s set the screen for your eyes and this room. It takes twenty seconds, and nothing will flash.'}
      </div>
      {done && <div style={{ marginTop: 28 }}><SamplePreview /></div>}
      <div style={{ flex: 1 }}></div>
      <button className="ps-btn" style={{ width: '100%', height: 50 }} onClick={() => (done ? onDone() : setStep('cal'))}>{done ? 'Start playing' : 'Find my lowest glow'}</button>
      {!done && <button onClick={() => { setS({ glow: 18, warmth: 75, calibrated: true }); onDone(); }} style={{ marginTop: 16, fontSize: 15, color: 'var(--ink3)', height: 44 }}>Skip for now — use Lights out</button>}
    </div>
  );
}

Object.assign(window, { DisplaySettings, FirstNight, SamplePreview });
