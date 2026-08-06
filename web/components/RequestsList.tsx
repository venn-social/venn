"use client";

import { useState } from "react";
import { respondToRequest } from "@/lib/follow";
import type { UserProfile } from "@/lib/profile";
import { createClient } from "@/lib/supabase/client";
import { CheckIcon, CrossIcon } from "@/components/Icon";

interface RequestsListProps {
  initialRequests: UserProfile[];
}

export function RequestsList({ initialRequests }: RequestsListProps) {
  const [requests, setRequests] = useState(initialRequests);
  const [respondingTo, setRespondingTo] = useState<Set<string>>(new Set());

  async function handleRespond(requester: UserProfile, accept: boolean) {
    if (respondingTo.has(requester.id)) return;
    setRespondingTo((prev) => new Set(prev).add(requester.id));
    setRequests((prev) => prev.filter((r) => r.id !== requester.id));

    const supabase = createClient();
    try {
      await respondToRequest(supabase, requester.id, accept);
    } catch {
      setRequests((prev) => [...prev, requester]);
    } finally {
      setRespondingTo((prev) => {
        const next = new Set(prev);
        next.delete(requester.id);
        return next;
      });
    }
  }

  if (requests.length === 0) {
    return (
      <p className="text-(--color-text-secondary)">
        Requests to follow your private account will show up here.
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      {requests.map((requester) => {
        const isResponding = respondingTo.has(requester.id);
        const initial = (requester.displayName ?? requester.username).charAt(0).toUpperCase();
        return (
          <div
            key={requester.id}
            className="flex items-center gap-3 rounded-lg bg-(--color-surface) p-3"
          >
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-(--color-graphite) text-sm font-semibold text-(--color-on-accent)">
              {initial}
            </div>
            <div className="flex flex-1 flex-col">
              <span className="font-medium text-(--color-text-primary)">
                {requester.displayName ?? requester.username}
              </span>
              <span className="text-sm text-(--color-text-secondary)">@{requester.username}</span>
            </div>
            <button
              type="button"
              onClick={() => handleRespond(requester, false)}
              disabled={isResponding}
              aria-label="Decline"
              className="flex h-8 w-8 items-center justify-center rounded-full bg-(--color-surface-strong) text-(--color-text-secondary) disabled:opacity-40"
            >
              <CrossIcon size={16} />
            </button>
            <button
              type="button"
              onClick={() => handleRespond(requester, true)}
              disabled={isResponding}
              aria-label="Accept"
              className="flex h-8 w-8 items-center justify-center rounded-full bg-(--color-surface-strong) text-(--color-accent) disabled:opacity-40"
            >
              <CheckIcon size={16} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
