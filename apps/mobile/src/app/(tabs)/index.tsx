/**
 * Home feed screen. Shows the current state of useFeed().
 * This is a placeholder — real rendering (FlatList of posts) goes here later.
 */
import { ActivityIndicator, StyleSheet, View } from 'react-native';

import { Screen, Text } from '@/components/ui';
import { useFeed } from '@/features/feed/useFeed';

export default function HomeScreen() {
  const feed = useFeed();

  return (
    <Screen>
      <Text variant="h1">Venn</Text>
      <Text variant="caption" color="textMuted">
        Your feed will live here.
      </Text>

      <View style={styles.content}>
        {feed.status === 'loading' && <ActivityIndicator />}
        {feed.status === 'error' && (
          <Text variant="body" color="danger">
            {feed.error}
          </Text>
        )}
        {feed.status === 'success' && feed.data.length === 0 && (
          <Text variant="body" color="textMuted">
            No posts yet. Be the first!
          </Text>
        )}
        {feed.status === 'success' && feed.data.length > 0 && (
          <Text variant="body">{`${feed.data.length} post(s) loaded.`}</Text>
        )}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: {
    marginTop: 24,
  },
});
