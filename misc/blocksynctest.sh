#!/bin/bash

# Maybe these tests should be rewritten in Perl and placed in t/


SRC=$(tempfile)
DST=$(tempfile)
OUT=$(tempfile)
EXIT=0

function grepout {
    GOT=$(grep "<$1>" $OUT | wc -l)
    if [ $GOT -eq $2 ]
    then
	echo -e "\e[32mOK\e[39m   $1 $2/$GOT"
    else
	echo -e "\e[31mFAIL\e[39m $1 $2/$GOT"
	EXIT=1
    fi
}


function cmpsrcdst {
    blocksync -S -s $SRC -d $DST -v $6 > $OUT
    #cat $OUT
    if [ $(md5sum $SRC $DST | awk '{print $1}' | uniq | wc -l) -eq $1 ]
    then
	echo -e "\e[32mOK\e[39m   checksum"
    else
	echo -e "\e[31mFAIL\e[39m checksum"
	EXIT=1
    fi
    grepout sparse    $2
    grepout new       $3
    grepout changed   $4
    grepout unchanged $5
}


(
    dd if=/dev/zero     bs=1M   count=1 2> /dev/null
    dd if=/dev/urandom  bs=1M   count=1 2> /dev/null
) | dd of=$SRC 2> /dev/null
echo overwrite/trunc - 1 MB zero, 1 MB rand
cmpsrcdst 1 1 1 0 0


(
    dd if=/dev/zero     bs=1M   count=1 2> /dev/null
    dd if=/dev/urandom  bs=1M   count=1 2> /dev/null
    dd if=/dev/zero     bs=1M   count=1 2> /dev/null
    dd if=/dev/urandom  bs=1M   count=1 2> /dev/null
) | dd of=$SRC 2> /dev/null
echo overwrite/trunc - 1 MB zero, 1 MB rand, 1 MB zero, 1 MB rand
cmpsrcdst 1 1 1 1 1


(
    dd if=/dev/urandom  bs=1M   count=10 2> /dev/null
    dd if=/dev/zero     bs=1M   count=10 2> /dev/null
    dd if=/dev/urandom  bs=512K count=19 2> /dev/null
) | dd of=$SRC 2> /dev/null
echo overwrite/trunc - 10 MB rand, 10 MB zero, 9,5 MB rand
cmpsrcdst 1 10 16 4 0
echo nothing changed
cmpsrcdst 1 0 0 0 30


(
    dd if=/dev/zero     bs=1M   count=6 2> /dev/null
    dd if=/dev/urandom  bs=1M   count=6 2> /dev/null
) | dd of=$SRC conv=notrunc 2> /dev/null
echo overwrite/notrunc - 6 MB zero, 6 MB rand
cmpsrcdst 1 0 0 12 18


(
    dd if=/dev/zero     bs=1M   count=6  2> /dev/null
    yes | dd iflag=fullblock bs=512K count=11 2> /dev/null
) | dd of=$SRC 2> /dev/null
echo overwrite/trunc src - 6 MB zero, 5,5 MB y\\n
cmpsrcdst 2 0 0 6 6
echo nothing changed/trunc dst
cmpsrcdst 1 0 0 0 12 -t


truncate -s 6291456 $SRC
echo truncate src+dst - 6 MB
cmpsrcdst 1 0 0 0 6 -t


(
    dd if=/dev/zero     bs=1M   count=6  2> /dev/null
    yes | dd  iflag=fullblock bs=512K count=11 2> /dev/null
) | dd of=$SRC 2> /dev/null
echo overwrite/trunc src - 6 MB zero, 5,5 MB y\\n
cmpsrcdst 1 0 6 0 6

(
    dd if=/dev/zero     bs=1M   count=6  2> /dev/null
    yes | dd iflag=fullblock bs=1M   count=6 2> /dev/null
    dd if=/dev/zero     bs=1M   count=20 2> /dev/null
) | dd of=$SRC 2> /dev/null
echo overwrite/trunc src - 6 MB zero, 6 MB y\\n, 20 MB zero
cmpsrcdst 1 20 0 1 11


(
    dd if=/dev/zero     bs=512K count=1 2> /dev/null
) >> $SRC
echo append - 0,5 MB zero - not full block - will not be sparse
cmpsrcdst 1 0 1 0 32


rm -f $SRC* $DST* $OUT*

exit $EXIT
