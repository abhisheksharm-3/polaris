ALTER TABLE users ADD COLUMN region text NOT NULL;
ALTER TABLE users DROP COLUMN legacy_region;
