export interface KeypadProps {
  /** Digits still to place, keyed 1–9. A digit at 0 fades and disables. */
  remaining?: Record<number, number>;
  /** Notes mode: each key shows its digit in its pencil-mark position. */
  notesMode?: boolean;
  clarity?: 0 | 1 | 2;
  onDigit?: (digit: number) => void;
}
export declare function Keypad(props: KeypadProps): JSX.Element;
