#!/bin/bash

hash mariadb 2>/dev/null || {
    echo >&2 'mariadb client could not be found; please install...'
    exit 1
}
