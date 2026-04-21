/**
 * Text — a typed wrapper around React Native's Text.
 * Forces callers to pick a typography variant instead of hand-setting fontSize.
 */
import { Text as RNText, StyleSheet } from 'react-native';

import type { TextProps as RNTextProps } from 'react-native';

import { colors, typography, type TypographyVariant } from '@/constants/theme';

interface TextProps extends RNTextProps {
  readonly variant?: TypographyVariant;
  readonly color?: keyof typeof colors;
}

export function Text({ variant = 'body', color = 'text', style, children, ...rest }: TextProps) {
  return (
    <RNText
      style={[typography[variant] as RNTextProps['style'], { color: colors[color] }, style]}
      {...rest}
    >
      {children}
    </RNText>
  );
}

// Silence the "no-unused-styles" lint warning by exporting a (currently empty)
// style sheet. Real projects will fill this in with layout-specific rules.
export const textStyles = StyleSheet.create({});
