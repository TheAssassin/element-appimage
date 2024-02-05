#! /bin/bash

set -euo pipefail

status () {
    echo "========================="
    echo -e "\033[31;1;4m$1\033[0m"
    echo "========================="
}

if [[ "$BUILD_TYPE" == "" ]] || [[ "$NODE_VERSION" == "" ]]; then
    status "Usage: env BUILD_TYPE=... NODE_VERSION=... $0"
    exit 2
fi

set -x

export APPIMAGE_EXTRACT_AND_RUN=1

ls -al

mkdir -p _deps
mkdir -p _build
mkdir -p _release

repo_root="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")"
old_cwd="$(readlink -f "$PWD")"
workdir="$(mktemp -d --tmpdir element-appimage-build-XXXXX)"

_cleanup() {
    # sudo is required as the Docker stuff runs as root
    [[ -d "$workdir" ]] && sudo rm -rf "$workdir"
}
trap _cleanup EXIT

pushd "$workdir"

status "Cloning Element Desktop"

git clone https://github.com/element-hq/element-desktop .
if [[ "$BUILD_TYPE" == "stable" ]]; then
    git checkout `curl -L --silent -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/element-hq/element-desktop/releases/latest | jq  -r '.tag_name'`
fi
git describe --tags --always --match "v*.*"
export ELEMENT_BUILD_VERSION="$(git describe --tags --always --match 'v*.*')"

"$repo_root"/patch.sh

yarn install

sed -i 's,docker run --rm -ti,docker run --rm,g' scripts/in-docker.sh
mkdir -p appimage_config
pushd appimage_config
if [[ "$BUILD_TYPE" == "stable" ]]; then
  wget https://app.element.io/config.json
else
  wget https://develop.element.io/config.json
fi
popd

yarn run fetch --noverify --cfgdir 'appimage_config'
yarn run docker:setup

cp "$repo_root"/*.ts src

pwd
ls

yarn run docker:install
yarn run docker:build:native
yarn run docker:build

ls -al

./scripts/in-docker.sh yarn run electron-builder -l appimage --publish never

sudo chown -R "$(id -u):$(id -g)" .

pushd dist

./*.AppImage --appimage-extract
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x ./appimagetool-x86_64.AppImage
sudo rm -rf Element*.AppImage

#cp -L /usr/lib/libsqlcipher.so.0 squashfs-root/usr/lib/.
#cp -L /lib64/libcrypto.so.10 squashfs-root/usr/lib/.
#cp -L /lib64/libssl3.so squashfs-root/usr/lib/.
#cp -L /lib64/libssl.so.10 squashfs-root/usr/lib/.
export VERSION="$ELEMENT_BUILD_VERSION"
./appimagetool-x86_64.AppImage squashfs-root -n -u 'gh-releases-zsync|TheAssassin|element-appimage|continuous|Element*.AppImage.zsync'

chmod +x Element*.AppImage*
mv Element*.AppImage* "$old_cwd"


