BEGIN;

SELECT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'cbv');

ROLLBACK;