/* global React, GridBoard, Keypad, ToolBtn, Ico */
const { useState: useStG, useEffect: useEfG, useMemo: useMemoG, useRef: useRefG } = React;
const LEVEL_NAMES = { easy: 'Easy', medium: 'Medium', hard: 'Hard', expert: 'Expert', master: 'Master' };
const TIER_NAMES = ['Beginner', 'Intermediate', 'Advanced', 'Expert', 'Esoteric'];
const fmtTime = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;

function newGame(diff) {
  const E = window.PSEngine, start = E.parse(E.PUZZLES[diff]), sol = E.solve(start);
  return { diff, start, sol, vals: start.slice(), notes: Array(81).fill(0), elapsed: 0, history: [], hints: 0, placedByHint: 0, checked: false, done: false };
}

function GameScreen({ game, setGame, settings, pal, onBack, openNight, onHush, onLesson, onGoodnight, onNew, demo }) {
  const E = window.PSEngine;
  const [sel, setSel] = useStG(() => game.vals.findIndex(v => !v));
  const [notesMode, setNotesMode] = useStG(!!(demo && demo.notes));
  const [hint, setHint] = useStG(() => { if (demo && demo.hint) { E.setNotation(settings.notation); return { h: E.findHint(game.vals, game.sol), level: demo.hint }; } return null; });
  const [paused, setPaused] = useStG(!!(demo && demo.paused));
  const [menu, setMenu] = useStG(!!(demo && demo.menu));
  const givens = useMemoG(() => game.start.map(v => !!v), [game.start]);

  useEfG(() => {
    if (paused || game.done || (demo && demo.frozen)) return;
    const id = setInterval(() => setGame(g => ({ ...g, elapsed: g.elapsed + 1 })), 1000);
    return () => clearInterval(id);
  }, [paused, game.done]);

  const errors = useMemoG(() => {
    if (settings.mistakes === 'never' || (settings.mistakes === 'check' && !game.checked)) return new Set();
    return new Set(game.vals.map((v, i) => (v && !givens[i] && v !== game.sol[i] ? i : -1)).filter(i => i >= 0));
  }, [game.vals, game.checked, settings.mistakes]);

  const remaining = useMemoG(() => { const r = {}; for (let d = 1; d <= 9; d++) r[d] = 9 - game.vals.filter(v => v === d).length; return r; }, [game.vals]);

  function commit(mut) {
    setGame(g => {
      const n = { ...g, vals: g.vals.slice(), notes: g.notes.slice(), history: [...g.history.slice(-80), { vals: g.vals, notes: g.notes }], checked: false };
      mut(n);
      n.done = n.vals.every((v, i) => v === n.sol[i]);
      return n;
    });
  }
  function place(d) {
    if (sel < 0 || givens[sel] || game.done) return;
    commit(n => {
      if (notesMode) { if (!n.vals[sel]) n.notes[sel] ^= (1 << d); return; }
      n.vals[sel] = n.vals[sel] === d ? 0 : d; n.notes[sel] = 0;
      if (n.vals[sel] && settings.autoRemove) E.PEERS[sel].forEach(p => { n.notes[p] &= ~(1 << d); });
    });
    if (hint && !notesMode && hint.h.cell === sel && hint.h.digit === d) setHint(null);
  }
  function erase() { if (sel < 0 || givens[sel]) return; commit(n => { n.vals[sel] = 0; n.notes[sel] = 0; }); }
  function undo() { setGame(g => { if (!g.history.length) return g; const last = g.history[g.history.length - 1]; return { ...g, vals: last.vals, notes: last.notes, history: g.history.slice(0, -1), done: false }; }); }
  function fillNotes() { commit(n => { for (let i = 0; i < 81; i++) n.notes[i] = n.vals[i] ? 0 : E.candMask(n.vals, i); }); setMenu(false); }

  function hintStep() {
    if (!hint) { E.setNotation(settings.notation); const h = E.findHint(game.vals, game.sol); if (h) { setHint({ h, level: 1 }); setGame(g => ({ ...g, hints: g.hints + 1 })); } return; }
    if (hint.level < 3) { setHint({ ...hint, level: hint.level + 1 }); return; }
    const h = hint.h;
    if (h.kind === 'mistake') commit(n => { n.vals[h.cell] = 0; });
    else commit(n => { n.vals[h.cell] = h.digit; n.notes[h.cell] = 0; if (settings.autoRemove) E.PEERS[h.cell].forEach(p => { n.notes[p] &= ~(1 << h.digit); }); });
    setGame(g => ({ ...g, placedByHint: g.placedByHint + 1, assisted: h.kind !== 'mistake' ? true : g.assisted }));
    setSel(h.cell); setHint(null);
  }

  const marks = useMemoG(() => {
    if (!hint) return {};
    const h = hint.h, L = hint.level;
    const focus = new Set([...h.focus, ...(L >= 2 ? h.pattern : []), ...(L >= 3 ? h.evidence : []), h.cell]);
    return { spotlight: true, focus, pattern: L >= 2 ? new Set(h.pattern) : null, elim: L >= 3 ? new Set(h.elim) : null, evidence: L >= 3 ? new Set(h.evidence) : null, target: L >= 3 ? h.cell : -1, ghost: L >= 3 && h.kind !== 'mistake' ? h.digit : 0 };
  }, [hint]);

  const needed = useMemoG(() => (game.done ? E.techniquesNeeded(game.start, game.sol) : null), [game.done]);
  const twoFinger = e => { if (e.touches && e.touches.length >= 2) onHush(); };

  return (
    <div onTouchStart={twoFinger} style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', paddingTop: 54 }}>
      <div style={{ height: 48, display: 'flex', alignItems: 'center', padding: '0 10px', gap: 4 }}>
        <button className="ps-icon" onClick={onBack} aria-label="Back"><Ico n="back" /></button>
        <button onClick={() => setPaused(p => !p)} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 1, color: 'var(--ink2)' }}>
          <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)' }}>{LEVEL_NAMES[game.diff]}</span>
          {settings.showTimer && <span style={{ fontSize: 15, fontWeight: 500, fontVariantNumeric: 'tabular-nums', display: 'flex', alignItems: 'center', gap: 5 }}>{fmtTime(game.elapsed)}{paused && <Ico n="pause" s={12} />}</span>}
        </button>
        <button className="ps-icon" onClick={openNight} aria-label="Night settings"><Ico n="moon" /></button>
        <button className="ps-icon" onClick={() => setMenu(m => !m)} aria-label="More"><Ico n="more" w={3} /></button>
      </div>

      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 6, position: 'relative' }}>
        <div style={{ opacity: game.done ? 0.3 : 1, transition: 'opacity .6s ease' }}>
          {paused ? (
            <div style={{ width: 366, height: 366, border: '1px solid var(--hair)', borderRadius: 6, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14 }}>
              <span className="ps-serif" style={{ fontSize: 28, color: 'var(--ink)' }}>Paused</span>
              <button className="ps-btn" onClick={() => setPaused(false)}>Resume</button>
            </div>
          ) : (
            <GridBoard vals={game.vals} givens={givens} notes={game.notes} sel={hint ? -1 : sel} type={pal.type} marks={marks} errors={errors} onSelect={i => { setSel(i); }} />
          )}
        </div>
        {game.done && <SolvedPanel game={game} needed={needed} onGoodnight={onGoodnight} onNew={onNew} />}
      </div>

      <div style={{ height: 124, margin: '12px 12px 0', display: 'flex', alignItems: 'stretch' }}>
        {hint && !game.done && <HintCard hint={hint} onNext={hintStep} onClose={() => setHint(null)} onLesson={onLesson} />}
        {!hint && !game.done && notesMode && <div style={{ alignSelf: 'center', width: '100%', textAlign: 'center', fontSize: 13, color: 'var(--ink3)' }}>Notes on — digits go in as pencil marks</div>}
      </div>

      <div style={{ flex: 1 }}></div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', padding: '0 18px', opacity: game.done ? 0.3 : 1 }}>
        <ToolBtn icon="undo" label="Undo" onClick={undo} disabled={!game.history.length} />
        <ToolBtn icon="erase" label="Erase" onClick={erase} />
        <ToolBtn icon="pencil" label="Notes" onClick={() => setNotesMode(m => !m)} active={notesMode} badge={notesMode ? 'ON' : 'OFF'} />
        <ToolBtn icon="hint" label={hint ? 'Next step' : 'Hint'} onClick={hintStep} active={!!hint} />
      </div>
      <div style={{ padding: '6px 8px 30px', opacity: game.done ? 0.3 : 1 }}>
        <Keypad onDigit={place} notesMode={notesMode} remaining={remaining} type={pal.type} />
      </div>

      {menu && (
        <div onClick={() => setMenu(false)} style={{ position: 'absolute', inset: 0, zIndex: 40 }}>
          <div onClick={e => e.stopPropagation()} className="ps-pop" style={{ position: 'absolute', top: 104, right: 12, width: 230 }}>
            {[['Check puzzle', () => { setGame(g => ({ ...g, checked: true })); setMenu(false); }], ['Fill all notes', fillNotes], ['Restart puzzle', () => { setGame(() => newGame(game.diff)); setMenu(false); setHint(null); }], ['Hush screen', () => { setMenu(false); onHush(); }]].map(([l, f], k) => (
              <button key={l} onClick={f} style={{ display: 'flex', justifyContent: 'space-between', width: '100%', padding: '13px 16px', fontSize: 15, color: 'var(--ink)', borderTop: k ? '1px solid var(--hair)' : 'none' }}>
                <span>{l}</span>{l === 'Hush screen' && <span style={{ fontSize: 12, color: 'var(--ink3)' }}>2-finger tap</span>}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function HintCard({ hint, onNext, onClose, onLesson }) {
  const { h, level } = hint, mistake = h.kind === 'mistake';
  const label = ['', 'Where to look', mistake ? 'Mistake' : 'Technique', 'Why'][level];
  const cta = level === 1 ? (mistake ? 'Show me' : 'Which technique?') : level === 2 ? 'Show me why' : mistake ? 'Clear it' : `Place ${h.digit} · assisted`;
  const hasLesson = ['Hidden Single', 'Naked Pair', 'Naked Single', 'Full House', 'Pointing', 'Claiming'].includes(h.technique);
  return (
    <div className="ps-card" style={{ flex: 1, padding: '12px 14px 12px 16px', display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ display: 'flex', gap: 4 }}>{[1, 2, 3].map(n => <span key={n} style={{ width: n === level ? 14 : 5, height: 5, borderRadius: 3, background: n <= level ? 'var(--accent)' : 'var(--hair)' }}></span>)}</div>
        <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)' }}>{label}</span>
        {level >= 2 && !mistake && h.tier >= 0 && <span style={{ fontSize: 11, color: 'var(--ink3)' }}>· {TIER_NAMES[h.tier] || 'Advanced'}</span>}
        <span style={{ flex: 1 }}></span>
        <button onClick={onClose} aria-label="Close hint" style={{ color: 'var(--ink3)', padding: 4, margin: -4 }}><Ico n="close" s={16} /></button>
      </div>
      <div style={{ flex: 1, minHeight: 0 }}>
        {level === 2 && !mistake && <div className="ps-serif" style={{ fontSize: 21, color: 'var(--ink)', marginBottom: 2 }}>{h.technique}</div>}
        <div style={{ fontSize: level === 1 ? 16 : 14, lineHeight: 1.35, color: level === 1 ? 'var(--ink)' : 'var(--ink2)', textWrap: 'pretty' }}>{level === 1 ? h.nudge : level === 2 ? (mistake ? h.why : h.short) : h.why}</div>
      </div>
      <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', alignItems: 'center' }}>
        {level >= 2 && hasLesson && <button onClick={() => onLesson(h.technique)} style={{ fontSize: 13, color: 'var(--ink2)', padding: '6px 4px', marginRight: 'auto' }}>Lesson →</button>}
        <button className="ps-btn ps-btn-sm" onClick={onNext}>{cta}</button>
      </div>
    </div>
  );
}

function SolvedPanel({ game, needed, onGoodnight, onNew }) {
  const list = needed ? Object.entries(needed).sort((a, b) => b[1] - a[1]) : [];
  return (
    <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10, textAlign: 'center', padding: '0 40px' }}>
      <span className="ps-serif" style={{ fontSize: 44, color: 'var(--ink)', lineHeight: 1 }}>Solved.</span>
      <span style={{ fontSize: 15, color: 'var(--ink2)', fontVariantNumeric: 'tabular-nums' }}>{LEVEL_NAMES[game.diff]} · {fmtTime(game.elapsed)}{game.hints ? ` · ${game.hints} hint${game.hints > 1 ? 's' : ''}` : ''}</span>
      {game.assisted && <span style={{ fontSize: 13, color: 'var(--ink2)', padding: '4px 10px', borderRadius: 12, boxShadow: 'inset 0 0 0 1px var(--hair)' }}>Assisted · counts for your streak, not best times</span>}
      <div style={{ fontSize: 13, color: 'var(--ink3)', lineHeight: 1.5, marginTop: 4 }}>This grid took {list.map(([t, n]) => `${t} ×${n}`).join(', ')}.</div>
      <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
        <button className="ps-btn ps-btn-ghost" onClick={onNew}>Another</button>
        <button className="ps-btn" onClick={onGoodnight}>Goodnight</button>
      </div>
    </div>
  );
}

Object.assign(window, { GameScreen, newGame, fmtTime, LEVEL_NAMES, TIER_NAMES });
