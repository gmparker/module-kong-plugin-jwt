-- Updated handler.lua file for Kong 3.x.x
local cache = kong.cache
local kong = kong
local constants = require "kong.constants"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"
local responses = kong.response

local ngx_error = ngx.ERR
local ngx_debug = ngx.DEBUG
local ngx_log = ngx.log

--Declare variables to determine which policy to apply
local policy_ALL = 'all'
local policy_ANY = 'any'

-- Set plugin version and priority
local JWTAuthHandler = {
  VERSION  = "0.1.0",
  PRIORITY = 950,
}

-- Function to filter a table
-- @param filterFnc (function) filter function
-- @return (table) the filtered table 
function table:filter(filterFnc)
  local result = {}

  for k, v in ipairs(self) do
      if filterFnc(v, k, self) then
          table.insert(result, v)
      end
  end

  return result
end



-- Function to get index of a value at a table.
-- @param any value
-- @return any
function table:find(value)
  for k, v in ipairs(self) do
      if v == value then
          return k
      end
  end
end




-- Function that checks wheter all given roles are also present in the claimed roles
-- @param roles_to_check (array) an array of role names
-- @param claimed_roles (table) list of roles claimed in JWT
-- @return (boolean) true if all given roles are also in the claimed roles
local function all_roles_in_roles_claim(roles_to_check, claimed_roles)
  local result = false
  local diff

  diff = table.filter(roles_to_check, function(value)
           return not table.find(claimed_roles, value)
         end)

  if #diff == 0 then
    result = true
  end

  return result
end




-- Function that checks whether a claimed role is part of a given list of roles.
-- @param roles_to_check (array) an array of role names.
-- @param claimed_roles (table) list of roles claimed in JWT
-- @return (boolean) whether a claimed role is part of any of the given roles.

local function role_in_roles_claim(roles_to_check, claimed_roles)
  local result = false
  for _, role_to_check in ipairs(roles_to_check) do
    for _, role in ipairs(claimed_roles) do
      if role == role_to_check then
        result = true
        break
      end
    end
    if result then
      break
    end
  end
  
  return result
end



-- Function that splits a string into substrings by reparator
-- @param str (string) the string to be splitted
-- @param sep (string) single character string (!) to separate on
-- @return (table) list of separated parts
local function split(str, sep)
  local ret = {}
  local n=1
  for w in str:gmatch("([^"..sep.."]*)") do
     ret[n] = ret[n] or w:gsub("^%s*(.-)%s*$", "%1") -- strip whitespace
     if w ~= "" then
      ret[n] = w
      n = n + 1
     end
  end
  return ret
end




-- Function to query database for customer id if not found in cache
local function load_customer(thisco_id)

  kong.log.notice("Executing database function: " .. tostring(thisco_id))

  --local customer, err = kong.db.lytx_customers:select({co_id = thisco_id})
  local customer, err = kong.db.lytx_customers:select_by_cache_key(thisco_id)
  

  if err then
    kong.log.err("Error when selecting co_id from the database: " .. err)
    return kong.response.exit(401, { message = "Error when selecting co_id from the database: " .. err})
  end
  
  if not customer then
    kong.log.err("Could not find customer ID: " .. tostring(thisco_id))
    return kong.response.exit(401, { message = "Could not find customer ID: " .. tostring(thisco_id)})
  end

  return customer
end
-- End function to query database for customer id if not found in cache






-- Main function to execute
function JWTAuthHandler:access(conf)

  local myvdebug = conf.vdebug
  
  if myvdebug then
      kong.log.notice("Now processing the access hander")
  end


  -- get the JWT from the Nginx context
  -- Commented out and replaced with updated version

  --local token = ngx.ctx.authenticated_jwt_token
  local token = kong.ctx.shared.authenticated_jwt_token
  
  if not token then
    ngx_log(ngx_error, "[jwt-auth-rbac plugin] Cannot get JWT token, add the ",
                       "JWT plugin to be able to use the JWT-Auth-RBAC plugin")
                       return kong.response.exit(403, {
                        message = "You cannot consume this service"
                      })
  end


  -- Decode JWT to get claims values from token
  local jwt, err = jwt_decoder:new(token)
  if err then
    return kong.response.exit(401, { message = "Bad token; " .. tostring(err)})
  end
  

  --Variables from the plugin
  local msg_error_all = conf.msg_error_all
  local msg_error_any = conf.msg_error_any
  local msg_error_not_roles_claimed = conf.msg_error_not_roles_claimed
  
  --Commented out to replace with database call
  --local roles_cfg = conf.roles
  --local myco_id = conf.co_id
  --local myrootgroupid = conf.rootgroupid

  if myvdebug then
    kong.log.notice("Config error message ALL: ", conf.msg_error_all)
    kong.log.notice("Config error message ANY: ", conf.msg_error_any)
    kong.log.notice("Config error message RNC: ", conf.msg_error_not_roles_claimed)
  end

  --variables from the decoded JWT
  local claims = jwt.claims
  local roles = claims[conf.roles_claim_name]
  local thisrootgroupid = claims['rootgroupid']
  local thisco_id = claims['co_id']
  --empty table variable
  local roles_table = {}

if myvdebug then
  kong.log.notice("co_id: ", myco_id)    
  kong.log.notice("rootgroupid: ", myrootgroupid)
  kong.log.notice("thisco_id: ", thisco_id)
  kong.log.notice("thisrootgroupid: ", thisrootgroupid)
end


-- implement caching
--hit_level 1 = hit, 2 = , 3 = miss, 4 = not in DB
--local customer_cache_key = "29e4352d-345f-43bd-9e3a-a69d1376e629" --kong.db.lytx_customers:cache_key(thisco_id)
--local customer_cache_key = thisco_id --kong.db.lytx_customers:cache_key('02595')
--local customer_cache_key = '02595'

local customer_cache_key = kong.db.lytx_customers:cache_key(thisco_id)

local customer, err, hit_level = kong.cache:get(customer_cache_key, nil, load_customer, thisco_id)


if myvdebug then
  kong.log.notice("Cache Hit Level: ", hit_level)
end

-- assign variables values from database / cache lookup
local myco_id = customer.co_id
local myrootgroupid = customer.rootgroupid
local roles_cfg = customer.roles
-- end implement caching


  -- Call function to connect to database and query for co_id passed in claims payload
  --local entity = load_customer(thisco_id)
  --local myco_id = entity.co_id
  --local myrootgroupid = entity.rootgroupid
  -- End call database query function

-- Validate company ID  
if myco_id ~= thisco_id then
  return kong.response.exit(403, { message = "Invalid Company ID"})
end

-- Validate rootgroupID
if myrootgroupid ~= thisrootgroupid then
  return kong.response.exit(403, { message = "Invalid Root Group ID"})
end


if myvdebug then
  kong.log.notice("JWT Claims: ", claims)
  kong.log.notice("roles: ", roles)
  kong.log.notice("roles claim name: ", conf.roles_claim_name)
end

  --check if no roles claimed..
  if not roles then
    return kong.response.exit(403, {message = msg_error_not_roles_claimed})
  end

  
  -- if the claim is a string (single role), make it a table
  if type(roles) == "string" then
    if string.find(roles, ",") then
      roles_table = split(roles, ",")

    else
      table.insert(roles_table, roles)
 
    end
    roles = roles_table
  end


--   if type(roles_cfg) == "table" then
--     -- in declarative db-less setup the roles can be separated by a space
--     if string.find(roles_cfg[1], " ") then
--     conf_roles_table = split(roles_cfg[1], " ")
--     end
--     if string.find(roles_cfg[1], ",") then
--     conf_roles_table = split(roles_cfgs[1], ",")
--     end
--     --roles_cfg = conf_roles_table
-- end

    
--   if type(conf.roles) == "table" then
--   -- in declarative db-less setup the roles can be separated by a space
--   if string.find(conf.roles[1], " ") then
--   conf_roles_table = split(conf.roles[1], " ")
--   end
--   if string.find(conf.roles[1], ",") then
--   conf_roles_table = split(conf.roles[1], ",")
--   end
--   conf.roles = conf_roles_table
--   end


  -- roles_cfg = "read", "write", "full", "update" --  from the Plugin definition
  -- roles = "read" -- from the Claims of the Token
if myvdebug then
    -- log the roles_cfg table from the plugin
    for k,v in pairs(roles_cfg) do
        kong.log.notice(k,v)
    end
    -- log the roles table from the JWT claims
    for k,v in pairs(roles) do
        kong.log.notice(k,v)
    end
end



  --validate roles against claims for policy type = ANY
  if conf.policy == policy_ANY and not role_in_roles_claim(roles_cfg, roles) then
    return kong.response.exit(403, {
      detail = "The required roles for this invocation are [" .. table.concat(roles_cfg,", ") .. "] and your roles are [" .. table.concat(roles,", ").."]",
      message = msg_error_any

    })
  end

  
  --validate roles against claims for policy type = ALL
  if conf.policy == policy_ALL and not all_roles_in_roles_claim(roles_cfg, roles) then
    return kong.response.exit(403, {
      detail = "The required roles for this invocation are [" .. table.concat(roles_cfg,", ") .. "] and your roles are [" .. table.concat(roles,", ").."]",
      message = msg_error_all
    })
  end


--end of JWTAuthHandler.access function
end

return JWTAuthHandler