#!/usr/bin/env sh








git config 'alias.cmake' '!cmake'











git config 'alias.build' '!p="${1##-*}"; [ "$p" ] && shift; git cmake --build --preset "${p:-default}"'






git config 'alias.crossmake' '!i686-w64-mingw32-cmake'
