#!/bin/sh

#/ Usage: copy-swift-binary.sh <build_hostname> <destination_hostname>
#/
#/   <build_hostname>            builder machine to copy down target file and dependencies from
#/   <destination_hostname>      target machine to upload to
#/
#/ This script makes a few assumptions— the main one being that your build host is separate from
#/ where you need to upload or run it. In addition it assumes you use
#/ [Swiftenv](http://swiftenv.fuller.li) to install Swift on your build host. Lastly, it's going to
#/ bundle up most of the Swift libraries.

set -e

APPNAME="APPNAME"
SWIFT_VERSION="4.0.3"

usage() {
    grep "^#/" "$0" | cut -c"4-" >&2
    exit "$1"
}
BUILDER="" TARGET=""
while [ "$#" -gt 0 ]
do
    case "$1" in
        -h|--help) usage 0;;
        -*) usage 1;;
        *) break;;
    esac
done
if [ -z "$1" ] || [ -z "$2" ]
then usage 1
fi

BUILDER="${1}"
TARGET="${2}"

mkdir -p "./${APPNAME}_Bundle"
rm -f "./${APPNAME}_Bundle/${APPNAME}"

# Set rpath to point to the binary's current directory when it runs
# https://bugs.swift.org/browse/SR-674
ssh "${BUILDER}" "cd /home/jmsmith/workspace/${APPNAME}; /home/jmsmith/.swiftenv/shims/swift build" # -Xlinker -rpath -Xlinker '\$ORIGIN'"

scp "${BUILDER}:/home/jmsmith/workspace/${APPNAME}/.build/debug/${APPNAME}" "./${APPNAME}_Bundle/${APPNAME}"

for FILENAME in libdispatch.la libdispatch.so libFoundation.so libswiftCore.so libswiftGlibc.so libswiftRemoteMirror.so libswiftSwiftOnoneSupport.so libXCTest.so x86_64/; do
    if [ ! -f "./${APPNAME}_Bundle/${FILENAME}" ] && [ ! -d "./${APPNAME}_Bundle/${FILENAME}" ]
    then
        scp -r "${BUILDER}:/home/jmsmith/.swiftenv/versions/${SWIFT_VERSION}/usr/lib/swift/linux/${FILENAME}" "./${APPNAME}_Bundle/${FILENAME}"
    fi
done

rm -f "./${APPNAME}.tar.bz"
tar -cjvf "./${APPNAME}.tar.bz" "./${APPNAME}_Bundle"

scp "./${APPNAME}.tar.bz" "${TARGET}:"

ssh "${TARGET}" "tar -xjvf ./${APPNAME}.tar.bz"

ssh "${TARGET}" "./${APPNAME}_Bundle/${APPNAME}"
