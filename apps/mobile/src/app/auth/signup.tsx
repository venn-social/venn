import { router } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, TextInput, View } from 'react-native';

import { Button, Screen, Text } from '@/components/ui';
import { colors, radius, spacing } from '@/constants/theme';
import { signUp } from '@/services/auth.service';

export default function SignupScreen() {
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async () => {
    setErrorMessage(null);
    setIsSubmitting(true);
    try {
      await signUp({ email, password, username });
      router.back();
    } catch (err: unknown) {
      setErrorMessage(err instanceof Error ? err.message : 'Sign up failed.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const canSubmit = email !== '' && password !== '' && username !== '';

  return (
    <Screen>
      <Text variant="h2">Create your account</Text>

      <View style={styles.form}>
        <TextInput
          style={styles.input}
          placeholder="Username"
          autoCapitalize="none"
          value={username}
          onChangeText={setUsername}
        />
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
          label="Create account"
          onPress={() => void handleSubmit()}
          loading={isSubmitting}
          disabled={!canSubmit}
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
