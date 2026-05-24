# Go Stack Rules

## Error Handling
- Check every error. No `_` for error values.
- Wrap errors with context: `fmt.Errorf("failed to create user: %w", err)`.
- Custom error types for domain errors that callers may need to inspect.

## Code Style
- `gofmt` and `golint` applied before every commit.
- Package names: short, lowercase, no underscores.
- Exported names must have doc comments.

## Concurrency
- No shared mutable state without a mutex or channel.
- Goroutines must have a defined exit condition. No goroutine leaks.
- Use `context.Context` for cancellation and timeouts — pass as first parameter.

## Testing
- Table-driven tests with `t.Run()` for multiple cases.
- Test file names: `<file>_test.go`. No separate `tests/` directory.
- Mocks via interfaces, not global state.
