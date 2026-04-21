/**
 * Root layout — wraps the whole app.
 * Expo Router uses this file for every route.
 */
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { AuthProvider } from '@/features/auth';

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <AuthProvider>
          <Stack screenOptions={{ headerShown: false }}>
            <Stack.Screen name="(tabs)" />
            <Stack.Screen name="auth/login" options={{ presentation: 'modal' }} />
            <Stack.Screen name="auth/signup" options={{ presentation: 'modal' }} />
          </Stack>
          <StatusBar style="auto" />
        </AuthProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
