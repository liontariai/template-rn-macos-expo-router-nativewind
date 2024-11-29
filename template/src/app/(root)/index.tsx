import { View } from "react-native";

export default function StartScreen() {
    return (
        <View className="flex-1 flex-col bg-black items-center gap-4">
            <View className="w-full bg-red-500 rounded-md min-h-[200px]" />
            <View className="w-full bg-red-500 rounded-md min-h-[200px]" />
            <View className="w-full bg-red-500 rounded-md min-h-[200px]" />
        </View>
    );
}
