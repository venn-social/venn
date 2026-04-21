import { formatCompactCount, formatRelativeTime } from '@/utils/formatters';

describe('formatRelativeTime', () => {
  const now = new Date('2026-04-21T12:00:00Z');

  it('returns "just now" for timestamps less than a minute ago', () => {
    expect(formatRelativeTime('2026-04-21T11:59:30Z', now)).toBe('just now');
  });

  it('returns minutes for timestamps within the last hour', () => {
    expect(formatRelativeTime('2026-04-21T11:45:00Z', now)).toBe('15m ago');
  });

  it('returns hours for timestamps within the last day', () => {
    expect(formatRelativeTime('2026-04-21T09:00:00Z', now)).toBe('3h ago');
  });

  it('returns days for timestamps within the last week', () => {
    expect(formatRelativeTime('2026-04-18T12:00:00Z', now)).toBe('3d ago');
  });

  it('returns a short date for timestamps older than a week', () => {
    const result = formatRelativeTime('2026-01-10T12:00:00Z', now);
    expect(result).toMatch(/Jan\s*10/);
  });
});

describe('formatCompactCount', () => {
  it('returns raw numbers below 1000', () => {
    expect(formatCompactCount(0)).toBe('0');
    expect(formatCompactCount(42)).toBe('42');
    expect(formatCompactCount(999)).toBe('999');
  });

  it('abbreviates thousands', () => {
    expect(formatCompactCount(1_000)).toBe('1K');
    expect(formatCompactCount(1_234)).toBe('1.2K');
    expect(formatCompactCount(34_500)).toBe('34.5K');
  });

  it('abbreviates millions', () => {
    expect(formatCompactCount(1_000_000)).toBe('1M');
    expect(formatCompactCount(2_100_000)).toBe('2.1M');
  });
});
