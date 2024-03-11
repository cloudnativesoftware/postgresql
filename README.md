# postgresql
PostgresSQL image with additional extensions that is derived from cloudnative-pg.io image for running with the same.

Drew inspiration from build of supabase container images for postgresql. Many of the extensions are also authored by supabase.

# How to build
1. Clone this repository
2. Build with docker e.g. ```docker build -t ghcr.io/cloudnativesoftware/postgresql:15.6 .```
3. docker push ghcr.io/cloudnativesoftware/postgresql:15.6 .