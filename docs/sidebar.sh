#!/bin/bash
IFS=$(echo -en "\n\b")
function getdir(){
    for element in `ls -1 $1`
    do
        dir_or_file=$1"/"$element
        counter=`echo $dir_or_file | grep -o / | wc -l`
        let counter-=2
        if [ -d $dir_or_file ] ;
        then

            printf '%0.s  ' $(seq 0 $counter) >> _sidebar.md
            echo "- $element" >> _sidebar.md
            getdir $dir_or_file
        else
            echo $dir_or_file
            printf '%0.s  ' $(seq 0 $counter) >> _sidebar.md
            path=`echo $dir_or_file| sed "s/[ ]/%20/g" | sed "s/[+]/%2B/g"`
            title=`echo $element | sed "s/.md//"`
            echo "- [$title](./$path)" >> _sidebar.md
        fi
    done
}

root_dir=`ls -d */`
#root_dir=`ls -d */ "$1/VulWiki" | sed 's/\///g'`
:> _sidebar.md
for dir in $root_dir
do
    if [ "$dir" = "." ]
    then
        continue
    else
        C1=`echo $dir | cut -f2 -d '/'`
        echo "- $C1" | cut -f2 -d '/' >> _sidebar.md
        getdir `echo $dir | sed s'/.$//'`
    fi
done
