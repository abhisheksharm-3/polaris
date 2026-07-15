package main

import "errors"

func get(m map[string]int, k string) (int, error) {
	v, ok := m[k]
	if !ok {
		return 0, errors.New("missing key")
	}
	return v, nil
}
