#!/bin/sh
# Greets whoever GREETING_NAME names.
printf 'hello, %s\n' "${GREETING_NAME:?GREETING_NAME is required}"
