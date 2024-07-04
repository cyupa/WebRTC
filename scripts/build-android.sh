#!/bin/sh

## WebRTC library build script
## Created by Stasel
## BSD-3 License
## 
## Example usage: MACOS=true IOS=true BUILD_VP9=true sh build.sh

# Configs
DEBUG="${DEBUG:-false}"
BUILD_VP9="${BUILD_VP9:-false}"
BRANCH="${BRANCH:-master}"

OUTPUT_DIR="./out"
COMMON_GN_ARGS="is_debug=${DEBUG} rtc_libvpx_build_vp9=${BUILD_VP9} is_component_build=false rtc_include_tests=false enable_stripping=true use_lld=true"

build_android() {
    local arch=$1
    local gen_dir="${OUTPUT_DIR}/android-${arch}"
    local gen_args="${COMMON_GN_ARGS} target_os=\"android\" target_cpu=\"${arch}\""
    gn gen "${gen_dir}" --args="${gen_args}"
    gn args --list ${gen_dir} > ${gen_dir}/gn-args.txt
    ninja -C "${gen_dir}" || exit 1
}

# Step 1: Download and install depot tools
if [ ! -d depot_tools ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
else
    cd depot_tools
    git pull origin main
    cd ..
fi
export PATH=$(pwd)/depot_tools:$PATH

# Step 2 - Download and build WebRTC
if [ ! -d src ]; then
    fetch --nohooks webrtc_android
fi
cd src
git fetch --all
git checkout $BRANCH
cd ..
gclient sync --with_branch_heads --with_tags
cd src

# Step 3 - Compile and build all frameworks
rm -rf $OUTPUT_DIR

build_android "x64"
build_android "x86"
build_android "arm"
build_android "arm64"

cd out
NOW=$(date -u +"%Y-%m-%dT%H-%M-%S")
OUTPUT_NAME=WebRTC-Android.zip
zip --symlinks -r $OUTPUT_NAME /.

# Step 8 calculate SHA256 checksum
CHECKSUM=$(shasum -a 256 $OUTPUT_NAME | awk '{ print $1 }')
COMMIT_HASH=$(git rev-parse HEAD)

echo "{ \"file\": \"${OUTPUT_NAME}\", \"checksum\": \"${CHECKSUM}\", \"commit\": \"${COMMIT_HASH}\", \"branch\": \"${BRANCH}\" }" > metadata.json
cat metadata.json

