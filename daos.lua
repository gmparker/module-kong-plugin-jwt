local typedefs = require "kong.db.schema.typedefs"

return {
  {
    primary_key = { "co_id" },
    name = "lytx_customers2",
    fields = {
      { co_id = { type = "string", required = false, unique = false, auto = false },},
      { created_at = typedefs.auto_timestamp_s },
      { rootgroupid = { type = "string", required = false, unique = false, auto = false }, },
      { iss = { type = "string", required = false, unique = false, auto = false }, },
    },
  },
}
