const { getDefaultConfig } = require("expo/metro-config");
const { makeMetroConfig } = require("@rnx-kit/metro-config");
const { withNativeWind } = require("nativewind/metro");

/** @type {import('expo/metro-config').MetroConfig} */
let config = getDefaultConfig(__dirname);

config = makeMetroConfig({
    ...config,
    transformer: {
        ...config.transformer,
        getTransformOptions: async () => ({
            transform: {
                experimentalImportSupport: false,
                inlineRequires: false,
            },
        }),
    },
    resolver: {
        ...config.resolver,
    },
});

config = withNativeWind(config, { input: "./global.css" });

module.exports = config;
