import "ts-node/register";
import { ExpoConfig } from "expo/config";

const config: ExpoConfig = {
    name: "TemplateProject",
    slug: "TemplateProject",
    version: "1.0.0",
    orientation: "portrait",
    icon: "./assets/images/icon.png",
    scheme: "myapp",
    userInterfaceStyle: "automatic",
    newArchEnabled: true,
    platforms: ["ios"],
    ios: {
        bundleIdentifier: "com.example.TemplateProject",
    },
    plugins: ["expo-router", "expo-build-properties", "expo-font"],
    experiments: {
        typedRoutes: true,
    },
};

export default config;
