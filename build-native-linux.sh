#!/bin/sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
music_flags='NOGME=1 NOOPENMPT=1'
if [ "${1:-}" = '--full-music' ]; then
    music_flags=''
    shift
fi
# The fixed optional flags intentionally expand into separate make arguments.
# Remaining user arguments are passed through without re-evaluation.
exec make -C "$source_dir/src" -j"${BUILD_JOBS:-4}" LINUX64=1 X86_64=1 SDL=1 \
    RELAXWARNINGS=1 EXENAME=srb2-v5.150-linux-x86_64 \
    DBGNAME=srb2-v5.150-linux-x86_64.debug \
    makedir=../make-linux-v5150-native bin=../bin-linux-v5150-native \
    $music_flags "$@"
