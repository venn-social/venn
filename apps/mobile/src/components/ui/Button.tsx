/**
 * Button — a primary action button.
 *
 * Design decision: a narrow API on purpose. Every button in the app is either
 * "primary" or "secondary" and every label is text. If you find yourself
 * wanting to render custom JSX inside, push back and keep the design system
 * small. Consistency > flexibility.
 */
import { ActivityIndicator, Pressable, StyleSheet } from 'react-native';

import { Text } from '@/components/ui/Text';
import { colors, radius, spacing } from '@/constants/theme';

type ButtonVariant = 'primary' | 'secondary';

interface ButtonProps {
  readonly label: string;
  readonly onPress: () => void;
  readonly variant?: ButtonVariant;
  readonly loading?: boolean;
  readonly disabled?: boolean;
  readonly testID?: string;
}

export function Button({
  label,
  onPress,
  variant = 'primary',
  loading = false,
  disabled = false,
  testID,
}: ButtonProps) {
  const isDisabled = disabled || loading;

  return (
    <Pressable
      testID={testID}
      onPress={onPress}
      disabled={isDisabled}
      style={({ pressed }) => [
        styles.base,
        variant === 'primary' ? styles.primary : styles.secondary,
        pressed && !isDisabled && styles.pressed,
        isDisabled && styles.disabled,
      ]}
      accessibilityRole="button"
      accessibilityState={{ disabled: isDisabled, busy: loading }}
    >
      {loading ? (
        <ActivityIndicator color={variant === 'primary' ? colors.textInverse : colors.text} />
      ) : (
        <Text
          variant="bodyBold"
          color={variant === 'primary' ? 'textInverse' : 'text'}
        >
          {label}
        </Text>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 48,
  },
  primary: {
    backgroundColor: colors.primary,
  },
  secondary: {
    backgroundColor: colors.backgroundMuted,
    borderWidth: 1,
    borderColor: colors.border,
  },
  pressed: {
    opacity: 0.85,
  },
  disabled: {
    opacity: 0.5,
  },
});
