import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import { PencilIcon } from "@/components/Icon";

interface EditableAvatarProps {
  name: string;
  avatarUrl: string | null;
}

/**
 * Your own avatar, which is also the way to edit your profile.
 *
 * The page used to carry an "Edit profile" button under the bio — a
 * permanent control for something you do rarely, sitting directly beneath
 * the thing it edits. The picture is the obvious place to put it, and the
 * pen only appears when you are pointing at it.
 *
 * The whole avatar is the link, not the pen. Hover does not exist on a
 * touchscreen, so a control that only appears on hover would be a control
 * a phone could never reach — tapping the picture gets there instead, and
 * the pen is a hint rather than the target. Keyboard users get the same
 * hint on focus.
 */
export function EditableAvatar({ name, avatarUrl }: EditableAvatarProps) {
  return (
    <Link
      href="/profile/edit"
      aria-label="Edit profile"
      className="group relative shrink-0 rounded-full outline-offset-2"
    >
      <Avatar name={name} avatarUrl={avatarUrl} />
      {/* A badge on the corner rather than a scrim over the whole picture.
          A scrim has to hide what is underneath to read as a state, and it
          cannot: the placeholder's initial is near-white, so darkening the
          circle left the letter and the pen overlapping each other. This
          covers nothing and says the same thing. */}
      <span
        aria-hidden="true"
        className="absolute -right-0.5 -bottom-0.5 flex h-6 w-6 items-center justify-center rounded-full border border-(--color-separator) bg-(--color-background) text-(--color-text-primary) opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100"
      >
        <PencilIcon size={13} />
      </span>
    </Link>
  );
}
