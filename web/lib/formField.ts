/**
 * How a text field looks, everywhere.
 *
 * One rule under where you type, on the page's own ground. Fields used to
 * be filled grey rectangles with a border of their own, which on a screen
 * made of hairlines was the loudest thing on it — and on a form with
 * several, a stack of grey blocks with the actual content between them.
 *
 * The rule firms up on focus, so the field is still obviously findable
 * once you are typing in it rather than disappearing entirely.
 *
 * Exported as a string rather than a component: these are plain `input`,
 * `textarea` and `select` elements with their own props, types and
 * handlers, and wrapping three different elements to share four classes
 * would cost more than it saves.
 */
export const FIELD_CLASS =
  "w-full border-b border-(--color-separator) bg-transparent py-2 " +
  "text-(--color-text-primary) outline-none placeholder:text-(--color-text-secondary) " +
  "focus:border-(--color-text-secondary)";
