local typedefs = require "kong.db.schema.typedefs"

return {
  {
    primary_key = { "id" },
    name = "lytx_customers",
    endpoint_key = "co_id",
    cache_key = { "co_id" },
    generate_admin_api    = true,
    admin_api_name        = "jwt-auth-rbac",
    fields = {
      { id = typedefs.uuid },
      { co_id = { type = "string", required = true, unique = true, auto = false },},
      { created_at = typedefs.auto_timestamp_s },
      { rootgroupid = { type = "string", required = true, unique = false, auto = false }, },
      { iss = { type = "string", required = true, unique = false, auto = false }, },
    },
  },
}
