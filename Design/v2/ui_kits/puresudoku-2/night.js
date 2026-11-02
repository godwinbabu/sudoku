// Night palette model. Two continuous axes instead of theme toggles:
//   glow   0–100  how much light the screen emits (maps to ink luminance; app also lowers UIScreen.brightness)
//   warmth 0–100  colour temperature of every lit pixel, 6500 K → 1200 K, interpolated in mireds (perceptually even)
// plus clarity 0–2 (size, weight, line strength) for tired or older eyes.
// The canvas is always true black at night: on OLED those pixels are off.
(function () {
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  function kelvinRGB(k) {
    const t = k / 100; let r, g, b;
    if (t <= 66) { r = 255; g = 99.4708025861 * Math.log(t) - 161.1195681661; }
    else { r = 329.698727446 * Math.pow(t - 60, -0.1332047592); g = 288.1221695283 * Math.pow(t - 60, -0.0755148492); }
    if (t >= 66) b = 255; else if (t <= 19) b = 0; else b = 138.5177312231 * Math.log(t - 10) - 305.0447927307;
    return [clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255)];
  }
  const M0 = 1e6 / 6500, M1 = 1e6 / 1200;
  const warmthToK = w => Math.round(1e6 / (M0 + (M1 - M0) * clamp(w, 0, 100) / 100) / 50) * 50;
  const rgb = (c, s) => `rgb(${c.map(x => Math.round(clamp(x * s, 0, 255))).join(',')})`;

  function typeScale(cl) {
    return { digit: [1, 1.1, 1.2][cl], given: [600, 700, 760][cl], user: [400, 500, 600][cl], cand: [1, 1.12, 1.25][cl], line: [1, 1.5, 2][cl], ui: [1, 1.06, 1.12][cl] };
  }

  function palette(st) {
    const cl = st.clarity || 0, type = typeScale(cl);
    if (st.appearance === 'day') {
      return { mode: 'day', type, kelvin: null, blueCut: 0, light: 100, vars: {
        '--bg': '#F4F1E9', '--surface': '#EBE6DA', '--surface2': '#E2DCCD', '--ink': '#1B1A17', '--ink2': '#57534B', '--ink3': '#8A857A',
        '--accent': '#9A5712', '--accentDim': '#C9A27A', '--line': cl ? '#B9B1A0' : '#CFC8B8', '--lineMajor': '#2E2B25', '--hair': '#D8D1C1',
        '--sel': '#EFD9B0', '--peer': '#ECE6D9', '--same': '#F1E2C6', '--err': '#B3261E', '--focusDim': '0.28', '--status': '#1B1A17' } };
    }
    const K = warmthToK(st.warmth), base = kelvinRGB(K);
    const acc = kelvinRGB(warmthToK(Math.min(100, st.warmth * 0.55 + 52)));
    const floor = [0.2, 0.3, 0.38][cl];
    const s = floor + (1 - floor) * Math.pow(clamp(st.glow, 0, 100) / 100, 1.15);
    const lift = [1, 1.25, 1.5][cl];
    const errc = [255, 70, 64];
    return { mode: 'night', type, kelvin: K, s,
      blueCut: Math.round((1 - (base[2] / 255) * s) * 100),
      light: Math.round(s * 100),
      vars: {
        '--bg': '#000', '--surface': rgb(base, s * 0.07), '--surface2': rgb(base, s * 0.11), '--ink': rgb(base, s), '--ink2': rgb(base, s * 0.7), '--ink3': rgb(base, s * 0.5),
        '--accent': rgb(acc, s * 0.96), '--accentDim': rgb(acc, s * 0.5), '--line': rgb(base, s * 0.17 * lift), '--lineMajor': rgb(base, s * 0.42 * lift), '--hair': rgb(base, s * 0.15),
        '--sel': rgb(acc, s * 0.2), '--peer': rgb(base, s * 0.055), '--same': rgb(acc, s * 0.12), '--err': rgb(errc, s * 0.95), '--focusDim': '0.22', '--status': rgb(base, s * 0.44) } };
  }

  window.PSNight = { palette, kelvinRGB, warmthToK };
})();
