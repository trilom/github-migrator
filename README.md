# github-migrator

```bash
# create a buildx builder
docker buildx create --use --name builder --driver docker-container --buildkitd-flags '--allow-insecure-entitlement security.insecure'
# create a ssh agent connection your builder can use
eval $(ssh-agent)
# add the target github enterprise key to ssh/scp payload
ssh-add ~/.ssh/id_rsa

# if you need to kill the builder
docker buildx builder rm
```

## export

> Just need to provide the source token (`SOURCE_TOKEN`) and organization(`ORGANIZATION`) as env vars.

- Inputs:
  - If the local **out** directory contains a file named _`ORGANIZATION`.tar.gz_ then this is moved inside the container _instead_ of pulling freshly from github cloud.
- Outputs:
  - Expect the `ORGANIZATION` to have been exported to _`ORGANIZATION`.tar.gz_ within the container.

```bash
SOURCE_TOKEN=ghp_tokenabc123 \
ORGANIZATION=trailmix \
  docker buildx bake export
```

## import

> Just need to provide the target token (`TARGET_TOKEN`), target user (`TARGET_USER`), target hostname (`TARGET_HOSTNAME`) and organization(`ORGANIZATION`) as env vars.

- Inputs:
  - If the local **conflicts** directory contains a file named _`ORGANIZATION`-conflicts.csv_ then this is moved inside the container _instead_ of checking the mappings. [(This is useful if you tried to import and a failure occured and you need to manually edit the mappings.)](https://docs.github.com/en/enterprise-server@3.7/admin/user-management/migrating-data-to-and-from-your-enterprise/preparing-to-migrate-data-to-your-enterprise#adding-custom-mappings)
- Deps:
  - Run [export](#export).
- Outputs:
  - Expect the _`ORGANIZATION`.tar.gz_ to move to `TARGET_HOSTNAME` with the `SSH_AUTH_SOCK` provided over `TARGET_SSH_PORT` with `TARGET_SSH_USER`.

```bash
TARGET_TOKEN=ghp_ENTtokenabc123 \
TARGET_USER=trilom-trailmix \
TARGET_HOSTNAME="github.vms.mud.name" \
ORGANIZATION=trailmix \
  docker buildx bake import
```

## output

> Just need to provide the source token (`SOURCE_TOKEN`), target token (`TARGET_TOKEN`), target user (`TARGET_USER`), target hostname (`TARGET_HOSTNAME`) and organization(`ORGANIZATION`)

- Deps:
  - Run [export](#export) and [import](#import).
- Outputs:
  - Expect the local **out** directory to contain the _`ORGANIZATION`.tar.gz_ file and _`ORGANIZATION`-conflicts.csv_ file.
- Exceptions:
  - If there are conflicts and there was a failure, you can provide a file to override the derived conflicts file in the **conflicts/** directory as _`ORGANIZATION`-conflicts.csv_.

```bash
SOURCE_TOKEN=ghp_tokenabc123 \
TARGET_HOSTNAME="github.vms.mud.name" \
TARGET_USER=trilom-trailmix \
TARGET_TOKEN=ghp_ENTtokenabc123 \
ORGANIZATION=trailmix \
  docker buildx bake
```

### cleanups

```bash
## list all repos in all migrations for an org
curl -H "Authorization: Bearer ghp_tokenabc123" -H "Accept: application/vnd.github+json" https://api.github.com/orgs/trailmix/migrations | jq -e '[.[].repositories[].name]' > repo-names.json
curl -H "Authorization: Bearer ghp_tokenabc123" -H "Accept: application/vnd.github+json" https://api.github.com/orgs/trailmix/migrations | jq -e '[.[].id]' > ids.json

# after two files exist, make a bunch of commands to unlock
echo 'jsonencode([for k,v in setproduct(jsondecode(file("ids.json")),jsondecode(file("repo-names.json"))): format("curl -H \"Authorization: Bearer ghp_tokenabc123\" -X DELETE -H \"Accept: application/vnd.github+json\" https://api.github.com/orgs/trailmix/migrations/%s/repos/%s/lock",v[0],v[1])])' | packer console -config-type=hcl2 | jq -r -e '.[]'
```
