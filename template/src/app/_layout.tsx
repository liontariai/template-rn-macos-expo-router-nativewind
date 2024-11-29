import "react-native-reanimated";
import "../../global.css";

import { Stack } from "expo-router";

export default function RootLayout() {
    return (
        <Stack>
            <Stack.Screen name="(root)" options={{ headerShown: false }} />
        </Stack>
    );
}
