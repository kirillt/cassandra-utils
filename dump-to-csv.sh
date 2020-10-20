#!/bin/bash
dir=`date +%s`
[ -d $dir ] && echo "Snapshot folder already exists" && exit 1

# suppressing redundant verbosity
pushd() { command pushd "$@" > /dev/null; }
popd() { command popd "$@" > /dev/null; }

indent() { sed -u 's/^/    /' "$@"; }

echo "Creating snapshot folder $dir"
mkdir $dir
pushd $_

dump-table() {
    keyspace=$1
    table=$2

    echo "Dumping table ''$table''"

    # sed is necesary here, because variables inside of '' are not expanded
    cmd=$(echo "copy %table% to '%table%.csv'" | sed s/%table%/$table/g)

    cqlsh -k $keyspace -e "$cmd" | indent
    echo
    exit
}

keyspaces=$(cqlsh -e 'describe keyspaces;')
for keyspace in $keyspaces
do
    echo "Dumping keyspace ''$keyspace''"
    mkdir $keyspace
    pushd $_
    tables=$(cqlsh -k $keyspace -e 'describe tables;')
    for table in $tables
    do
        dump-table $keyspace $table | indent
    done
    popd
done
popd
