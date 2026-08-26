import { Children } from "react";

/**
 * The feed as two staggered columns.
 *
 * A single column of full-width covers meant one post filled the screen and
 * browsing was a series of arrivals rather than a view of anything. Two
 * columns show four or five at once, and because the covers now keep their
 * own proportions the columns fall out of step by themselves — which is the
 * point, and why the right one also starts lower. An even grid of uneven
 * pictures reads as a mistake; an uneven one reads as a wall.
 *
 * Posts alternate left, right, left, so reading order down the page still
 * roughly follows time. It is not exact — a tall post pushes its column
 * down past its neighbour — but a feed of covers is browsed rather than
 * read line by line, and strict order is what a single column was for.
 *
 * Splits `children` rather than taking the posts and a render function,
 * which lets the server components that use it keep rendering their own
 * rows: a function prop cannot cross that boundary.
 */
export function FeedColumns({ children }: { children: React.ReactNode }) {
  const items = Children.toArray(children);
  if (items.length === 0) return null;

  const left = items.filter((_, index) => index % 2 === 0);
  const right = items.filter((_, index) => index % 2 === 1);

  return (
    <div className="flex items-start gap-3 sm:gap-4">
      <div className="flex w-1/2 flex-col gap-8">{left}</div>
      {/* Offset, so the two columns never line up into rows. */}
      <div className="mt-10 flex w-1/2 flex-col gap-8">{right}</div>
    </div>
  );
}
