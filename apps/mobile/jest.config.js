module.exports = {
  preset: 'jest-expo',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@unimodules/.*|unimodules|sentry-expo|native-base|react-native-svg|@supabase/.*))',
  ],
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/index.ts',
    '!src/app/**', // Route files are hard to unit-test; test components instead.
  ],
  // Threshold only checked when --coverage is passed (it's on by default in
  // the `test` script). Tighten the bar / add new paths as we add tests.
  coverageThreshold: {
    './src/utils/': {
      statements: 80,
      branches: 70,
      functions: 80,
      lines: 80,
    },
  },
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^@venn/shared$': '<rootDir>/../../packages/shared/src',
    '^@venn/shared/(.*)$': '<rootDir>/../../packages/shared/src/$1',
  },
};
