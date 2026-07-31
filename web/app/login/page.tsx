"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

/**
 * Magic-link sign-in — mirrors ios/Venn/Features/Auth/AuthView.swift's
 * copy and states (idle/sending/error/sent) per CLAUDE.md rule 17. Simpler
 * than iOS for Phase 1: no resend cooldown, no guest bypass yet.
 */
export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [errorMessage, setErrorMessage] = useState("");

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setStatus("sending");
    setErrorMessage("");

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    });

    if (error) {
      setStatus("error");
      setErrorMessage("Couldn't send the magic link. Please try again.");
      return;
    }
    setStatus("sent");
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 px-4">
      <div className="flex flex-col items-center gap-4 text-center">
        <h1 className="text-2xl font-semibold text-(--color-text-primary)">venn</h1>
        <p className="text-(--color-text-secondary)">Where your tastes meet your friends&apos;.</p>
      </div>

      {status === "sent" ? (
        <div className="flex w-full max-w-sm flex-col items-center gap-3 rounded-lg border border-(--color-separator) p-4 text-center">
          <h2 className="text-lg font-semibold text-(--color-text-primary)">Check your inbox</h2>
          <p className="text-(--color-text-secondary)">
            We emailed a sign-in link to <strong>{email}</strong>. Tapping it verifies your email
            and signs you in.
          </p>
          <button
            type="button"
            onClick={() => setStatus("idle")}
            className="text-sm font-semibold text-(--color-accent)"
          >
            Use a different email
          </button>
        </div>
      ) : (
        <form
          onSubmit={handleSubmit}
          className="flex w-full max-w-sm flex-col gap-3 rounded-lg border border-(--color-separator) p-4"
        >
          <input
            type="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder="Email"
            autoComplete="email"
            className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
          />
          {status === "error" && (
            <p className="text-sm text-red-500">{errorMessage}</p>
          )}
          <button
            type="submit"
            disabled={status === "sending" || email.length === 0}
            className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
          >
            {status === "sending" ? "Sending…" : "Continue"}
          </button>
        </form>
      )}
    </main>
  );
}
