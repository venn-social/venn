import { router } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, TextInput, View } from 'react-native';

import { Button, Screen, Text } from '@/components/ui';
import { colors, radius, spacing } from '@/constants/theme';
import { signIn } from '@/services/auth.service';

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async () => {
    setErrorMessage(null);
    setIsSubmitting(true);
    try {
      await signIn({ email, password });
      router.back();
    } catch (err: unknown) {
      setErrorMessage(err instanceof Error ? err.message : 'Sign in failed.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Screen>
      <Text variant="h2">Sign in</Text>

      <View style={styles.form}>
        <TextInput
          style={styles.input}
          placeholder="Email"
          autoCapitalize="none"
          keyboardType="email-address"
          value={email}
          onChangeText={setEmail}
        />
        <TextInput
          style={styles.input}
          placeholder="Password"
          secureTextEntry
          value={password}
          onChangeText={setPassword}
        />
        {errorMessage !== null && (
          <Text variant="caption" color="danger">
            {errorMessage}
          </Text>
        )}
        <Button
          label="Sign in"
          onPress={() => void handleSubmit()}
          loading={isSubmitting}
          disabled={email === '' || password === ''}
        />
        <Button
          label="Create account"
          onPress={() => router.replace('/auth/signup')}
          variant="secondary"
        />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  form: {
    marginTop: spacing.lg,
    gap: spacing.md,
  },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    fontSize: 16,
    color: colors.text,
  },
});
