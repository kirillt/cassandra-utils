#!/bin/bash

indent() { sed -u 's/^/    /' "$@"; }

common-prefix() {
    echo -e "$1\n$2" | grep -zoP '^(.*)(?=.*?\n\1)'
}

intersect() {
    awk 'NR==FNR { lines[$0]=1; next } $0 in lines' $1 $2 | uniq
}

difference() {
    buffer=$(mktemp)
    for entry in $(cat $2)
    do
        ! grep -q "^$entry$" $3 && echo $entry >> $buffer
    done

    [ -s $buffer ] && echo "Unique entries in $1:" && (cat $buffer | indent)
    rm $buffer
}

common=$(mktemp)
report() {
    set1=$3
    set2=$4
    template=$5

    if diff -q $set1 $set2 &> /dev/null
    then
        echo "Dumps contain the same $template"
        cat $set1 > $common
    else
        echo "Dumps contain different $template"
        intersect $set1 $set2 > $common

        #echo "common entries:"      | indent
        #cat $common                 | indent | indent

        difference $1 $set1 $common | indent
        difference $2 $set2 $common | indent
        echo
    fi
}

parent=$(common-prefix $1 $2 | tr -d '\0')
dump1=${1#"$parent"}
dump2=${2#"$parent"}

echo "Analyzing dumps <<$dump1>> and <<$dump2>> with their common prefix $parent"

keyspaces1=$(mktemp)
keyspaces2=$(mktemp)
ls -1 "$1" | grep -v '.*\..*' > $keyspaces1
ls -1 "$2" | grep -v '.*\..*' > $keyspaces2
report $1 $2 $keyspaces1 $keyspaces2 "keyspaces"
echo
rm $keyspaces1
rm $keyspaces2

keyspaces=$(mktemp)
mv $common $keyspaces

rm -rf out
mkdir out
tables1=$(mktemp)
tables2=$(mktemp)
for keyspace in $(cat $keyspaces)
do
    echo "Keyspace $keyspace"
    ls -1 "$1/$keyspace" | sed s/\.csv//g > $tables1
    ls -1 "$2/$keyspace" | sed s/\.csv//g > $tables2
    report $1 $2 $tables1 $tables2 "tables" | indent

    tables=$(mktemp)
    mv $common $tables

    for table in $(cat $tables)
    do
        if ! diff -q $1/$keyspace/$table.csv $2/$keyspace/$table.csv &> /dev/null
        then
            echo "Dumps have different versions of <<$table>>" | indent | indent
            mkdir -p out/{$dump1,$dump2}/$keyspace
            cp $1/$keyspace/$table.csv out/$dump1/$keyspace/$table.csv
            cp $2/$keyspace/$table.csv out/$dump2/$keyspace/$table.csv
        fi
    done
done
rm $tables1
rm $tables2
echo

[ ! "$(ls -A out)" ] && echo "No differening tables found" && rm -rf out
