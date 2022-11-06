# syntax=docker/dockerfile:1.4-labs
FROM --platform=$BUILDPLATFORM alpine AS export
RUN apk add bash curl jq
WORKDIR /app
ARG ORGANIZATION SOURCE_TOKEN SOURCE_TYPE
# if a file exists on the builder at out/$ORGANIZATION.tar.gz 
# then it will import that instead of getting a new one
COPY --link ./ .
RUN test -f out/$ORGANIZATION.tar.gz && cp out/$ORGANIZATION.tar.gz . || ./export.sh

FROM --platform=$BUILDPLATFORM alpine as import
RUN apk add openssh-client
WORKDIR /app
ARG ORGANIZATION TARGET_HOSTNAME TARGET_SSH_PORT TARGET_SSH_USER TARGET_TOKEN TARGET_USER 
# ssh-keyscan on port 122 to use ssh to github host
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan -p ${TARGET_SSH_PORT} ${TARGET_HOSTNAME} >> /root/.ssh/known_hosts
# move conflicts if exists to github host
COPY --link ./conflicts/ .
RUN --mount=type=ssh test -f $ORGANIZATION-conflicts.csv && scp -P ${TARGET_SSH_PORT} ${ORGANIZATION}-conflicts.csv ${TARGET_SSH_USER}@${TARGET_HOSTNAME}:/home/admin/. || exit 0
# move organization output to github host
COPY --from=export /app/${ORGANIZATION}.tar.gz /app/${ORGANIZATION}.tar.gz
RUN --mount=type=ssh \
  echo "Moving ${ORGANIZATION}.tar.gz to ${TARGET_SSH_USER}@${TARGET_HOSTNAME}:/home/admin/..." \
  && scp -P ${TARGET_SSH_PORT} ${ORGANIZATION}.tar.gz ${TARGET_SSH_USER}@${TARGET_HOSTNAME}:/home/admin/.
# create "import.sh" script and run it on github host, if failure move conflicts file
COPY --link ./import.sh .
RUN --mount=type=ssh \
  ssh -p ${TARGET_SSH_PORT} ${TARGET_SSH_USER}@${TARGET_HOSTNAME} TARGET_TOKEN=${TARGET_TOKEN} TARGET_USER=${TARGET_USER} ORGANIZATION=${ORGANIZATION} 'bash -s' < import.sh || \
  scp -P ${TARGET_SSH_PORT} ${TARGET_SSH_USER}@${TARGET_HOSTNAME}:/home/admin/${ORGANIZATION}-conflicts.csv conflicts.csv

# move conflicts to docker host for output
RUN --mount=type=ssh scp -P ${TARGET_SSH_PORT} ${TARGET_SSH_USER}@${TARGET_HOSTNAME}:/home/admin/${ORGANIZATION}-conflicts.csv conflicts.csv

FROM --platform=$BUILDPLATFORM scratch as output
ARG ORGANIZATION
COPY --link --from=export /app/${ORGANIZATION}.tar.gz /${ORGANIZATION}.tar.gz
COPY --link --from=import /app/conflicts.csv /${ORGANIZATION}-conflicts.csv