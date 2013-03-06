#!/bin/bash

ROOT_DIR="`pwd`"
SRC_DIR="`pwd`/libvpx"
BUILD_DIR="`pwd`/build"
LIB_DIR="`pwd`/lib"
INCLUDE_DIR="`pwd`/include"

SDK_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.1.sdk/"

# Compile for each of the four architecures (i386 for simulator)

# We skip amrv6 since it isn't available on latest iOS SDK (6.0 onwards)
#cd $ROOT_DIR
#mkdir -p $BUILD_DIR/armv6
#cd $BUILD_DIR/armv6 
#$SRC_DIR/configure --target=armv6-darwin-gcc --sdk-path=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer --libc=$SDK_DIR
#make 

cd $ROOT_DIR
mkdir -p $BUILD_DIR/armv7
cd $BUILD_DIR/armv7
$SRC_DIR/configure --target=armv7-darwin-gcc  --sdk-path=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer --libc=$SDK_DIR
make 

# We skip armv7s because it isn't supported yet by vp8
#cd $ROOT_DIR
#mkdir -p $BUILD_DIR/armv7s
#cd $BUILD_DIR/armv7s
#$SRC_DIR/configure --target=armv7s-darwin-gcc  --sdk-path=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer --libc=$SDK_DIR
#make 

#We skip this becuase it doesn't seem to build - complains about optimisation level
#cd $ROOT_DIR
#mkdir -p $BUILD_DIR/i386 
#cd $BUILD_DIR/i386
#$SRC_DIR/configure --target=x86-darwin9-gcc  --sdk-path=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer --libc=$SDK_DIR
#make

# Combine into universal binary
mkdir -p $LIB_DIR
xcrun -sdk iphoneos lipo -create -arch armv7 $BUILD_DIR/armv7/libvpx.a  -output $LIB_DIR/libvpx.a

# Copy headers
mkdir -p $INCLUDE_DIR
cd $SRC_DIR
cp vpx/*.h $INCLUDE_DIR
#for f in $BUILD_DIR/*.h; do sed -i '' 's/\#include "vpx\//\#include "/' $f; done 