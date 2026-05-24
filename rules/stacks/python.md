# Python Stack Rules

---

## Before Starting Any Work

Check installed versions:
```bash
cat pyproject.toml | grep -E '(python|fastapi|django|flask|sqlalchemy|pydantic|alembic)'
# or
pip show fastapi django flask sqlalchemy pydantic | grep Version
```

Fetch current docs:
- **FastAPI**: WebFetch `https://fastapi.tiangolo.com/tutorial/` for the installed version
- **Pydantic v2**: WebFetch `https://docs.pydantic.dev/latest/` — v2 is a breaking change from v1
- **SQLAlchemy 2.x**: WebFetch `https://docs.sqlalchemy.org/en/20/` — 2.x async patterns differ significantly
- **Django**: WebFetch `https://docs.djangoproject.com/en/stable/` for the installed version

Never implement Pydantic v1 patterns on a v2 codebase — always verify.

---

## Typing (always required)

```python
# REQUIRED — type hints on all function signatures
async def create_user(user_data: CreateUserSchema) -> UserType:
    ...

# REQUIRED — return types on all public functions
def format_currency(amount: float, currency: str = "USD") -> str:
    ...

# BANNED
def process(data):  # no types
    return data
```

Use `from __future__ import annotations` at the top of files for forward references.

---

## Pydantic v2 (if installed)

```python
from pydantic import BaseModel, field_validator, model_validator

class CreateUserSchema(BaseModel):
    name: str
    email: EmailStr
    age: int

    @field_validator('name')
    @classmethod
    def name_must_not_be_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError('Name cannot be blank')
        return v.strip()

# BANNED in Pydantic v2 — these are v1 patterns
class Config:  # use model_config = ConfigDict(...) instead
    orm_mode = True  # use from_attributes=True in ConfigDict
```

---

## FastAPI (if detected)

### Dependency Injection
```python
# Inject DB sessions and auth — never use global state
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> UserType:
    ...

@router.post("/orders", response_model=OrderType, status_code=201)
async def create_order(
    order_data: CreateOrderSchema,
    current_user: UserType = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OrderType:
    ...
```

### Response models always declared
```python
# REQUIRED — explicit response_model on every endpoint
@router.get("/users/{user_id}", response_model=UserType)
async def get_user(user_id: UUID, db: AsyncSession = Depends(get_db)) -> UserType:
    ...

# BANNED — never return raw dict
@router.get("/users/{user_id}")
async def get_user(user_id: str):
    return {"id": user_id, "name": "..."}  # no validation, no schema
```

### Async endpoints for all I/O
```python
# REQUIRED — async for all DB and HTTP operations
@router.post("/emails/send")
async def send_email(data: SendEmailSchema) -> MessageType:
    await email_service.send(data)
    return MessageType(message="Email queued")
```

### Error handling
```python
from fastapi import HTTPException

# Use HTTPException for client errors, not generic Exception
raise HTTPException(status_code=404, detail="User not found")
raise HTTPException(status_code=403, detail="Insufficient permissions")

# Use middleware for 500s — never expose internal errors to clients
```

---

## Django (if detected)

- **Class-based views** for CRUD operations
- **DRF serializers** for all API responses — never return raw QuerySet or dict
- `select_related()` for FK joins, `prefetch_related()` for M2M — never trigger N+1
- All QuerySets evaluated in views/serializers — never in templates
- **Celery** for background tasks — never long-running operations in request cycle

---

## SQLAlchemy 2.x (if detected)

```python
# 2.x async pattern
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

async def get_user_by_email(db: AsyncSession, email: str) -> UserModel | None:
    result = await db.execute(select(UserModel).where(UserModel.email == email))
    return result.scalar_one_or_none()

# BANNED — sync patterns in async codebase
session.query(UserModel).filter_by(email=email).first()  # sync 1.x pattern
```

---

## General Python Rules

- **No bare `except:`** — always catch specific exceptions
- **No f-strings in raw SQL** — use parameterized queries only
- **No hardcoded secrets** — use `python-dotenv` or `pydantic-settings` for environment variables
- **No mutable default arguments** in function signatures:
  ```python
  # WRONG
  def add_item(items: list = []):  # shared mutable default
  # RIGHT
  def add_item(items: list | None = None):
      items = items or []
  ```
- **No `print()` for logging** — use the `logging` module or `structlog`
- **One module, one responsibility** — split files exceeding 150 lines

## Testing

- **pytest** with fixtures for all setup/teardown — no `unittest.TestCase`
- **Factory Boy** or similar for test data — no hardcoded test fixtures
- **httpx.AsyncClient** for FastAPI endpoint tests (not `TestClient` for async apps)
- Mock external services — never call real APIs or send real emails in tests
- Test file names: `test_[module_name].py` — co-located with the module they test

## Performance

- Cache expensive queries with Redis via `aiocache` or `fastapi-cache2`
- Use database indexes on all columns in `WHERE`, `ORDER BY`, `JOIN` clauses
- Paginate all list endpoints — never return unbounded result sets
- Use `asyncio.gather()` for concurrent I/O operations instead of sequential awaits
