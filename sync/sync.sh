#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) ; readonly dir
cd "${dir}/.."

# Stage 1 sync
set -x
vendir sync
{ set +x; } 2>/dev/null

# Remove trailing whitespace end of lines (hack to fix vendir bug)
find vendor/ -type f -exec sed -i 's/[[:space:]]*$//' {} \;

# Patches
#./sync/patches/example/patch.sh

