#!/bin/bash
set -x
ACCEPT_HEADER="-H 'Accept: application/vnd.github+json'"
TYPE=${SOURCE_TYPE:=organization}
LOCK=${SOURCE_LOCK:=false}
# list all repos
if [ "$TYPE" == "organization" ]; then
  rREPOS=$(curl -s $ACCEPT_HEADER -H "Authorization: Bearer $SOURCE_TOKEN" https://api.github.com/orgs/$ORGANIZATION/repos?per_page=100)
else
  rREPOS=$(curl -s $ACCEPT_HEADER -H "Authorization: Bearer $SOURCE_TOKEN" https://api.github.com/user/repos?per_page=100\&affiliation=owner)
fi

REPOS=$(echo $rREPOS | jq -r '[.[].full_name'])

# start a migration from target
if [ "$TYPE" == "organization" ]; then
  rID=$(curl -s -X POST \
    $ACCEPT_HEADER \
    -H "Authorization: Bearer $SOURCE_TOKEN" \
    -d'{"lock_repositories":'$LOCK', "repositories":'"$REPOS"'}' \
    https://api.github.com/orgs/$ORGANIZATION/migrations)
else
  rID=$(curl -s -X POST \
    $ACCEPT_HEADER \
    -H "Authorization: Bearer $SOURCE_TOKEN" \
    -d'{"lock_repositories":'$LOCK', "repositories":'"$REPOS"'}' \
    https://api.github.com/user/migrations)
fi
ID=$(echo $rID | jq -r '.id')

# check migration status until exported
check_migration () {
  if [ "$TYPE" == "organization" ]; then
    r=$(curl -s \
    $ACCEPT_HEADER \
    -H "Authorization: Bearer $SOURCE_TOKEN" \
    https://api.github.com/orgs/$ORGANIZATION/migrations/$ID)
  else
    r=$(curl -s \
    $ACCEPT_HEADER \
    -H "Authorization: Bearer $SOURCE_TOKEN" \
    https://api.github.com/user/migrations/$ID)
  fi
  echo $r | jq -r '. | select(.state=="exported") | .guid'
}

GUID=
while [[ "$GUID" == "" ]]; do
  GUID=$(check_migration);
  sleep 5;
  echo 'Waiting on migration...'
done

if [ "$TYPE" == "organization" ]; then
  DOWNLOAD=$(curl -s \
    -H 'Accept: application/vnd.github+json' \
    -H "Authorization: Bearer $SOURCE_TOKEN" \
    -L -o $ORGANIZATION.tar.gz --write-out '%{http_code}' \
    https://api.github.com/orgs/$ORGANIZATION/migrations/$ID/archive)
else
  DOWNLOAD=$(curl -s \
    -H 'Accept: application/vnd.github+json' \
    -H "Authorization: Bearer $SOURCE_TOKEN" \
    -L -o $ORGANIZATION.tar.gz --write-out '%{http_code}' \
    https://api.github.com/user/migrations/$ID/archive)
fi
echo $DOWNLOAD