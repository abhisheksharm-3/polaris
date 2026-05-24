# Rust Stack Rules

---

## Before Starting Any Work

Check installed versions:
```bash
cargo --version
rustc --version
cat Cargo.toml | grep -E '(tokio|axum|sqlx|serde|anyhow|thiserror|tracing)'
```

Fetch current docs:
- **The Rust Book**: WebFetch `https://doc.rust-lang.org/book/` for ownership/borrowing fundamentals
- **Tokio**: WebFetch `https://tokio.rs/tokio/tutorial` for the installed version
- **Axum**: WebFetch `https://docs.rs/axum/latest/axum/` if used
- **SQLx**: WebFetch `https://docs.rs/sqlx/latest/sqlx/` for async DB patterns
- **Serde**: WebFetch `https://serde.rs/` for serialization patterns

---

## Error Handling

```rust
// REQUIRED — use thiserror for library/domain errors
use thiserror::Error;

#[derive(Debug, Error)]
pub enum UserError {
    #[error("User not found: {id}")]
    NotFound { id: Uuid },
    #[error("Email already in use")]
    EmailConflict,
    #[error("Database error")]
    Database(#[from] sqlx::Error),
}

// REQUIRED — propagate with ?
async fn create_user(db: &PgPool, data: CreateUserInput) -> Result<User, UserError> {
    let user = sqlx::query_as!(User, "INSERT INTO users ... RETURNING *", ...)
        .fetch_one(db)
        .await?;
    Ok(user)
}

// BANNED — unwrap in production code
let user = get_user(id).unwrap(); // panics on None/Err

// BANNED — bare expect with unhelpful message
let config = read_config().expect("failed"); // use descriptive message if expect is justified at startup

// ALLOWED — expect only at startup/initialization where panic is acceptable
let db = PgPool::connect(&database_url)
    .await
    .expect("Failed to connect to database — check DATABASE_URL");
```

Use `anyhow` only for application-level error aggregation (binary entry points), not in library code.

---

## Ownership and Borrowing

```rust
// PREFER borrowed references — don't take ownership unless needed
fn print_user(user: &User) { ... }         // correct
fn process_user(user: User) { ... }        // only if function needs to own it

// AVOID clone() — document why if used
let name = user.name.clone();  // clone is a code smell; add a comment explaining why

// SHARED MUTABLE STATE — use Arc<Mutex<T>> or Arc<RwLock<T>>
use std::sync::{Arc, RwLock};
let cache: Arc<RwLock<HashMap<Uuid, User>>> = Arc::new(RwLock::new(HashMap::new()));
```

## Async (Tokio)

```rust
// REQUIRED — async for all I/O
#[tokio::main]
async fn main() -> anyhow::Result<()> { ... }

// BANNED — blocking calls in async context
std::thread::sleep(Duration::from_secs(1));  // use tokio::time::sleep
std::fs::read_to_string(path);               // use tokio::fs::read_to_string

// CPU-BOUND work — spawn_blocking to avoid blocking the async runtime
let result = tokio::task::spawn_blocking(|| heavy_computation()).await?;

// CONCURRENT I/O — use join! or select!, not sequential awaits
let (users, orders) = tokio::join!(fetch_users(db), fetch_orders(db));
```

## Axum (if detected)

```rust
use axum::{extract::State, http::StatusCode, response::Json, routing::post, Router};

// State injection via Extension or State extractor
async fn create_user(
    State(db): State<PgPool>,
    Json(payload): Json<CreateUserInput>,
) -> Result<(StatusCode, Json<User>), AppError> {
    let user = user_service::create(&db, payload).await?;
    Ok((StatusCode::CREATED, Json(user)))
}

// Typed error response — implement IntoResponse for AppError
impl IntoResponse for AppError {
    fn into_response(self) -> axum::response::Response {
        let (status, message) = match self {
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, msg),
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, "Unauthorized".into()),
            AppError::Internal(_) => (StatusCode::INTERNAL_SERVER_ERROR, "Internal error".into()),
        };
        (status, Json(json!({ "error": message }))).into_response()
    }
}
```

## SQLx (if detected)

```rust
// PREFER — compile-time checked queries
let user = sqlx::query_as!(
    User,
    "SELECT id, name, email FROM users WHERE id = $1",
    id
)
.fetch_optional(&db)
.await?;

// Always use parameterized queries — never string interpolation in SQL
// BANNED
let query = format!("SELECT * FROM users WHERE email = '{}'", email); // SQL injection
```

## Code Quality

```rust
// Clippy must pass with no warnings — run before every commit
// cargo clippy -- -D warnings

// Format with rustfmt before every commit
// cargo fmt

// No unsafe blocks without a safety comment
unsafe {
    // SAFETY: ptr is guaranteed non-null because it was returned from Box::into_raw
    // and we are the sole owner at this point.
    Box::from_raw(ptr)
}

// Derive common traits where applicable
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct User { ... }
```

## Testing

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_user_returns_user_with_id() {
        let db = test_db().await;
        let input = CreateUserInput { name: "Alice".into(), email: "alice@example.com".into() };
        let user = create_user(&db, input).await.unwrap();
        assert!(!user.id.is_nil());
        assert_eq!(user.name, "Alice");
    }
}
```

- Integration tests in `tests/` directory — use a real test database
- Unit tests in `#[cfg(test)]` modules co-located with the code they test
- No global mutable state in tests — each test gets its own isolated DB transaction
