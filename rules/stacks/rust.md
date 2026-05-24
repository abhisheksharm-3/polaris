# Rust Stack Rules

## Error Handling
- Use `Result<T, E>` for all fallible operations. No `.unwrap()` in production code.
- Custom error types with `thiserror`. Propagate with `?`.
- `anyhow` for application-level error aggregation only.

## Ownership and Borrowing
- Prefer borrowed references (`&T`) over owned values when the callee doesn't need ownership.
- Avoid `clone()` unless profiling shows it's not a bottleneck. Document why clone is needed.
- Use `Arc<Mutex<T>>` for shared mutable state across threads.

## Async (Tokio)
- All async functions must be non-blocking. No `std::thread::sleep` in async context.
- Use `tokio::spawn` for CPU-bound work with `spawn_blocking`.

## Quality Gates
- `cargo clippy -- -D warnings` must pass with no warnings.
- `cargo fmt` applied before every commit.
- No `unsafe` blocks without a safety comment explaining the invariant maintained.
