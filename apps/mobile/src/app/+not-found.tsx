import { Link, Stack } from 'expo-router';
import { StyleSheet } from 'react-native';

import { Screen, Text } from '@/components/ui';
import { colors, spacing } from '@/constants/theme';

export default function NotFoundScreen() {
  return (
    <>
      <Stack.Screen options={{ title: 'Oops!' }} />
      <Screen>
        <Text variant="h2">Page not found.</Text>
        <Link href="/" style={styles.link}>
          <Text variant="body" color="primary">
            Go to home
          </Text>
        </Link>
      </Screen>
    </>
  );
}

const styles = StyleSheet.create({
  link: {
    marginTop: spacing.md,
    paddingVertical: spacing.sm,
    color: colors.primary,
  },
});
