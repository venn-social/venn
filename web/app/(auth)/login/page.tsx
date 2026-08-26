"use client";

import { useEffect, useState } from "react";
import { canResend, resendSecondsRemaining } from "@/lib/auth";
import { FIELD_CLASS } from "@/lib/formField";
import { createClient } from "@/lib/supabase/client";

/**
 * Magic-link sign-in — mirrors ios/Venn/Features/Auth/AuthView.swift's
 * copy and states (idle/sending/error/sent/verifying) per CLAUDE.md rule
 * 17. Both platforms now accept the numeric code the email carries
 * alongside the link, and both gate resend behind the same cooldown.
 */
/**
 * Supabase's built-in email sender throttles at roughly 3-4 sends/hour and
 * returns `over_email_send_rate_limit`. Reporting that as "try again" is
 * actively misleading — trying again is exactly what doesn't work, and it
 * makes a throttle indistinguishable from a bug. Say "wait" when the
 * answer is "wait".
 *
 * This distinction stops mattering once custom SMTP is configured, which
 * removes the limit (docs/TECH_DEBT.md row 20).
 */
function signInErrorMessage(error: { code?: string; status?: number }): string {
  if (error.code === "over_email_send_rate_limit" || error.status === 429) {
    return "Too many sign-in emails just now. Wait a minute and try again.";
  }
  return "Couldn't send the magic link. Please try again.";
}

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "verifying" | "error">("idle");
  const [errorMessage, setErrorMessage] = useState("");
  const [lastSentAt, setLastSentAt] = useState<number | null>(null);
  /** Ticks once a second so the countdown re-renders. */
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (status !== "sent") return;
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [status]);

  const secondsUntilResend = resendSecondsRemaining(lastSentAt, now);
  const resendUnlocked = status === "sent" && canResend(lastSentAt, now);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setStatus("sending");
    setErrorMessage("");

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`
      }
    });

    if (error) {
      setStatus("error");
      setErrorMessage(signInErrorMessage(error));
      return;
    }
    setLastSentAt(Date.now());
    setNow(Date.now());
    setStatus("sent");
  }

  async function handleResend() {
    setStatus("sending");
    setErrorMessage("");

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`
      }
    });

    if (error) {
      // Back to "sent", not "error": the inbox panel has to stay up so the
      // code field survives a failed resend.
      setStatus("sent");
      setErrorMessage(signInErrorMessage(error));
      return;
    }
    setLastSentAt(Date.now());
    setNow(Date.now());
    setStatus("sent");
  }

  async function handleVerifyCode(event: React.FormEvent) {
    event.preventDefault();
    setStatus("verifying");
    setErrorMessage("");

    const supabase = createClient();
    const { error } = await supabase.auth.verifyOtp({
      email,
      token: code,
      type: "email"
    });

    if (error) {
      setStatus("sent");
      setErrorMessage("That code didn't work — check it and try again.");
      return;
    }
    window.location.href = "/profile";
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 px-4">
      <div className="flex flex-col items-center gap-4 text-center">
        <h1 className="text-2xl font-semibold text-(--color-text-primary)">venn</h1>
        <p className="text-(--color-text-secondary)">you have good taste. explore it.</p>
      </div>

      {status === "sent" || status === "verifying" ? (
        <div className="flex w-full max-w-sm flex-col items-center gap-4 text-center">
          <h2 className="text-lg font-semibold text-(--color-text-primary)">Check your inbox</h2>
          <p className="text-(--color-text-secondary)">
            We emailed a sign-in link to <strong>{email}</strong>. Tapping it verifies your email
            and signs you in — or enter the code from that same email below.
          </p>
          <form onSubmit={handleVerifyCode} className="flex w-full flex-col gap-3">
            <input
              type="text"
              inputMode="numeric"
              required
              value={code}
              onChange={(event) => setCode(event.target.value)}
              placeholder="Code from email"
              autoComplete="one-time-code"
              className={`${FIELD_CLASS} text-center`}
            />
            {errorMessage && status === "sent" && (
              <p className="text-sm text-red-500">{errorMessage}</p>
            )}
            <button
              type="submit"
              disabled={status === "verifying" || code.length === 0}
              className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
            >
              {status === "verifying" ? "Verifying…" : "Verify code"}
            </button>
          </form>
          <button
            type="button"
            onClick={() => void handleResend()}
            disabled={!resendUnlocked}
            className="text-sm font-semibold text-(--color-accent) disabled:opacity-50"
          >
            {secondsUntilResend > 0 ? `Resend in ${secondsUntilResend}s` : "Resend link"}
          </button>
          <button
            type="button"
            onClick={() => {
              setStatus("idle");
              setCode("");
              setErrorMessage("");
              setLastSentAt(null);
            }}
            className="text-sm font-semibold text-(--color-accent)"
          >
            Use a different email
          </button>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="flex w-full max-w-sm flex-col gap-4">
          <input
            type="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder="Email"
            autoComplete="email"
            className={FIELD_CLASS}
          />
          {status === "error" && <p className="text-sm text-red-500">{errorMessage}</p>}
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
