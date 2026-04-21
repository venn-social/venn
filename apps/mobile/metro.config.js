// Metro (React Native's bundler) config.
// This teaches Metro how to resolve our monorepo workspace packages
// (like @venn/shared) from the packages/ folder.
const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const projectRoot = __dirname;
const monorepoRoot = path.resolve(projectRoot, '../..');

const config = getDefaultConfig(projectRoot);

// Watch all workspace files so Metro sees edits to packages/shared.
config.watchFolders = [monorepoRoot];

// Let Metro resolve node_modules from both the app and the monorepo root.
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(monorepoRoot, 'node_modules'),
];

config.resolver.disableHierarchicalLookup = true;

module.exports = config;
