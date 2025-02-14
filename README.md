# A template for a react-native macOS app

Use react-native-macos on version 0.76.0 (new arch) with expo-router and nativewind.

### Step 1

```bash
bunx @react-native-community/cli init MyMacosApp --version 0.76.0 --template https://github.com/liontariai/template-rn-macos-expo-router-nativewind
```

### Step 2

```bash
cd MyMacosApp
```

### Step 3

```bash
bun install
```

### Step 4

```bash
cd macos && pod install && cd ..
```

### Step 5

```bash
bun expo start
```

### Final step:

Open the macos/MyMacosApp.xcworkspace file with XCode and build + run the app.

![screenshot](https://github.com/user-attachments/assets/4f5025af-ebc4-448f-a026-d1115275d59b)
