return {
    postgres = {
      up = [[
        CREATE TABLE IF NOT EXISTS "lytx_customers" (
          "id"           UUID                         PRIMARY KEY,
          "co_id"        TEXT                         UNIQUE,
          "rootgroupid"  TEXT,
          "iss"          TEXT,
          "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC')
        );
  
        DO $$
        BEGIN
          CREATE INDEX IF NOT EXISTS "lytx_customers_co_id_idx" ON "lytx_customers" ("co_id");
        EXCEPTION WHEN UNDEFINED_COLUMN THEN
          -- Do nothing, accept existing state
        END$$;
      ]],
    },
  
    cassandra = {
      up = [[
        CREATE TABLE IF NOT EXISTS lytx_customers(
          created_at  timestamp,
          id          text,
          co_id       text,
          rootgroupid text,
          iss         text
        );
        CREATE INDEX IF NOT EXISTS ON lytx_customers(co_id);
      ]],
    },
  }