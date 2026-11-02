export interface BoardMarks {
  /** Cells left at full strength; all others dim (hint spotlight). */
  focus?: number[];
  /** Cells that prove the step — solid accent ring. */
  evidence?: number[];
  /** Pattern cells (pair, X-Wing corners) — faint accent fill. */
  pattern?: number[];
  /** Hint target — dashed ring. */
  target?: number;
  /** Ghost digit shown in the target. */
  ghost?: number;
}
export interface BoardProps {
  /** 81 values, 0 = empty. */
  values: number[];
  /** 81 booleans — true for puzzle givens. */
  givens?: boolean[];
  /** 81 bitmasks of pencil marks (bit d set = candidate d). */
  notes?: number[];
  selected?: number;
  width?: number;
  /** 0 Standard, 1 Large, 2 Bold. */
  clarity?: 0 | 1 | 2;
  marks?: BoardMarks;
  /** Cell indexes shown as mistakes (underline bar). */
  errors?: number[];
  onSelect?: (index: number) => void;
}
export declare function Board(props: BoardProps): JSX.Element;
