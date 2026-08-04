import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { OnboardingUsernameStep } from "@/components/OnboardingUsernameStep";

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({})
}));

const { isUsernameAvailable, createProfile } = vi.hoisted(() => ({
  isUsernameAvailable: vi.fn(),
  createProfile: vi.fn()
}));

vi.mock("@/lib/onboarding", async () => {
  const actual = await vi.importActual<typeof import("@/lib/onboarding")>("@/lib/onboarding");
  return {
    ...actual,
    isUsernameAvailable,
    createProfile
  };
});

// Real timers throughout this file — OnboardingUsernameStep's live check
// debounces via a real setTimeout, and @testing-library's findByText/waitFor
// poll via their own real setTimeout internally. Faking timers breaks that
// polling (it never advances), so these tests just let the real 350ms
// debounce elapse and rely on findByText's own (generous) default timeout.

describe("OnboardingUsernameStep", () => {
  beforeEach(() => {
    isUsernameAvailable.mockReset();
    createProfile.mockReset();
  });

  it("shows an available hint after the debounce when the handle is free", async () => {
    isUsernameAvailable.mockResolvedValue(true);
    render(<OnboardingUsernameStep userId="user-1" onComplete={() => {}} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "ada" } });

    expect(await screen.findByText("@ada is available")).toBeDefined();
  });

  it("shows a taken hint after the debounce when the handle is in use", async () => {
    isUsernameAvailable.mockResolvedValue(false);
    render(<OnboardingUsernameStep userId="user-1" onComplete={() => {}} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "ada" } });

    expect(await screen.findByText("@ada is taken — try another")).toBeDefined();
  });

  it("shows an inline error for an invalid handle without a network call", () => {
    render(<OnboardingUsernameStep userId="user-1" onComplete={() => {}} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "a" } });

    expect(screen.getByText("Usernames need at least 3 characters.")).toBeDefined();
    expect(isUsernameAvailable).not.toHaveBeenCalled();
  });

  it("calls onComplete after a successful submit", async () => {
    createProfile.mockResolvedValue(undefined);
    const onComplete = vi.fn();
    render(<OnboardingUsernameStep userId="user-1" onComplete={onComplete} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "ada" } });
    fireEvent.click(screen.getByRole("button", { name: "Create profile" }));

    await vi.waitFor(() => expect(onComplete).toHaveBeenCalled());
    expect(createProfile).toHaveBeenCalledWith({}, "user-1", "ada", null);
  });

  it("shows an inline error and does not call onComplete when the username is taken at submit", async () => {
    const { UsernameTakenError } = await vi.importActual<typeof import("@/lib/onboarding")>(
      "@/lib/onboarding"
    );
    createProfile.mockRejectedValue(new UsernameTakenError("ada"));
    const onComplete = vi.fn();
    render(<OnboardingUsernameStep userId="user-1" onComplete={onComplete} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "ada" } });
    fireEvent.click(screen.getByRole("button", { name: "Create profile" }));

    expect(await screen.findByText("That username is taken — try another.")).toBeDefined();
    expect(onComplete).not.toHaveBeenCalled();
  });
});