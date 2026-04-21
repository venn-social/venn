import { router } from 'expo-router';
import { StyleSheet, View } from 'react-native';

import { Button, Screen, Text } from '@/components/ui';
import { spacing } from '@/constants/theme';
import { useAuth } from '@/features/auth';
import { signOut } from '@/services/auth.service';

export default function ProfileScreen() {
  const { user, isLoading } = useAuth();

  const handleSignOut = () => {
    void signOut();
  };

  const handleSignIn = () => {
    router.push('/auth/login');
  };

  if (isLoading) {
    return (
      <Screen>
        <Text variant="body" color="textMuted">
          Loading…
        </Text>
      </Screen>
    );
  }

  return (
    <Screen>
      <Text variant="h1">Profile</Text>

      {user === null ? (
        <View style={styles.block}>
          <Text variant="body" color="textMuted">
            You're not signed in yet.
          </Text>
          <View style={styles.buttonRow}>
            <Button label="Sign in" onPress={handleSignIn} />
          </View>
        </View>
      ) : (
        <View style={styles.block}>
          <Text variant="bodyBold">{user.email ?? 'Signed in'}</Text>
          <View style={styles.buttonRow}>
            <Button label="Sign out" onPress={handleSignOut} variant="secondary" />
          </View>
        </View>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  block: {
    marginTop: spacing.lg,
    gap: spacing.md,
  },
  buttonRow: {
    marginTop: spacing.md,
  },
});
