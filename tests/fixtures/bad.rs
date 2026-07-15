fn get(v: &[i32], i: usize) -> i32 {
    // TODO: add a bounds check
    dbg!(i);
    *v.get(i).unwrap()
}
