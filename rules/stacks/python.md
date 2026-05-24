# Python Stack Rules

## Code Style
- Type hints on all function signatures (parameters and return types).
- Pydantic models for data validation at boundaries (API input/output).
- No bare `except:` — always catch specific exceptions.

## FastAPI (if detected)
- Dependency injection via `Depends()` for DB sessions and auth.
- Response models explicitly declared on all endpoints.
- All endpoints return typed response models, never raw dicts.
- Async endpoints (`async def`) for I/O-bound operations.

## Django (if detected)
- Class-based views for CRUD. Function-based views for simple endpoints.
- QuerySets never evaluated in templates — pass Python objects.
- `select_related` / `prefetch_related` on all multi-join queries.

## General
- No f-strings in SQL queries — use parameterized queries.
- Environment variables via `python-dotenv` or `pydantic-settings`.
- Tests with `pytest`. Fixtures for DB setup/teardown.
