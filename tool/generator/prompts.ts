import type { QuestionType } from "./types.js";

export const SYSTEM_PROMPT = `You write original practice questions for a middle-school SHSAT
(NYC Specialized High Schools Admissions Test) tutoring app. Every question must be entirely
original content that you author yourself, written in the style and difficulty range of the
officially released NYC DOE SHSAT specimen tests. Do not copy or closely paraphrase any specific
question you may recall from a copyrighted test-prep book or course. Each question must have
exactly 4 multiple-choice options with exactly one unambiguously correct answer.`;

const TYPE_INSTRUCTIONS: Record<QuestionType, string> = {
  arithmetic_word_problem: `Write ${"{count}"} arithmetic word problems (percents, ratios, rates,
proportions, or basic arithmetic) at 8th-grade difficulty. For each, also provide
"check_expression": a plain JavaScript arithmetic expression (numbers and + - * / ( ) only, no
variables) that evaluates to the correct numeric answer, so it can be checked by machine.`,
  algebra_equation: `Write ${"{count}"} "solve for x" basic algebra questions (linear equations,
one or two steps) at 8th-grade difficulty. For each, also provide "check_expression": a plain
JavaScript arithmetic expression (numbers and + - * / ( ) only, no variables) that evaluates to
the correct numeric value of x, so it can be checked by machine.`,
  grammar_edit: `Write ${"{count}"} "revising and editing" style questions: present a sentence or
short set of sentences with a grammar, punctuation, or usage issue and ask which choice best
corrects/improves it (or that no change is needed, as one option) at 8th-grade difficulty.`,
  reading_comprehension: `Write one original short passage (150-300 words, fiction or
nonfiction, appropriate for a middle-school reader) and ${"{count}"} multiple-choice
comprehension questions about it (main idea, inference, vocabulary-in-context, or detail
questions) at 8th-grade difficulty.`,
};

export function buildInstruction(type: QuestionType, count: number): string {
  return TYPE_INSTRUCTIONS[type].replaceAll("{count}", String(count));
}
