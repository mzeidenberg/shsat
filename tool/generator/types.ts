export type Subject = "math" | "ela";

export type QuestionType =
  | "arithmetic_word_problem"
  | "algebra_equation"
  | "grammar_edit"
  | "reading_comprehension";

export interface Choice {
  key: string;
  text: string;
}

export interface QuestionMetadata {
  content_hash: string;
  generator_model: string;
  generated_at: string;
  verifier_model: string | null;
  deterministic_check_passed: boolean | null;
  verifier_agreed: boolean | null;
  reviewed: boolean;
  reviewer: string | null;
}

export interface Question {
  id: string;
  subject: Subject;
  type: QuestionType;
  difficulty: "easy" | "medium" | "hard";
  passage_id: string | null;
  prompt: string;
  choices: Choice[];
  answer_key: string;
  explanation: string;
  /** JS-evaluable arithmetic expression whose numeric result should equal the
   * chosen answer's value. Only present for math types; used for the
   * deterministic check and stripped before shipping to the app. */
  check_expression?: string;
  metadata: QuestionMetadata;
}

export interface Passage {
  id: string;
  title: string;
  text: string;
  word_count: number;
}
