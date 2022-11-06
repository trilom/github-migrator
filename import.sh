#!/bin/bash
set -x
UUID="$(uuid)"
prepare () {
  if ghe-migrator prepare /home/admin/$ORGANIZATION.tar.gz -g $UUID; then
    echo 'prepare complete'
  else
    echo 'prepare failure'
    exit 1
  fi
}
conflicts () {
  if test -f $ORGANIZATION-conflicts.csv; then
    echo 'conflicts exists already'
  else
    if ghe-migrator conflicts -g $UUID > $ORGANIZATION-conflicts.csv; then
      echo 'conflicts complete'
    else
      echo 'conflicts failure'
      exit 1
    fi
  fi
  cat $ORGANIZATION-conflicts.csv;
}
map () {
  if ghe-migrator map -i $ORGANIZATION-conflicts.csv -g $UUID; then
    echo 'map complete'
  else
    echo 'map failure'
    exit 1
  fi
}
import () {
  if ghe-migrator import /home/admin/$ORGANIZATION.tar.gz -g $UUID -u $TARGET_USER -p $TARGET_TOKEN; then
    echo 'import complete'
  else
    echo 'import failure'
    exit 1
  fi
}
prepare \
&& conflicts \
&& map \
&& import \

# ghe-migrator audit -g $UUID;
&& ghe-migrator unlock -g $UUID;