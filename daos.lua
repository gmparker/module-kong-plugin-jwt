local typedefs = require "kong.db.schema.typedefs"

return {
  {
    primary_key = { "co_id" },
    cache_key = { "co_id" },
    name = "lytx_customers",
    fields = {
      { co_id = { type = "string", required = false, unique = true, auto = true },},
      { created_at = typedefs.auto_timestamp_s },
      { rootgroupid = { type = "string", required = false, unique = false, auto = false }, },
      { iss = { type = "string", required = false, unique = false, auto = false }, },
    },
  },
}
