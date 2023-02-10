# module-kong-plugin-jwt

/* 

# Client generates an RS256 key pair and provides the public key to Lytx
# create private and public keys
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -outform PEM -pubout -out public.pem

# Lytx uses that public key to create a consumer and an RS256 credential in the Kong API Gateway
# create consumer and credential for JWT creation
curl -d "username=acme_supply&custom_id=000003" http://localhost:8001/consumers/
curl -X POST http://localhost:8001/consumers/acme_supply/jwt \
-F "algorithm=RS256" \
-F "rsa_public_key=@/home/ec2-user/public.pem"

# Return credential details just created to retrieve the "key" value
curl -X GET http://localhost:8001/consumers/acme_supply/jwt

# Lytx configures the jwt and jwt-auth-rbac plugins for use by the client
This still needs to be determined how it will be implemented.

# Lytx provides the “key” created during that process to the client to be used as the “iss” value in the claims section of the JTW token 
Client creates a JWT token using the provided “key” value for the “iss” and their private and public keys with RS256 for the algorithm and includes it as “Bearer” in the “Authorization” header. The payload also needs to contain the company ID, root group ID and their appropriate roles as configured for RBAC access:

# Header:
{
  "alg": "RS256",
  "typ": "JWT",
  "iss": "G0Yl92ix7l0sFn0taLkEo1Z4BVhiaiIy"
}

# Payload (data)
{
  "name": "Acme Supply",
  "exp": 1999999999,
  "roles" : "read",
  "co_id" : "99999",
  "rootgroupid" : "99999999-0000-0000-0000-000000000000"
}

# The Kong API Gateway decrypts the JWT token and validates it against the client’s public key and the “iss” value in the token. It also checks the claims payload for roles
# and compares the roles against the jwt-auth-rbac plugin configuration.
# As long as all of the required elements are present in the JWT token, the Kong API Gateway allows the request and forwards it to the upstream service for processing.


Notes: The client’s Private Key is NEVER provided to Lytx.












*/
