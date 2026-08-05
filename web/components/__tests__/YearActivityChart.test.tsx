import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { YearActivityChart } from "@/components/YearActivityChart";

const monthly = [
  { month: "2026-07-01", count: 2 },
  { month: "2026-08-01", count: 4 }
];

describe("YearActivityChart", () => {
  it("labels each month", () => {
    render(<YearActivityChart monthly={monthly} />);
    expect(screen.getByText("Jul")).toBeDefined();
    expect(screen.getByText("Aug")).toBeDefined();
  });

  it("summarises the whole chart for screen readers", () => {
    // Twelve individually-labelled bars are useless spoken aloud, so iOS
    // composes one summary and hides the bars. Web mirrors that.
    render(<YearActivityChart monthly={monthly} />);
    const chart = screen.getByLabelText(/Monthly activity, trailing twelve months/);
    expect(chart.getAttribute("aria-label")).toContain("Jul: 2");
    expect(chart.getAttribute("aria-label")).toContain("Aug: 4");
  });

  it("renders without dividing by zero when nothing was logged", () => {
    render(<YearActivityChart monthly={[{ month: "2026-08-01", count: 0 }]} />);
    expect(screen.getByText("Aug")).toBeDefined();
  });
});
