/**
 * Bottom tab navigator. Add new tabs by creating a file in this folder,
 * then registering a <Tabs.Screen> entry below.
 */
import { Tabs } from 'expo-router';

import { colors } from '@/constants/theme';

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
        headerShown: false,
      }}
    >
      <Tabs.Screen name="index" options={{ title: 'Home' }} />
      <Tabs.Screen name="explore" options={{ title: 'Explore' }} />
      <Tabs.Screen name="profile" options={{ title: 'Profile' }} />
    </Tabs>
  );
}
