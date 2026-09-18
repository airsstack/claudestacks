#!/bin/sh
# Parses every hook script without running it.
status=0
for script in hooks/*.sh; do
  if sh -n "$script"; then
    echo "ok    $script"
  else
    status=1
  fi
done
exit $status
