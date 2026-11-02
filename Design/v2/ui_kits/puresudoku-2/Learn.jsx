/* global React, GridBoard, Ico, ScreenHead, SectionLabel, TIER_NAMES */
const { useState: useStL } = React;

const TECHNIQUES = [
  ['Full House', 0, 'The last empty cell in a row, column or box.', 'mastered', 31],
  ['Naked Single', 0, 'A cell that can only hold one digit.', 'mastered', 58],
  ['Hidden Single', 0, 'A digit with only one home in a unit.', 'mastered', 112],
  ['Pointing', 1, 'A box confines a digit to one line.', 'learning', 4],
  ['Claiming', 1, 'A line confines a digit to one box.', 'new', 0],
  ['Naked Pair', 1, 'Two cells, two candidates, locked together.', 'new', 0],
  ['Naked Triple', 1, 'The same idea with three cells and three digits.', 'new', 0],
  ['Naked Quad', 1, 'Four cells holding exactly four digits.', 'new', 0],
  ['X-Wing', 2, 'One digit, two rows, the same two columns.', 'new', 0],
  ['Y-Wing', 2, 'A pivot cell and two pincers that share a digit.', 'new', 0],
  ['Swordfish', 2, 'X-Wing stretched across three rows.', 'new', 0],
  ['XY-Chain', 3, 'A chain of two-candidate cells that forces a result.', 'new', 0],
  ['Unique Rectangle', 3, 'Avoiding a pattern that would allow two solutions.', 'new', 0],
  ['3D Medusa', 3, 'Colouring candidates across many digits at once.', 'new', 0],
  ['Exocet', 4, 'A rare base-and-target pattern in two boxes.', 'new', 0],
  ['Sue de Coq', 4, 'Two overlapping sets that split their digits.', 'new', 0],
  ["Bowman's Bingo", 4, 'Follow a guess until it contradicts itself.', 'new', 0],
];

const G = obj => { const v = Array(81).fill(0); Object.entries(obj).forEach(([i, d]) => (v[+i] = d)); return v; };
const BOX1 = [0, 1, 2, 9, 10, 11, 18, 19, 20];
const ROW = r => [...Array(9)].map((_, c) => r * 9 + c);
const COLC = c => [...Array(9)].map((_, r) => r * 9 + c);

const LESSONS = {
  'Hidden Single': {
    intro: 'The most useful move in Sudoku. Instead of asking “what goes in this cell?”, ask “where does this digit go?”',
    vals: G({ 0: 7, 9: 3, 20: 8, 13: 5, 25: 5, 37: 5, 6: 2, 50: 9, 60: 4, 75: 6, 31: 3, 66: 1 }),
    steps: [
      { t: 'Pick one box and one digit. Where can 5 go in box 1?', focus: BOX1 },
      { t: 'The 5 in row 2 covers all of row 2 — so not the middle row of this box.', focus: [...BOX1, 13], ev: [13], elim: [10, 11] },
      { t: 'The 5 in row 3 rules out the bottom row as well.', focus: [...BOX1, 13, 25], ev: [13, 25], elim: [10, 11, 18, 19] },
      { t: 'And the 5 in column 2 rules out the top-middle cell.', focus: [...BOX1, 13, 25, 37], ev: [13, 25, 37], elim: [10, 11, 18, 19, 1] },
      { t: 'One cell is left. 5 must go here — the digit was hidden among other possibilities, but it has only one home.', focus: [...BOX1, 13, 25, 37], ev: [13, 25, 37], target: 2, ghost: 5 },
    ],
    practice: 'easy',
  },
  'Pointing': {
    intro: 'Your first elimination. It doesn’t place a digit on its own — it removes candidates so a single appears.',
    vals: G({ 0: 5, 1: 8, 10: 4, 18: 6, 19: 2, 20: 9, 6: 3, 12: 7, 14: 1, 17: 6 }),
    steps: [
      { t: 'Look at 3 in box 1. It has two possible cells — and both sit in row 2.', focus: BOX1, cands: { 9: { 3: 'key' }, 11: { 3: 'key' } } },
      { t: 'Whichever cell it takes, box 1’s 3 lives in row 2. That claims row 2’s 3.', focus: [...BOX1, ...ROW(1)], pattern: [9, 11], cands: { 9: { 3: 'key' }, 11: { 3: 'key' }, 13: { 3: '' }, 16: { 3: '' } } },
      { t: 'So 3 can’t go anywhere else in row 2. Cross it off.', focus: [...BOX1, ...ROW(1)], pattern: [9, 11], cands: { 9: { 3: 'key' }, 11: { 3: 'key' }, 13: { 3: 'elim' }, 16: { 3: 'elim' } } },
      { t: 'The box points along a line. Its mirror image, Claiming, is when a line confines a digit to one box.', focus: [...BOX1, ...ROW(1)], pattern: [9, 11], cands: { 9: { 3: 'key' }, 11: { 3: 'key' } } },
    ],
    practice: 'medium',
  },
  'Naked Pair': {
    intro: 'When two cells in a unit can only be the same two digits, those digits are taken — even before you know which is which.',
    vals: G({ 36: 9, 39: 1, 42: 8 }),
    steps: [
      { t: 'Row 5, with its candidates pencilled in.', focus: ROW(4), cands: { 37: { 2: '', 7: '' }, 38: { 2: '', 4: '', 7: '' }, 40: { 2: '', 7: '' }, 41: { 3: '', 4: '', 5: '', 7: '' }, 43: { 3: '', 6: '' }, 44: { 2: '', 4: '', 5: '', 6: '' } } },
      { t: 'Two cells can only be 2 or 7. Between them, they’ll use both.', focus: ROW(4), pattern: [37, 40], cands: { 37: { 2: 'key', 7: 'key' }, 38: { 2: '', 4: '', 7: '' }, 40: { 2: 'key', 7: 'key' }, 41: { 3: '', 4: '', 5: '', 7: '' }, 43: { 3: '', 6: '' }, 44: { 2: '', 4: '', 5: '', 6: '' } } },
      { t: 'So no other cell in row 5 can be 2 or 7. Cross them out.', focus: ROW(4), pattern: [37, 40], cands: { 37: { 2: 'key', 7: 'key' }, 38: { 2: 'elim', 4: '', 7: 'elim' }, 40: { 2: 'key', 7: 'key' }, 41: { 3: '', 4: '', 5: '', 7: 'elim' }, 43: { 3: '', 6: '' }, 44: { 2: 'elim', 4: '', 5: '', 6: '' } } },
      { t: 'The third cell is left with only 4. A Naked Single drops out.', focus: ROW(4), pattern: [37, 40], target: 38, ghost: 4, cands: { 37: { 2: 'key', 7: 'key' }, 40: { 2: 'key', 7: 'key' }, 41: { 3: '', 4: '', 5: '' }, 43: { 3: '', 6: '' }, 44: { 4: '', 5: '', 6: '' } } },
    ],
    practice: 'hard',
  },
  'X-Wing': {
    intro: 'Your first “fish”. One digit, two lines, and a rectangle that locks it in place.',
    vals: G({ 9: 6, 10: 1, 12: 8, 14: 2, 15: 9, 17: 5, 54: 3, 55: 9, 57: 5, 59: 7, 60: 1, 62: 8 }),
    steps: [
      { t: 'Follow one digit: 4. In row 2 it has only two possible cells.', focus: ROW(1), cands: { 11: { 4: 'key' }, 16: { 4: 'key' } } },
      { t: 'Row 7 is the same — two cells, and in the same two columns.', focus: [...ROW(1), ...ROW(6)], cands: { 11: { 4: 'key' }, 16: { 4: 'key' }, 56: { 4: 'key' }, 61: { 4: 'key' } } },
      { t: 'Whichever way they fall, one 4 lands in each column at these corners. That’s the X.', focus: [...ROW(1), ...ROW(6)], pattern: [11, 16, 56, 61], cands: { 11: { 4: 'key' }, 16: { 4: 'key' }, 56: { 4: 'key' }, 61: { 4: 'key' } } },
      { t: 'So every other 4 in columns 3 and 8 can go.', focus: [...COLC(2), ...COLC(7)], pattern: [11, 16, 56, 61], cands: { 11: { 4: 'key' }, 16: { 4: 'key' }, 56: { 4: 'key' }, 61: { 4: 'key' }, 29: { 4: 'elim' }, 74: { 4: 'elim' }, 43: { 4: 'elim' }, 25: { 4: 'elim' }, 32: { 4: '' }, 48: { 4: '' } } },
    ],
    practice: 'expert',
  },
};
LESSONS['Full House'] = LESSONS['Naked Single'] = null;

function StatusDot({ s }) {
  if (s === 'mastered') return <span style={{ width: 12, height: 12, borderRadius: 6, background: 'var(--accent)' }}></span>;
  if (s === 'learning') return <span style={{ width: 12, height: 12, borderRadius: 6, boxShadow: 'inset 0 0 0 1.5px var(--accent)', background: 'linear-gradient(90deg, var(--accent) 50%, transparent 50%)' }}></span>;
  return <span style={{ width: 12, height: 12, borderRadius: 6, boxShadow: 'inset 0 0 0 1.5px var(--ink3)' }}></span>;
}

function LearnScreen({ openNight, openLesson }) {
  const used = TECHNIQUES.filter(t => t[3] !== 'new').length;
  return (
    <div className="ps-scroll" style={{ position: 'absolute', inset: 0, paddingTop: 54, paddingBottom: 100 }}>
      <ScreenHead title="Learn" openNight={openNight} />
      <div style={{ padding: '0 22px 18px', fontSize: 14, color: 'var(--ink3)' }}>{used} of {TECHNIQUES.length} techniques in your hands</div>
      <button onClick={() => openLesson('Pointing')} className="ps-card" style={{ margin: '0 16px 28px', width: 'calc(100% - 32px)', padding: '16px 16px 16px 18px', textAlign: 'left', display: 'flex', gap: 14, alignItems: 'center' }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)' }}>Up next · 3 min</div>
          <div className="ps-serif" style={{ fontSize: 24, color: 'var(--ink)', margin: '4px 0 4px' }}>Pointing</div>
          <div style={{ fontSize: 14, color: 'var(--ink2)', textWrap: 'pretty' }}>What unlocks Medium. You’ve met it in 4 hints so far.</div>
        </div>
        <span style={{ color: 'var(--accent)' }}><Ico n="chev" /></span>
      </button>
      {TIER_NAMES.map((tier, ti) => (
        <div key={tier} style={{ marginBottom: 22 }}>
          <SectionLabel>{tier}</SectionLabel>
          <div style={{ margin: '0 16px', borderTop: '1px solid var(--hair)' }}>
            {TECHNIQUES.filter(t => t[1] === ti).map(([name, , short, st, seen]) => {
              const has = !!LESSONS[name];
              return (
                <button key={name} onClick={() => openLesson(name)} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 14, padding: '12px 6px', borderBottom: '1px solid var(--hair)', textAlign: 'left' }}>
                  <StatusDot s={st} />
                  <span style={{ flex: 1 }}><span style={{ display: 'block', fontSize: 16, color: 'var(--ink)' }}>{name}</span><span style={{ display: 'block', fontSize: 13, color: 'var(--ink3)', marginTop: 2 }}>{short}</span></span>
                  <span style={{ fontSize: 12, color: 'var(--ink3)', whiteSpace: 'nowrap' }}>{seen ? `${seen}×` : has ? 'Lesson' : ''}</span>
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

function LessonScreen({ name, onBack, pal, onPractice, initialStep = 0 }) {
  const L = LESSONS[name], meta = TECHNIQUES.find(t => t[0] === name);
  const [k, setK] = useStL(initialStep);
  if (!L) {
    return (
      <div style={{ position: 'absolute', inset: 0, paddingTop: 54 }}>
        <div style={{ height: 48, padding: '0 10px', display: 'flex', alignItems: 'center' }}><button className="ps-icon" onClick={onBack}><Ico n="back" /></button></div>
        <div style={{ padding: '8px 24px' }}>
          <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)' }}>{TIER_NAMES[meta[1]]}</div>
          <div className="ps-serif" style={{ fontSize: 34, color: 'var(--ink)', margin: '6px 0 10px' }}>{name}</div>
          <div style={{ fontSize: 16, color: 'var(--ink2)', lineHeight: 1.45, textWrap: 'pretty' }}>{meta[2]}</div>
          <div className="ps-card" style={{ marginTop: 24, padding: 16, fontSize: 14, color: 'var(--ink3)', lineHeight: 1.45 }}>Step-by-step lesson in progress. Uses the same lesson template as Hidden Single, Pointing, Naked Pair and X-Wing.</div>
        </div>
      </div>
    );
  }
  const s = L.steps[k], last = k === L.steps.length - 1;
  const marks = { spotlight: true, focus: new Set(s.focus || []), evidence: new Set(s.ev || []), elim: new Set(s.elim || []), pattern: new Set(s.pattern || []), target: s.target ?? -1, ghost: s.ghost || 0 };
  return (
    <div style={{ position: 'absolute', inset: 0, paddingTop: 54, display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 48, padding: '0 10px', display: 'flex', alignItems: 'center' }}>
        <button className="ps-icon" onClick={onBack} aria-label="Back"><Ico n="back" /></button>
        <span style={{ flex: 1, textAlign: 'center', fontSize: 12, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink3)' }}>{TIER_NAMES[meta[1]]} · Lesson</span>
        <span style={{ width: 44 }}></span>
      </div>
      <div style={{ padding: '4px 24px 14px' }}>
        <div className="ps-serif" style={{ fontSize: 34, color: 'var(--ink)', lineHeight: 1.1 }}>{name}</div>
        <div style={{ fontSize: 15, color: 'var(--ink2)', lineHeight: 1.4, marginTop: 8, textWrap: 'pretty' }}>{L.intro}</div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <GridBoard vals={L.vals} givens={L.vals.map(Boolean)} width={342} type={pal.type} marks={marks} candMarks={s.cands} />
      </div>
      <div style={{ padding: '18px 24px 0', minHeight: 92, fontSize: 17, lineHeight: 1.4, color: 'var(--ink)', textWrap: 'pretty' }}>{s.t}</div>
      <div style={{ flex: 1 }}></div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '0 20px 44px' }}>
        <button className="ps-icon" disabled={!k} style={{ opacity: k ? 1 : 0.3, boxShadow: 'inset 0 0 0 1px var(--hair)' }} onClick={() => setK(k - 1)} aria-label="Previous step"><Ico n="back" /></button>
        <div style={{ flex: 1, display: 'flex', justifyContent: 'center', gap: 5 }}>{L.steps.map((_, i) => <span key={i} style={{ width: i === k ? 16 : 6, height: 6, borderRadius: 3, background: i <= k ? 'var(--accent)' : 'var(--hair)' }}></span>)}</div>
        {last ? <button className="ps-btn" onClick={() => onPractice(L.practice)}>Practise</button> : <button className="ps-btn" onClick={() => setK(k + 1)}>Next</button>}
      </div>
    </div>
  );
}

Object.assign(window, { LearnScreen, LessonScreen, TECHNIQUES });
