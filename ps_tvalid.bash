#!/bin/bash

hash mariadb 2>/dev/null || {
    echo >&2 'mariadb client could not be found; please install...'
    exit 1
}

creds_path=$1
if [ "$creds_path" = '' ]
then
    >&2 echo '...please provide $creds_path as $1--first argument'
    exit 1
fi
if ! test -f "$creds_path"
then
    >&2 echo '...please provide $creds_path as a file that actually exists'
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
if [ "$validate_creds_res" != "$validate_creds_ok" ]
then
    >&2 echo "...creds.bash status: $validate_creds_res"
    exit 1
fi

echo "...creds.bash status: $validate_creds_res"

exec_prod_db() {
    mariadb \
        -u "$prod_user" "$prod_db" \
        -p"$prod_pass" \
        -h "$prod_host" \
        -P "$prod_port" \
        -e "$1"
}

# $1: slave_db string from creds.bash
# $2: query
exec_slave_db() {
    slave_user=''
    slave_pass=''
    slave_db=''
    slave_host=''
    slave_port=''

    IFS=' & ' read -ra slave_creds <<< "$1"
    for i in "${!slave_creds[@]}"
    do
        case "$i" in
            '0')
                slave_user=${slave_creds[$i]}
                ;;
            '1')
                slave_pass=${slave_creds[$i]}
                ;;
            '2')
                slave_db=${slave_creds[$i]}
                ;;
            '3')
                slave_host=${slave_creds[$i]}
                ;;
            '4')
                slave_port=${slave_creds[$i]}
                ;;
        esac
    done

    mariadb \
        -u "$slave_user" "$slave_db" \
        -p"$slave_pass" \
        -h "$slave_host" \
        -P "$slave_port" \
        -e "$2"
}

from_date=$2
to_date=$3

out_file=$4

if [ "$from_date" = '' ] || [ "$to_date" = '' ]
then
    >&2 echo '...please pass in $from_date and $to_date as $2 and $3'
    exit 1
fi

# ...Fill this in:
#
table=''
date_col=''

if [ "$out_file" = '' ]
then
    >&2 echo '...please pass in $out_file as $4'
    exit 1
fi

> $out_file

main() {
    count_by_date_query=\
"SELECT
    $date_col,
    COUNT(*)
FROM $table
WHERE $date_col BETWEEN '$from_date' AND '$to_date'
GROUP BY $date_col;"

    prod_res=$(exec_prod_db "$count_by_date_query")

    echo "Production" >> $out_file
    echo "----------" >> $out_file

    echo "$prod_res" >> $out_file
    echo "" >> $out_file

    if [ "$?" = '1' ]
    then
        >&2 echo '...failed to execute prod query'
        return 1
    fi

    for slave_i in "${!slaves[@]}"
    do
        res=$(exec_slave_db "${slaves[$slave_i]}" "$count_by_date_query")

        if [ "$?" = '1' ]
        then
            >&2 echo "...failed to execute query for slave at index '$slave_i'"
            return 1
        fi

        echo "Slave $slave_i" >> $out_file
        echo "-------" >> $out_file

        echo "$res" >> $out_file
        echo "" >> $out_file
    done
}

main
