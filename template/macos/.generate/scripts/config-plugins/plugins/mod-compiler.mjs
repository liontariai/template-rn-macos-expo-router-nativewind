// @ts-check
import { BaseMods, evalModsAsync } from "../ExpoConfigPlugins.mjs";
import { getMacOsModFileProviders } from "./withMacOsBaseMods.mjs";

/** @type {import("@expo/config-plugins").withDefaultBaseMods} */
export const withDefaultBaseMods = (config, props) => {
    config = BaseMods.withGeneratedBaseMods(config, {
        ...props,
        // @ts-expect-error `macos` is not assignable to type `android | ios`
        platform: "macos",
        providers: getMacOsModFileProviders(),
    });
    return config;
};

/** @type {import("@expo/config-plugins").compileModsAsync} */
export const compileModsAsync = (config, props) => {
    if (props.introspect === true) {
        console.warn("`introspect` is not supported by react-native-test-app");
    }

    config = withDefaultBaseMods(config);
    return evalModsAsync(config, props);
};
