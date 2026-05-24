# Go Stack Rules

---

## Before Starting Any Work

Check installed versions:
```bash
go version
cat go.mod | grep -E '(module|go |github\.com/(gin|echo|chi|fiber)|gorm|pgx|uber-go)'
```

Fetch current docs:
- **Go stdlib**: WebFetch `https://pkg.go.dev/std` for the installed Go version
- **Gin/Echo/Chi**: WebFetch the specific router's docs for the version in go.mod
- **pgx**: WebFetch `https://pkg.go.dev/github.com/jackc/pgx/v5` for v5 patterns (v4 differs significantly)
- **Go generics**: WebFetch `https://go.dev/blog/intro-generics` if using Go 1.18+

---

## Error Handling (zero tolerance)

```go
// REQUIRED — check every error
result, err := someOperation()
if err != nil {
    return fmt.Errorf("failed to do X: %w", err)
}

// BANNED — ignoring errors
result, _ := someOperation() // never ignore errors

// REQUIRED — wrap with context at every layer
func GetUser(ctx context.Context, id uuid.UUID) (*User, error) {
    user, err := db.QueryUser(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("GetUser %s: %w", id, err)
    }
    return user, nil
}

// REQUIRED — sentinel errors for inspectable domain errors
var ErrUserNotFound = errors.New("user not found")
var ErrEmailConflict = errors.New("email already in use")

// Check with errors.Is, not string comparison
if errors.Is(err, ErrUserNotFound) {
    http.Error(w, "Not found", http.StatusNotFound)
    return
}
```

---

## Context (always required)

```go
// REQUIRED — context.Context as first parameter on all functions that do I/O
func CreateOrder(ctx context.Context, db *pgxpool.Pool, input CreateOrderInput) (*Order, error) { ... }
func SendEmail(ctx context.Context, client *EmailClient, to string, body string) error { ... }

// REQUIRED — propagate context from HTTP handler to all downstream calls
func (h *Handler) CreateOrder(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    order, err := h.orderService.Create(ctx, input)
    ...
}

// BANNED — background context in request handlers
ctx := context.Background() // only valid at program startup, not in handlers
```

---

## Concurrency

```go
// Goroutines MUST have a defined exit condition
// BANNED — goroutine that leaks
go func() {
    for {
        processQueue() // runs forever with no way to stop
    }
}()

// REQUIRED — cancellable goroutine
go func(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        default:
            processQueue(ctx)
        }
    }
}(ctx)

// REQUIRED — protect shared mutable state
type UserCache struct {
    mu    sync.RWMutex
    users map[uuid.UUID]*User
}

func (c *UserCache) Get(id uuid.UUID) (*User, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    user, ok := c.users[id]
    return user, ok
}

// Use channels for communication, mutexes for state protection
```

---

## Code Style

```go
// Package names: short, lowercase, no underscores
package userservice  // NOT: user_service, UserService

// Exported names MUST have doc comments
// CreateUser creates a new user record and returns the created user.
// Returns ErrEmailConflict if the email is already registered.
func CreateUser(ctx context.Context, input CreateUserInput) (*User, error) { ... }

// Interface names: verb + er (if single method), or descriptive noun
type UserRepository interface {
    GetByID(ctx context.Context, id uuid.UUID) (*User, error)
    Create(ctx context.Context, input CreateUserInput) (*User, error)
}

// Return early — avoid deep nesting
func processRequest(r *http.Request) error {
    if r.Method != http.MethodPost {
        return ErrMethodNotAllowed
    }
    // ... continue with the happy path
}
```

---

## HTTP Handlers

```go
// Thin handlers — no business logic
func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
    var input CreateUserInput
    if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }

    if err := validate(input); err != nil {
        respondError(w, http.StatusUnprocessableEntity, err.Error())
        return
    }

    user, err := h.userService.Create(r.Context(), input)
    if errors.Is(err, ErrEmailConflict) {
        respondError(w, http.StatusConflict, "email already in use")
        return
    }
    if err != nil {
        h.logger.Error("create user failed", "error", err)
        respondError(w, http.StatusInternalServerError, "internal error")
        return
    }

    respondJSON(w, http.StatusCreated, user)
}
```

---

## Database (pgx v5 if detected)

```go
// REQUIRED — parameterized queries only
row := db.QueryRow(ctx, "SELECT id, name FROM users WHERE email = $1", email)

// BANNED — string interpolation in queries
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email) // SQL injection

// Use pgxpool for connection pooling
pool, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))

// Transactions
tx, err := pool.Begin(ctx)
if err != nil { ... }
defer tx.Rollback(ctx) // safe to call after Commit

// ... operations ...

if err := tx.Commit(ctx); err != nil {
    return fmt.Errorf("commit transaction: %w", err)
}
```

---

## Testing

```go
// Table-driven tests for all non-trivial functions
func TestCreateUser(t *testing.T) {
    tests := []struct {
        name    string
        input   CreateUserInput
        wantErr error
    }{
        { name: "valid input", input: CreateUserInput{Name: "Alice", Email: "alice@x.com"}, wantErr: nil },
        { name: "empty name", input: CreateUserInput{Name: "", Email: "alice@x.com"}, wantErr: ErrValidation },
        { name: "duplicate email", input: CreateUserInput{Name: "Bob", Email: "existing@x.com"}, wantErr: ErrEmailConflict },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            user, err := CreateUser(ctx, tt.input)
            if !errors.Is(err, tt.wantErr) {
                t.Errorf("got error %v, want %v", err, tt.wantErr)
            }
            _ = user
        })
    }
}

// Test files co-located with source: user_service_test.go
// Integration tests use real DB with transactions rolled back after each test
// Mock via interfaces — never global state
```

---

## Code Quality

- `gofmt` applied before every commit — no exceptions
- `golangci-lint` passes with no warnings
- No global mutable variables — inject dependencies via struct fields or function parameters
- All struct fields that are always set at initialization should be non-pointer types
- Use `slog` (Go 1.21+) or `zap` for structured logging — never `fmt.Println` in production
