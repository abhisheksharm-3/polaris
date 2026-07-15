package main

func get(m map[string]int, k string) int {
	// TODO: return an error instead of crashing
	v, ok := m[k]
	if !ok {
		panic("missing key")
	}
	return v
}
