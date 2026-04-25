import { RateLimitError, createRateLimiter } from './rateLimit';

describe('createRateLimiter', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-04-25T12:00:00Z'));
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('allows up to maxCalls within the window', () => {
    const limiter = createRateLimiter({ maxCalls: 3, windowMs: 1000 });
    expect(() => limiter.check()).not.toThrow();
    expect(() => limiter.check()).not.toThrow();
    expect(() => limiter.check()).not.toThrow();
  });

  it('throws RateLimitError on the (maxCalls + 1)-th call', () => {
    const limiter = createRateLimiter({ maxCalls: 2, windowMs: 1000 });
    limiter.check();
    limiter.check();
    expect(() => limiter.check()).toThrow(RateLimitError);
  });

  it('reports retryAfterMs based on the oldest call', () => {
    const limiter = createRateLimiter({ maxCalls: 1, windowMs: 5000 });
    limiter.check();
    jest.advanceTimersByTime(2000);
    try {
      limiter.check();
      throw new Error('should have thrown');
    } catch (e) {
      expect(e).toBeInstanceOf(RateLimitError);
      expect((e as RateLimitError).retryAfterMs).toBe(3000);
    }
  });

  it('expires old calls outside the window', () => {
    const limiter = createRateLimiter({ maxCalls: 2, windowMs: 1000 });
    limiter.check();
    limiter.check();
    jest.advanceTimersByTime(1001);
    expect(() => limiter.check()).not.toThrow();
  });

  it('isAllowed reports correctly without consuming budget', () => {
    const limiter = createRateLimiter({ maxCalls: 2, windowMs: 1000 });
    expect(limiter.isAllowed()).toBe(true);
    limiter.check();
    expect(limiter.isAllowed()).toBe(true);
    limiter.check();
    expect(limiter.isAllowed()).toBe(false);
  });

  it('reset clears the window', () => {
    const limiter = createRateLimiter({ maxCalls: 1, windowMs: 1000 });
    limiter.check();
    expect(limiter.isAllowed()).toBe(false);
    limiter.reset();
    expect(limiter.isAllowed()).toBe(true);
  });

  it('rejects invalid options', () => {
    expect(() => createRateLimiter({ maxCalls: 0, windowMs: 1000 })).toThrow();
    expect(() => createRateLimiter({ maxCalls: 1, windowMs: 0 })).toThrow();
  });
});
