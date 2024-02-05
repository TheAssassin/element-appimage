#! /bin/sh

set -eux
sed -i 's,import AutoLaunch from "auto-launch";,import AutoLaunch from "auto-launch";import * as appimage from "./appimage";,g' src/electron-main.ts
sed -i "s,global.launcher.enable();,appimage.enableAutoStart();,g" src/electron-main.ts
sed -i "s,global.launcher.disable(),appimage.disableAutoStart(),g" src/electron-main.ts
sed -i "s,await oldLauncher.isEnabled(),appimage.isAutoStartEnabled(),g" src/electron-main.ts

if [[ "$BUILD_TYPE" == "stable" ]] && grep -q 16.18.1 dockerbuild/Dockerfile; then
    sed -i 's|ENV NODE_VERSION 16.18.1|ENV NODE_VERSION 18.6.0|g' dockerbuild/Dockerfile
fi
