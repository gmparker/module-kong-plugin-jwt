-- Updated handler.lua file for Kong 3.x.x

--Commented out
--local BasePlugin = require "kong.plugins.base_plugin"
--local responses = require "kong.tools.responses"
local constants = require "kong.constants"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"
local responses = kong.response

local ngx_error = ngx.ERR
local ngx_debug = ngx.DEBUG
local ngx_log = ngx.log

--variables to determine which policy to apply
local policy_ALL = 'all'
local policy_ANY = 'any'

-- New code added
local JWTAuthHandler = {
  VERSION  = "0.1.0",
  PRIORITY = 950,
}


--Commented out
--local JWTAuthHandler = BasePlugin:extend()

--Commented out
--JWTAuthHandler.PRIORITY = 950
--JWTAuthHandler.VERSION = "0.1.0"

--Commented out
--function JWTAuthHandler:new()
  --JWTAuthHandler.super.new(self, "jwt-auth")
--end

--- Filter a table
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

--- Get index of a value at a table.
-- @param any value
-- @return any
function table:find(value)
  for k, v in ipairs(self) do
      if v == value then
          return k
      end
  end
end


--- checks wheter all given roles are also present in the claimed roles
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


--- checks whether a claimed role is part of a given list of roles.
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

--- split a string into substrings by reparator
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


function JWTAuthHandler:access(conf)

  local myvdebug = conf.vdebug

  if myvdebug then
      kong.log.notice("Now processing the access hander")
  end
  --Commented out
--JWTAuthHandler.super.access(self)

  -- get the JWT from the Nginx context
  -- Commented out and replaced with updated version
  --local token = ngx.ctx.authenticated_jwt_token
  local token = kong.ctx.shared.authenticated_jwt_token

  if not token then
    ngx_log(ngx_error, "[jwt-auth plugin] Cannot get JWT token, add the ",
                       "JWT plugin to be able to use the JWT-Auth plugin")
                       return kong.response.exit(403, {
                        message = "You cannot consume this service"
                      })
    --return responses.send_HTTP_FORBIDDEN("You cannot consume this service")
  end

  -- decode token to get roles claim
  local jwt, err = jwt_decoder:new(token)
  if err then
    -- return false, {status = 401, message = "Bad token; " .. tostring(err)}
    return kong.response.exit(401, { message = "Bad token; " .. tostring(err)})
  end
  

  --Variables from the plugin
  local msg_error_all = conf.msg_error_all
  local msg_error_any = conf.msg_error_any
  local msg_error_not_roles_claimed = conf.msg_error_not_roles_claimed
  local roles_cfg = conf.roles
  local myco_id = conf.co_id
  local myrootgroupid = conf.rootgroupid

  if myvdebug then
    kong.log.notice("Config error message ALL: ", conf.msg_error_all)
    kong.log.notice("Config error message ANY: ", conf.msg_error_any)
    kong.log.notice("Config error message RNC: ", conf.msg_error_not_roles_claimed)
  end

  --variables from the decoded JWT
  local claims = jwt.claims
  local roles = claims[conf.roles_claim_name]
  local thisrootgroupud = claims['rootgroupid']
  local thisco_id = claims['co_id']
  --empty table variable
  local roles_table = {}

if myvdebug then
  kong.log.notice("co_id: ", myco_id)    
  kong.log.notice("rootgroupid: ", myrootgroupid)
  kong.log.notice("thisco_id: ", thisco_id)
  kong.log.notice("thisrootgroupud: ", thisrootgroupud)
end

if myco_id ~= thisco_id then
  return kong.response.exit(403, { message = "Invalid Company ID"})
end

if myrootgroupid ~= thisrootgroupud then
  return kong.response.exit(403, { message = "Invalid Root Group ID"})
end


if myvdebug then
  kong.log.notice("JWT Claims: ", claims)
  kong.log.notice("roles: ", roles)
  kong.log.notice("roles claim name: ", conf.roles_claim_name)
end

  --check if no roles claimed..
  if not roles then
    --return responses.send_HTTP_FORBIDDEN("You cannot consume this service")
    return kong.response.exit(403, {
      -- message = "You cannot consume this service"
      message = msg_error_not_roles_claimed
    })
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
    --return responses.send_HTTP_FORBIDDEN("You cannot consume this service")
    return kong.response.exit(403, {
      -- message = "You can't use these service"
      detail = "The required roles for this invocation are [" .. table.concat(roles_cfg,", ") .. "] and your roles are [" .. table.concat(roles,", ").."]",
      message = msg_error_any

    })
  end

  
  --validate roles against claims for policy type = ALL
  if conf.policy == policy_ALL and not all_roles_in_roles_claim(roles_cfg, roles) then
    --return responses.send_HTTP_FORBIDDEN("You cannot consume this service")
    return kong.response.exit(403, {
      -- message = "You can't use these service"
      detail = "The required roles for this invocation are [" .. table.concat(roles_cfg,", ") .. "] and your roles are [" .. table.concat(roles,", ").."]",
      message = msg_error_all
    })
  end


--end of JWTAuthHandler.access function
end

return JWTAuthHandler