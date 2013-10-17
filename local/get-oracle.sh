#!/usr/bin/env bash

# Gets lattice oracles

if [ $# -lt 3 ]; then
    echo "Specify split and decode and data  directory"
    exit 1;
fi

split=$1
textFile=$3/text
trainDir=$2
symTable=$trainDir/graph/words.txt
latticeDir=$trainDir/decode_$split
oracleDir=$latticeDir/oracle

echo $latticeDir
echo $oracleDir

. path.sh

if [ ! -f $textFile -o ! -d $trainDir -o ! -f $symTable -o ! -d $latticeDir ]; then
    echo "Required files not found"
    exit 1;
fi

mkdir -p $oracleDir

cat $textFile | sed 's:\[laughter\]::g' | sed 's:\[noise\]::g' | \
    utils/sym2int.pl -f 2- $symTable | \
    $KALDI_ROOT/src/latbin/lattice-oracle --word-symbol-table=$symTable "ark:gunzip -c $latticeDir/lat.*.gz|" ark:- ark,t:$oracleDir/oracle.tra 2>$oracleDir/oracle.log

sort -k1,1 -u $oracleDir/oracle.tra -o $oracleDir/oracle.tra
