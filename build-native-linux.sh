#!/bin/sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
music_flags='NOGME=1 NOOPENMPT=1'
if [ "${1:-}" = '--full-music' ]; then
    music_flags=''
    shift
fi


exec make -C "$source_dir/src" -j"${BUILD_JOBS:-4}" LINUX64=1 X86_64=1 SDL=1 \
    RELAXWARNINGS=1 EXENAME=srb2-v1.6.0-linux-x86_64 \
    DBGNAME=srb2-v1.6.0-linux-x86_64.debug \
    makedir=../make-linux-v160-native bin=../bin-linux-v160-native \
    $music_flags "$@"
