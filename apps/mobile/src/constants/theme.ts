/**
 * theme.ts — single source of truth for colors, spacing, and typography.
 *
 * Rules:
 *   - Never hardcode a color, font size, or spacing value in a component.
 *     Always pull from `theme`. This makes dark mode, rebrands, and
 *     accessibility changes a one-file edit.
 *   - Add new tokens here; don't invent them per-component.
 */

export const colors = {
  background: '#FFFFFF',
  backgroundMuted: '#F5F5F7',
  text: '#111111',
  textMuted: '#6B6B70',
  textInverse: '#FFFFFF',
  primary: '#5B6CFF',
  primaryPressed: '#4855E8',
  border: '#E4E4E8',
  danger: '#E5484D',
  success: '#30A46C',
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
} as const;

export const radius = {
  sm: 6,
  md: 12,
  lg: 20,
  pill: 999,
} as const;

export const typography = {
  h1: { fontSize: 32, fontWeight: '700', lineHeight: 40 },
  h2: { fontSize: 24, fontWeight: '700', lineHeight: 32 },
  h3: { fontSize: 18, fontWeight: '600', lineHeight: 24 },
  body: { fontSize: 16, fontWeight: '400', lineHeight: 24 },
  bodyBold: { fontSize: 16, fontWeight: '600', lineHeight: 24 },
  caption: { fontSize: 13, fontWeight: '400', lineHeight: 18 },
} as const;

export type ThemeColor = keyof typeof colors;
export type ThemeSpacing = keyof typeof spacing;
export type TypographyVariant = keyof typeof typography;
