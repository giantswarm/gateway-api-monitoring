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
readonly dashboard_base="${repo_dir}/dashboards/envoy-gateway"

cd "${repo_dir}"

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------

# Modify a dashboard JSON file in-place with yq
yq_patch() {
    local file="$1"
    local expression="$2"
    yq -i -o json --prettyPrint -- "$expression" "$file"
}

# Add cluster_id filter to all PromQL expressions in panels and templating
# Pattern matches { preceded by a word character (metric name), not $ (Grafana variable)
# Handles both empty {} and non-empty {filters} cases to avoid trailing comma
add_promql_label_filter() {
    local file="$1"

    # Panels: handle non-empty filters {x} -> {cluster_id="$workload_cluster", x}
    yq -i -o json --prettyPrint \
        '(.panels[] | select(.type != "row") | .targets[].expr) |= sub("(\w)\{([^}])", "${1}{cluster_id=\"$$workload_cluster\", ${2}")' \
        "$file"
    # Panels: handle empty filters {} -> {cluster_id="$workload_cluster"}
    yq -i -o json --prettyPrint \
        '(.panels[] | select(.type != "row") | .targets[].expr) |= sub("(\w)\{\}", "${1}{cluster_id=\"$$workload_cluster\"}")' \
        "$file"
    # Panels: handle no filters - metric followed by [ (range) -> metric{cluster_id="$workload_cluster"}[
    yq -i -o json --prettyPrint \
        '(.panels[] | select(.type != "row") | .targets[].expr) |= sub("(\w)\[", "${1}{cluster_id=\"$$workload_cluster\"}[")' \
        "$file"

    # Templating definitions use label_values() with two formats:
    #   label_values(metric{filters}, name) -> add to existing filters
    #   label_values(metric) -> add new filter block

    # Handle: label_values(metric{filters}, name) -> label_values(metric{cluster_id="$workload_cluster", filters}, name)
    yq -i -o json --prettyPrint \
        '(.templating.list[] | select(.name != "datasource") | .definition) |= sub("(\w)\{([^}])", "${1}{cluster_id=\"$$workload_cluster\", ${2}")' \
        "$file"
    yq -i -o json --prettyPrint \
        '(.templating.list[] | select(.name != "datasource") | .query.query) |= sub("(\w)\{([^}])", "${1}{cluster_id=\"$$workload_cluster\", ${2}")' \
        "$file"
    # Handle: label_values(metric, name) -> label_values(metric{cluster_id="$workload_cluster"}, name)
    # Match metric name followed by comma - no filters present
    yq -i -o json --prettyPrint \
        '(.templating.list[] | select(.name != "datasource") | .definition) |= sub("label_values\((\w+),", "label_values(${1}{cluster_id=\"$$workload_cluster\"},")' \
        "$file"
    yq -i -o json --prettyPrint \
        '(.templating.list[] | select(.name != "datasource") | .query.query) |= sub("label_values\((\w+),", "label_values(${1}{cluster_id=\"$$workload_cluster\"},")' \
        "$file"
    # Handle: label_values(name) -> label_values({cluster_id="$workload_cluster"}, name)
    # Match label name followed by ) - no filters present, single argument
    yq -i -o json --prettyPrint \
        '(.templating.list[] | select(.name != "datasource") | .definition) |= sub("label_values\((\w+)\)", "label_values({cluster_id=\"$$workload_cluster\"}, ${1})")' \
        "$file"
    yq -i -o json --prettyPrint \
        '(.templating.list[] | select(.name != "datasource") | .query.query) |= sub("label_values\((\w+)\)", "label_values({cluster_id=\"$$workload_cluster\"}, ${1})")' \
        "$file"
}

# Add workload_cluster variable to .templating.list (appended at the end)
add_workload_cluster_variable() {
    local file="$1"
    yq -i -o json --prettyPrint '
        {
            "current": {
                "selected": false,
                "text": "",
                "value": ""
            },
            "datasource": {
                "uid": "$datasource"
            },
            "definition": "label_values(kubernetes_build_info, cluster_id)",
            "hide": 0,
            "includeAll": false,
            "label": "Workload Cluster",
            "multi": false,
            "name": "workload_cluster",
            "options": [],
            "query": {
                "query": "label_values(kubernetes_build_info, cluster_id)",
                "refId": "PrometheusVariableQueryEditor-VariableQuery"
            },
            "refresh": 1,
            "regex": "",
            "skipUrlSync": false,
            "sort": 1,
            "type": "query"
        } as $wc |
        .templating.list = [.templating.list[0]] + [$wc] + [.templating.list[1,2,3,4]]
    ' "$file"
}

# ------------------------------------------------------------------------------
# Patch: envoy-clusters.json
# ------------------------------------------------------------------------------

patch_envoy_clusters() {
    local dfile="$dashboard_base/envoy-clusters.json"

    # Update dashboard title
    yq_patch "$dfile" '.title = "Envoy Gateway | Clusters"'

    # Add workload_cluster filter to all PromQL expressions
    add_promql_label_filter "$dfile"

    # Add workload_cluster variable to templating
    add_workload_cluster_variable "$dfile"
}

# ------------------------------------------------------------------------------
# Patch: envoy-gateway-global.json
# ------------------------------------------------------------------------------

patch_envoy_gateway_global() {
    local dfile="$dashboard_base/envoy-gateway-global.json"

    # Update dashboard title
    yq_patch "$dfile" '.title = "Envoy Gateway | Global"'

    # Add workload_cluster filter to all PromQL expressions
    add_promql_label_filter "$dfile"

    # Add workload_cluster variable to templating
    add_workload_cluster_variable "$dfile"
}

# ------------------------------------------------------------------------------
# Patch: envoy-proxy-global.json
# ------------------------------------------------------------------------------

patch_envoy_proxy_global() {
    local dfile="$dashboard_base/envoy-proxy-global.json"

    # Update dashboard title
    yq_patch "$dfile" '.title = "Envoy Gateway | Proxy Global"'

    # Add workload_cluster filter to all PromQL expressions
    add_promql_label_filter "$dfile"

    # Add workload_cluster variable to templating
    add_workload_cluster_variable "$dfile"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

set -x

patch_envoy_clusters
patch_envoy_gateway_global
patch_envoy_proxy_global

{ set +x; } 2>/dev/null
