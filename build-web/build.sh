#!/bin/bash

set -e

# Config

# To speed up builds with single-threaded full LTO linking,
# we run all builds in parallel each from their own folder.
export NUM_JOBS=5
declare -a JOBS=(
  "target=editor use_closure_compiler=yes"
  "target=template_debug"
  "target=template_release"
  "target=template_debug dlink_enabled=yes"
  "target=template_release dlink_enabled=yes"
)

export SCONS="scons -j$(expr ${NUM_CORES} / ${NUM_JOBS}) verbose=yes warnings=no progress=no"
export OPTIONS="production=yes"
export OPTIONS_MONO="module_mono_enabled=yes -j${NUM_CORES}"
export TERM=xterm

source /root/emsdk/emsdk_env.sh

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

dnf -y install gettext

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Web..."

  for i in {0..4}; do
    cp -r /root/godot /root/godot$i
    cd /root/godot$i
    echo "$SCONS platform=web ${OPTIONS} ${JOBS[$i]}"
    $SCONS platform=web ${OPTIONS} ${JOBS[$i]} &
    pids[$i]=$!
  done

  for pid in ${pids[*]}; do
    wait $pid
  done

  mkdir -p /root/out/tools
  cp -rvp /root/godot0/bin/*.editor*.zip /root/out/tools

  mkdir -p /root/out/templates
  for i in {1..4}; do
    cp -rvp /root/godot$i/bin/*.zip /root/out/templates
  done
fi

# Mono

# No Web support with .NET 6 yet.
#if [ "${MONO}" == "1" ]; then
if false; then
  echo "Starting Mono build for Web..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/

  $SCONS platform=web ${OPTIONS} ${OPTIONS_MONO} target=template_debug
  $SCONS platform=web ${OPTIONS} ${OPTIONS_MONO} target=template_release

  mkdir -p /root/out/templates-mono
  cp -rvp bin/*.zip /root/out/templates-mono
  rm -f bin/*.zip
fi

echo "Web build successful"
