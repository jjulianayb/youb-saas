-- Real two-session concurrency proof for create_employee_profile.
-- The shell helper launches two independent psql clients against the same database.
\set ON_ERROR_STOP on
\! bash scripts/test-sql-concurrency.sh
\if :SHELL_ERROR
  \echo 'Concurrent employee creation helper failed.'
  \quit 3
\endif
