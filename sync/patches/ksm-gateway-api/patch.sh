#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# ------------------------------------------------------------------------------
# Setup paths
# ------------------------------------------------------------------------------

repo_dir=$(git rev-parse --show-toplevel)
readonly repo_dir

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly script_dir

readonly script_dir_rel=".${script_dir#"${repo_dir}"}"
readonly ksm_base="${repo_dir}/ksm/gateway-api"

cd "${repo_dir}"

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------

# Modify a dashboard file in-place with yq
yq_patch() {
    local file="$1"
    local expression="$2"
    yq -i -- "$expression" "$file"
}

patch_gateway_api_state() {
    local file="$ksm_base/custom-resource-state.yaml"

    yq_patch "$file" '.spec'

    # Add rbac block with apiGroups and resources derived from the custom-resource-state
    yq_patch "$file" '.rbac = [
        {
            "apiGroups": [.resources[].groupVersionKind.group] | unique,
            "resources": [.resources[].groupVersionKind.kind | downcase + "s"] | unique,
            "verbs": ["list", "watch"]
        }
    ]'
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

set -x

patch_gateway_api_state

{ set +x; } 2>/dev/null
