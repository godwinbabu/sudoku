export interface HintCardProps {
  /** 1 Where to look · 2 Technique · 3 Why. */
  level?: 1 | 2 | 3;
  technique?: string;
  /** Beginner, Intermediate, Advanced, Expert, Esoteric. */
  tier?: string;
  text: string;
  /** Button label, e.g. "Which technique?", "Show me why", "Place 5". */
  cta: string;
  /** Night: the button becomes an outline (no lit fills). */
  night?: boolean;
  onNext?: () => void;
  onClose?: () => void;
  onLesson?: () => void;
}
export declare function HintCard(props: HintCardProps): JSX.Element;
