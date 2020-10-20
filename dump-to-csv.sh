#!/bin/bash
dir=`date +%s`
[ -d $dir ] && echo "Snapshot folder already exists" && exit 1

# suppressing redundant verbosity
pushd() { command pushd "$@" > /dev/null; }
popd() { command popd "$@" > /dev/null; }

echo "Creating snapshot folder $dir"
mkdir $dir
pushd $_
echo

indent() { sed -u 's/^/    /' "$@"; }

start=$SECONDS

elapsed() {
    echo "Total seconds elapsed: $(($SECONDS - $start))"
    echo
}

dump-table() {
    keyspace=$1
    table=$2

    echo "Dumping table ''$keyspace.$table''"

    # sed is necesary here, because variables inside of '' are not expanded
    cmd=$(echo "copy %table% to '%table%.csv'" | sed s/%table%/$table/g)

    cqlsh -k $keyspace -e "$cmd" | indent
    elapsed
}

dump-all() {
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
}

log="output.log"

dump-all 2>&1 | tee $log

if [[ "$*" == *"--ordered"* ]]
then
    echo "Sorting all exported files"
    results=$(find -iname '*.csv')
    for result in $results
    do
        buffer=$(mktemp)
        sort $result > $buffer
        mv $buffer $result
    done

    elapsed
fi

popd

echo "Log with all errors:"
echo "$dir/$log" | indent

echo "Snapshot folder:"
du -sh $dir | indent
