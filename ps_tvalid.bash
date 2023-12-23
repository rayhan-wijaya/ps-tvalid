#!/bin/bash

hash mariadb 2>/dev/null || {
    echo >&2 'mariadb client could not be found; please install...'
    exit 1
}

creds_path=$1
if [ "$creds_path" = '' ]
then
    echo '...please provide $creds_path as $1--first argument'
    exit 1
fi
if ! test -f "$creds_path"
then
    echo '...please provide $creds_path as a file that actually exists'
    exit 1
fi

. "$creds_path"

validate_creds_ok='ok!'
validate_creds() {
    if [ "$prod_user" = '' ]; then echo '`prod_user` is not defined'; return; fi
    if [ "$prod_pass" = '' ]; then echo '`prod_pass` is not defined'; return; fi
    if [ "$prod_db"   = '' ]; then echo '`prod_db` is not defined';   return; fi
    if [ "$prod_host" = '' ]; then echo '`prod_host` is not defined'; return; fi
    if [ "$prod_port" = '' ]; then echo '`prod_port` is not defined'; return; fi

    # TODO: *efficiently* check the slave string as well
    #
    if [ "$slaves"       = ''  ]; then echo '`slaves` is not defined'; return; fi
    if [ "${#slaves[@]}" = '0' ]; then echo '`slaves` array is empty'; return; fi

    echo "$validate_creds_ok"
}

validate_creds_res="$(validate_creds)"
echo "...creds.bash status: $validate_creds_res"
if [ "$validate_creds_res" != "$validate_creds_ok" ]
then
    exit 1
fi

exec_prod_db() {
    mariadb
        -u $prod_user
        -p"$prod_pass"
        -d $prod_db
        -h $prod_host
        -P $prod_password
        -e "$1"
}
