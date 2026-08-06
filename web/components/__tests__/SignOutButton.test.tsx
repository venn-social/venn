import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { SignOutButton } from "@/components/SignOutButton";

const replace = vi.fn();
const refresh = vi.fn();
const signOut = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, refresh })
}));

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({ auth: { signOut } })
}));

describe("SignOutButton", () => {
  beforeEach(() => {
    replace.mockClear();
    refresh.mockClear();
    signOut.mockReset();
  });

  it("ends the session and returns to sign-in", async () => {
    signOut.mockResolvedValue({ error: null });
    render(<SignOutButton />);

    fireEvent.click(screen.getByRole("button", { name: "Sign out" }));

    await waitFor(() => expect(signOut).toHaveBeenCalled());
    expect(replace).toHaveBeenCalledWith("/login");
  });

  it("refreshes so the cached signed-in shell is dropped", async () => {
    // Without this the nav would keep rendering as signed in, since it is
    // a server component holding the old session.
    signOut.mockResolvedValue({ error: null });
    render(<SignOutButton />);

    fireEvent.click(screen.getByRole("button", { name: "Sign out" }));

    await waitFor(() => expect(refresh).toHaveBeenCalled());
  });

  it("signs out this browser only, not every device", async () => {
    // The SDK defaults to scope "global", which would also end the session
    // on the user's phone. A plain "Sign out" means this device; ending
    // every session is a separate, explicitly labelled action.
    signOut.mockResolvedValue({ error: null });
    render(<SignOutButton />);

    fireEvent.click(screen.getByRole("button", { name: "Sign out" }));

    await waitFor(() => expect(signOut).toHaveBeenCalledWith({ scope: "local" }));
  });

  it("still signs you out locally when the server call fails", async () => {
    // Signing out is an intent. Stranding someone in a signed-in UI because
    // the network blinked is the wrong way to fail — especially on a
    // borrowed device, which is when people reach for this.
    signOut.mockRejectedValue(new Error("offline"));
    render(<SignOutButton />);

    fireEvent.click(screen.getByRole("button", { name: "Sign out" }));

    await waitFor(() => expect(replace).toHaveBeenCalledWith("/login"));
  });
});
