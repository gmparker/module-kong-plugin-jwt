return {
    postgres = {
      up = [[
        CREATE TABLE IF NOT EXISTS "lytx_customers2" (
          "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
          "co_id"        TEXT   PRIMARY KEY,
          "rootgroupid"  TEXT,
          "iss"          TEXT
        );
  
        DO $$
        BEGIN
          CREATE INDEX IF NOT EXISTS "lytx_customers_co_id_idx" ON "lytx_customers2" ("co_id");
        EXCEPTION WHEN UNDEFINED_COLUMN THEN
          -- Do nothing, accept existing state
        END$$;
      ]],
    },
  
    cassandra = {
      up = [[
        CREATE TABLE IF NOT EXISTS lytx_customers2(
          created_at  timestamp,
          co_id       text,
          rootgroupid text,
          iss         text
        );
        CREATE INDEX IF NOT EXISTS ON lytx_customers2(co_id);
      ]],
    },
  }