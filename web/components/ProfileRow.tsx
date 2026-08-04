import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import type { UserProfile } from "@/lib/profile";

interface ProfileRowProps {
  profile: UserProfile;
}

/**
 * One person in a list — avatar, name, handle. Ports ProfileRow.swift,
 * which iOS reuses across people search, follow lists, and requests.
 */
export function ProfileRow({ profile }: ProfileRowProps) {
  const name = profile.displayName ?? profile.username;

  return (
    <Link href={`/${profile.username}`} className="flex items-center gap-3 py-2">
      <Avatar name={name} avatarUrl={profile.avatarUrl} size={44} />
      <span className="flex flex-col">
        <span className="font-medium text-(--color-text-primary)">{name}</span>
        <span className="text-sm text-(--color-text-secondary)">@{profile.username}</span>
      </span>
    </Link>
  );
}
