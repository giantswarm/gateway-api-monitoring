package main

import (
	"encoding/json"
	"fmt"
	"os"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintf(os.Stderr, "Usage: %s <original.json> <patch.json>\n", os.Args[0])
		os.Exit(1)
	}

	originalPath := os.Args[1]
	patchPath := os.Args[2]

	// Read original file
	originalData, err := os.ReadFile(originalPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading original file: %v\n", err)
		os.Exit(1)
	}

	// Parse JSON
	var original map[string]any
	if err := json.Unmarshal(originalData, &original); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing original JSON: %v\n", err)
		os.Exit(1)
	}

	// Read patch file
	patchData, err := os.ReadFile(patchPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading patch file: %v\n", err)
		os.Exit(1)
	}

	var patch map[string]any
	if err := json.Unmarshal(patchData, &patch); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing patch JSON: %v\n", err)
		os.Exit(1)
	}

	// Merge patch into original
	merged := deepMerge(original, patch)

	// Write result
	result, err := json.MarshalIndent(merged, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling result: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(originalPath, result, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing result: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Successfully merged %s into %s\n", patchPath, originalPath)
}

// deepMerge recursively merges patch into original.
// - For maps: recursively merge, patch values override original
// - For slices with objects containing "name" field: merge by name (update existing, add new)
// - For other values: patch overrides original
func deepMerge(original, patch map[string]any) map[string]any {
	result := make(map[string]any)

	// Copy original values
	for k, v := range original {
		result[k] = v
	}

	// Apply patch
	for k, patchVal := range patch {
		origVal, exists := result[k]
		if !exists {
			result[k] = patchVal
			continue
		}

		// Both are maps: recursive merge
		origMap, origIsMap := origVal.(map[string]any)
		patchMap, patchIsMap := patchVal.(map[string]any)
		if origIsMap && patchIsMap {
			result[k] = deepMerge(origMap, patchMap)
			continue
		}

		// Both are slices: try to merge by "name" field
		origSlice, origIsSlice := origVal.([]any)
		patchSlice, patchIsSlice := patchVal.([]any)
		if origIsSlice && patchIsSlice {
			result[k] = mergeSlices(origSlice, patchSlice)
			continue
		}

		// Default: patch overrides
		result[k] = patchVal
	}

	return result
}

// mergeSlices merges two slices. If elements have a "name" field, merge by name.
// Otherwise, append patch elements to original.
func mergeSlices(original, patch []any) []any {
	// Check if we can merge by "name"
	if canMergeByName(original) && canMergeByName(patch) {
		return mergeByName(original, patch)
	}

	// Default: append patch to original
	return append(original, patch...)
}

// canMergeByName checks if all elements in the slice are maps with a "name" field
func canMergeByName(slice []any) bool {
	if len(slice) == 0 {
		return true
	}
	for _, item := range slice {
		m, ok := item.(map[string]any)
		if !ok {
			return false
		}
		if _, hasName := m["name"]; !hasName {
			return false
		}
	}
	return true
}

// mergeByName merges slices by the "name" field of each element
func mergeByName(original, patch []any) []any {
	// Build index of original items by name
	origByName := make(map[string]int)
	for i, item := range original {
		m := item.(map[string]any)
		name := m["name"].(string)
		origByName[name] = i
	}

	// Create result with original items
	result := make([]any, len(original))
	copy(result, original)

	// Process patch items
	for _, patchItem := range patch {
		patchMap := patchItem.(map[string]any)
		name := patchMap["name"].(string)

		if idx, exists := origByName[name]; exists {
			// Merge with existing item
			origMap := result[idx].(map[string]any)
			result[idx] = deepMerge(origMap, patchMap)
		} else {
			// Append new item
			result = append(result, patchItem)
		}
	}

	return result
}
