/**
 * Root layout — wraps the whole app.
 * Expo Router uses this file for every route.
 */
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { PostHogProvider } from 'posthog-react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import type { PropsWithChildren } from 'react';

import { AuthProvider } from '@/features/auth';
import { getPostHogClient } from '@/lib/analytics';
import { Sentry, initSentry } from '@/lib/sentry';

// Initialise Sentry as early as possible so even module-load errors are caught.
// When EXPO_PUBLIC_SENTRY_DSN is unset, this is a no-op.
initSentry();

function MaybePostHogProvider({ children }: PropsWithChildren) {
  const client = getPostHogClient();
  if (client === null) {
    return <>{children}</>;
  }
  return <PostHogProvider client={client}>{children}</PostHogProvider>;
}

function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <MaybePostHogProvider>
          <AuthProvider>
            <Stack screenOptions={{ headerShown: false }}>
              <Stack.Screen name="(tabs)" />
              <Stack.Screen name="auth/login" options={{ presentation: 'modal' }} />
              <Stack.Screen name="auth/signup" options={{ presentation: 'modal' }} />
            </Stack>
            <StatusBar style="auto" />
          </AuthProvider>
        </MaybePostHogProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

// Sentry.wrap adds an error boundary that captures render-time crashes.
// When Sentry is uninitialised it's still a passthrough, so this is safe to
// keep on regardless of whether SENTRY_DSN is configured.
export default Sentry.wrap(RootLayout);
