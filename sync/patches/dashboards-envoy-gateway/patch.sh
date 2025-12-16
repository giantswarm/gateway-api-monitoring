#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

repo_dir=$(git rev-parse --show-toplevel) ; readonly repo_dir
script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) ; readonly script_dir

cd "${repo_dir}"

readonly script_dir_rel=".${script_dir#"${repo_dir}"}"
dashboard_base="${repo_dir}/dashboards/envoy-gateway"

merger="${repo_dir}/hack/merger/merger"

set -x

# Merge patch file into dashboard
"${merger}" "${dashboard_base}/envoy-clusters.json" "${script_dir}/envoy-clusters-patch.json"
"${merger}" "${dashboard_base}/envoy-gateway-global.json" "${script_dir}/envoy-gateway-global-patch.json"
"${merger}" "${dashboard_base}/envoy-proxy-global.json" "${script_dir}/envoy-proxy-global-patch.json"

{ set +x; } 2>/dev/null
