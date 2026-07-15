fn get(v: &[i32], i: usize) -> Option<i32> {
    v.get(i).copied()
}
