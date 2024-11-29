// @ts-check
import { getMacOsModFileProviders } from "./plugins/withMacOsBaseMods.mjs";

export { applyConfigPlugins } from "./apply.mjs";
export {
    compileModsAsync,
    withDefaultBaseMods,
} from "./plugins/mod-compiler.mjs";
export { withInternal } from "./plugins/withInternal.mjs";

export const BaseMods = {
    getMacOsModFileProviders,
};
