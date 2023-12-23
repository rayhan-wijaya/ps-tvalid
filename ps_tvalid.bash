#!/bin/bash

hash mariadb 2>/dev/null || {
    echo >&2 'mariadb client could not be found; please install...'
    exit 1
}

creds_path=$1
. "$creds_path"

validate_creds_ok='ok!'
validate_creds() {
    if [ "prod_user" = '' ]; then; return '`prod_user` is not defined'; fi
    if [ "prod_pass" = '' ]; then; return '`prod_pass` is not defined'; fi
    if [ "prod_db" = '' ]; then; return '`prod_db` is not defined'; fi
    if [ "prod_host" = '' ]; then; return '`prod_host` is not defined'; fi
    if [ "prod_port" = '' ]; then; return '`prod_port` is not defined'; fi

    # TODO: *efficiently* check the slave string as well
    #
    if [ "slaves" = '' ]; then; return '`slaves` is not defined'; fi
    if [ "${#slaves[@]}" = '0' ] then; return '`slaves` array is empty'; fi

    return "$validate_creds_ok"
}

validate_creds_res="$(validate_creds)"
if [ "$validate_creds_res" != "$validate_creds_ok" ]
then
    echo "...creds.bash status: "
fi
