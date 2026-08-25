/**
 * Browser APIs jsdom does not implement, stubbed once for every suite.
 *
 * jsdom does no layout, so the observers that watch for it are simply
 * absent. Components are entitled to use them; without these, any test that
 * renders such a component dies on `ReferenceError` in a place that has
 * nothing to do with what it was testing.
 *
 * These are inert on purpose. A stub that fired callbacks would invent
 * layout events that jsdom cannot actually produce, which is worse than a
 * component that simply never learns its size — the state it already
 * handles, because it is the state before the first measurement.
 */

class InertObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
  takeRecords() {
    return [];
  }
}

if (!("ResizeObserver" in globalThis)) {
  globalThis.ResizeObserver = InertObserver as unknown as typeof ResizeObserver;
}
