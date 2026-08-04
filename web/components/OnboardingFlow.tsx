"use client";

import { useState } from "react";
import { OnboardingPhotoStep } from "@/components/OnboardingPhotoStep";
import { OnboardingUsernameStep } from "@/components/OnboardingUsernameStep";

interface OnboardingFlowProps {
  userId: string;
}

export function OnboardingFlow({ userId }: OnboardingFlowProps) {
  const [step, setStep] = useState<"username" | "photo">("username");

  if (step === "username") {
    return <OnboardingUsernameStep userId={userId} onComplete={() => setStep("photo")} />;
  }

  return (
    <OnboardingPhotoStep
      userId={userId}
      onComplete={() => {
        window.location.href = "/profile";
      }}
    />
  );
}