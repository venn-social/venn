import { AppNav } from "@/components/AppNav";

/**
 * Shell for signed-in pages. Pages under (auth) — login, onboarding —
 * deliberately get no nav: there is nothing useful to navigate to before
 * you have a profile. Route groups don't affect URLs, so /profile is
 * still /profile.
 */
export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <AppNav />
      {children}
    </>
  );
}
