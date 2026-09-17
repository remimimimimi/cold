#!/usr/bin/env sh
set -eu

build=$1; args=$2; out=$3; shim=$4
dir=$build/tools/clang/tools/driver
link=$dir/CMakeFiles/clang.dir/link.txt
cmd=$(sed "s| -o [^ ]*| -o '$out'|" "$link")
compiler=${cmd%% *}; arguments=${cmd#* }

export COLD_LINK_ARGS=$args
cd "$dir"
eval "$compiler -fno-use-linker-plugin -B'$shim' $arguments"
