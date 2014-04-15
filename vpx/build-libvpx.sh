#!/usr/bin/env bash

ROOT_DIR="`pwd`"
SRC_DIR="`pwd`/libvpx"
BUILD_DIR="`pwd`/build"
LIB_DIR="`pwd`/lib"
INCLUDE_DIR="`pwd`/include"

OLD_XCODE_DIR="/Applications/Xcode4.app/"
NEW_XCODE_DIR="/Applications/Xcode.app/"

SDK_PATH="${OLD_XCODE_DIR}Contents/Developer/Platforms/iPhoneOS.platform/Developer/"

OLD_SDK_DIR="${OLD_XCODE_DIR}Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.1.sdk/"
NEW_SDK_DIR="${NEW_XCODE_DIR}Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS7.1.sdk/"


# Compile for each of the four architecures (i386 for simulator)

# We skip amrv6 since it isn't available on latest iOS SDK (6.0 onwards)
# armv6
# cd $ROOT_DIR
# mkdir -p $BUILD_DIR/armv6
# cd $BUILD_DIR/armv6
# $SRC_DIR/configure --target=armv6-darwin-gcc  --sdk-path=$SDK_PATH --libc=$OLD_SDK_DIR
# make 


# armv7
cd $ROOT_DIR
mkdir -p $BUILD_DIR/armv7
cd $BUILD_DIR/armv7
$SRC_DIR/configure --target=armv7-darwin-gcc  --sdk-path=$SDK_PATH --libc=$NEW_SDK_DIR
make 


# We skip armv7s because it isn't supported yet by vp8

# armv7s
#cd $ROOT_DIR
#mkdir -p $BUILD_DIR/armv7s
#cd $BUILD_DIR/armv7s
#$SRC_DIR/configure --target=armv7s-darwin-gcc  --sdk-path=$SDK_PATH --libc=$NEW_SDK_DIR
#make 


# We skip this becuase it doesn't seem to build - complains about optimisation level

cd $ROOT_DIR
mkdir -p $BUILD_DIR/i386
cd $BUILD_DIR/i386
$SRC_DIR/configure --target=x86-darwin9-gcc  --sdk-path=$SDK_PATH --libc=$NEW_SDK_DIR
make 


# Combine into universal binary
mkdir -p $LIB_DIR
xcrun -sdk iphoneos lipo -create -arch armv7 $BUILD_DIR/armv7/libvpx.a -arch i386 $BUILD_DIR/i386/libvpx.a  -output $LIB_DIR/libvpx.a
# -arch armv6 $BUILD_DIR/armv6/libvpx.a -arch armv7 $BUILD_DIR/armv7/libvpx.a -arch armv7s $BUILD_DIR/armv7s/libvpx.a -arch i386 $BUILD_DIR/i386/libvpx.a

# Copy headers
mkdir -p $INCLUDE_DIR
cd $SRC_DIR
cp vpx/*.h $INCLUDE_DIR
#for f in $BUILD_DIR/*.h; do sed -i '' 's/\#include "vpx\//\#include "/' $f; done 