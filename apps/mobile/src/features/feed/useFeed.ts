/**
 * useFeed — example feature hook. Fetches the feed once on mount and exposes
 * a Loadable<Post[]> so screens don't have to juggle (loading, error, data)
 * as separate pieces of state.
 */
import { useEffect, useState } from 'react';

import { fetchFeed } from '@/services/posts.service';

import type { Loadable, Post } from '@/types';

export function useFeed(): Loadable<Post[]> {
  const [state, setState] = useState<Loadable<Post[]>>({ status: 'idle' });

  useEffect(() => {
    let cancelled = false;
    setState({ status: 'loading' });

    fetchFeed()
      .then((posts) => {
        if (!cancelled) {
          setState({ status: 'success', data: posts });
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          const message = err instanceof Error ? err.message : 'Failed to load feed.';
          setState({ status: 'error', error: message });
        }
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return state;
}
