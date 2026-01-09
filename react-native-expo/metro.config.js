const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const projectRoot = __dirname;

const config = getDefaultConfig(projectRoot);

// 🔒 Hard stop: only watch THIS app
config.watchFolders = [projectRoot];

// 🚫 Block anything outside /cursor explicitly
config.resolver.blockList = [
  new RegExp(`${path.resolve(projectRoot, "..").replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&")}.*`),
];

module.exports = config;