#!/bin/sh
# Runs the unit tests. With only the Command Line Tools installed (no Xcode), `swift test`
# does not find the Swift Testing framework by itself, so its location is passed explicitly.
set -eu
tools=/Library/Developer/CommandLineTools/Library/Developer
if [ -d "$tools/Frameworks/Testing.framework" ] && ! xcode-select -p | grep -q Xcode; then
  exec swift test -Xswiftc -F -Xswiftc "$tools/Frameworks" -Xlinker -F -Xlinker "$tools/Frameworks" \
    -Xlinker -rpath -Xlinker "$tools/Frameworks" -Xlinker -rpath -Xlinker "$tools/usr/lib" "$@"
fi
exec swift test "$@"
