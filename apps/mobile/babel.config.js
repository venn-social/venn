// Babel config for Expo. The preset includes all the plugins needed to run
// React Native code (JSX, TypeScript, class properties, etc.).
module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [
      // React Native Reanimated's plugin must be last.
      'react-native-reanimated/plugin',
    ],
  };
};
