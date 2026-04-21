/**
 * Screen — a wrapper for every screen in the app.
 * Handles safe areas, default padding, and background color so every screen
 * looks consistent without every screen re-solving the same problems.
 */
import type { PropsWithChildren } from 'react';
import { StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { colors, spacing } from '@/constants/theme';

interface ScreenProps {
  readonly padded?: boolean;
}

export function Screen({ children, padded = true }: PropsWithChildren<ScreenProps>) {
  return (
    <SafeAreaView style={styles.safe} edges={['top', 'left', 'right']}>
      <View style={[styles.content, padded && styles.contentPadded]}>{children}</View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: colors.background,
  },
  content: {
    flex: 1,
  },
  contentPadded: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.md,
  },
});
