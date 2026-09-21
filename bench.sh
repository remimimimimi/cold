#!/usr/bin/env bash
set -euo pipefail

PATH="$PWD:$PATH"

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
args=${1:-/tmp/cold-tests/clang/link.args}

if [[ ! -f $args ]]; then
    echo "Clang link arguments not found: $args" >&2
    exit 1
fi

if [[ -z ${LLVM_BUILD:-} ]]; then
    source "$root/.env"
fi
driver=$LLVM_BUILD/tools/clang/tools/driver
if [[ ! -d $driver ]]; then
    echo "Clang driver build directory not found: $driver" >&2
    exit 1
fi

for command in hyperfine cold mold wild ld; do
    if ! command -v "$command" >/dev/null; then
        echo "Command not found in PATH: $command" >&2
        exit 1
    fi
done

args=$(realpath -- "$args")
cd -- "$driver"

hyperfine \
    --warmup "${WARMUP:-2}" \
    --runs "${RUNS:-10}" \
    --shell=bash \
    --command-name 'wild (1 thread)' \
        'mapfile -t a < '"$(printf '%q' "$args")"'; wild --no-threads "${a[@]}"' \
    --command-name 'mold (1 thread)' \
        'mapfile -t a < '"$(printf '%q' "$args")"'; mold --thread-count=1 "${a[@]}"' \
    --command-name cold \
        'mapfile -t a < '"$(printf '%q' "$args")"'; cold "${a[@]}"' \
    --command-name 'GNU ld' \
        'mapfile -t a < '"$(printf '%q' "$args")"'; ld "${a[@]}"'
