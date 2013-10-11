#!/bin/bash
#
# Copyright 2010-2012 Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey).  Apache 2.0.
# The input is the Fisher Dataset which contains DISC1 and DISC2. (*.sph files) 
# In addition the transcripts are needed as well. 

#TODO: Rewrite intro, copyright stuff and dir information
# To be run from one directory above this script.

# The input is the 3 CDs from the LDC distribution of Resource Management.
# The script's argument is a directory which has three subdirectories:
# rm1_audio1  rm1_audio2  rm2_audio

# Note: when creating your own data preparation scripts, it's a good idea
# to make sure that the speaker id (if present) is a prefix of the utterance
# id, that the output scp file is sorted on utterance id, and that the 
# transcription file is exactly the same length as the scp file and is also
# sorted on utterance id (missing transcriptions should be removed from the
# scp file using e.g. scripts/filter_scp.pl)

stage=0

export LC_ALL=C


if [ $# -lt 2 ]; then
   echo "Arguments should be the location of the Callhome Spanish Speech and Transcript Directories, se
e ../run.sh for example."
   exit 1;
fi

cdir=`pwd`
dir=`pwd`/data/local/data
local=`pwd`/local
utils=`pwd`/utils
tmpdir=`pwd`/data/local/tmp

. ./path.sh || exit 1; # Needed for KALDI_ROOT
export PATH=$PATH:$KALDI_ROOT/tools/irstlm/bin
sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
if [ ! -x $sph2pipe ]; then
   echo "Could not find (or execute) the sph2pipe program at $sph2pipe";
   exit 1;
fi
cd $dir

# Make directory of links to the WSJ disks such as 11-13.1.  This relies on the command
# line arguments being absolute pathnames.
rm -r links/ 2>/dev/null
mkdir links/
ln -s $* links

# Basic spot checks to see if we got the data that we needed
if [ ! -d links/LDC96S35 -o ! -d links/LDC96T17 ];
then
        echo "The speech and the data directories need to be named LDC96S35 and LDC96T17 respecti
vely"
        exit 1;
fi

if [ ! -d links/LDC96S35/CALLHOME/SPANISH/SPEECH/DEVTEST -o ! -d links/LDC96S35/CALLHOME/SPANISH/SPEECH/EVLTEST -o ! -d links/LDC96S35/CALLHOME/SPANISH/SPEECH/TRAIN ];
then
        echo "Dev, Eval or Train directories missing or not properly organised within the speech data dir"
        exit 1;
fi

#Check the transcripts directories as well to see if they exist
if [ ! -d links/LDC96T17/callhome_spanish_trans_970711/transcrp/devtest -o ! -d links/LDC96T17/callhome_spanish_trans_970711/transcrp/evltest -o ! -d links/LDC96T17/callhome_spanish_trans_970711/transcrp/train ]
then
        echo "Transcript directories missing or not properly organised"
        exit 1;
fi

speech_train=$dir/links/LDC96S35/CALLHOME/SPANISH/SPEECH/TRAIN
speech_dev=$dir/links/LDC96S35/CALLHOME/SPANISH/SPEECH/DEVTEST
speech_test=$dir/links/LDC96S35/CALLHOME/SPANISH/SPEECH/EVLTEST
transcripts_train=$dir/links/LDC96T17/callhome_spanish_trans_970711/transcrp/train 
transcripts_dev=$dir/links/LDC96T17/callhome_spanish_trans_970711/transcrp/devtest 
transcripts_test=$dir/links/LDC96T17/callhome_spanish_trans_970711/transcrp/evltest 
                                                                                   
fcount_train=`find ${speech_train} -iname '*.SPH' | wc -l` 
fcount_dev=`find ${speech_dev} -iname '*.SPH' | wc -l`                                             
fcount_test=`find ${speech_test} -iname '*.SPH' | wc -l`                                             
fcount_t_train=`find ${transcripts_train} -iname '*.txt' | wc -l` 
fcount_t_dev=`find ${transcripts_dev} -iname '*.txt' | wc -l` 
fcount_t_test=`find ${transcripts_test} -iname '*.txt' | wc -l` 

#Now check if we got all the files that we needed
if [ $fcount_train != 80 -o $fcount_dev != 20 -o $fcount_test != 20 -o $fcount_t_train != 80 -o $fcount_t_dev != 20 -o $fcount_t_test != 20 ];                 
then                                                                               
        echo "Incorrect number of files in the data directories"                   
        echo "The paritions should contain 80/20/20 files"
        exit 1;                                                                    
fi   

if [ $stage -le 0 ]; then
	#Gather all the speech files together to create a file list
	(
	    find $speech_train -iname '*.sph';
	    find $speech_dev -iname '*.sph';
	    find $speech_test -iname '*.sph';
	)  > $tmpdir/callhome_train_sph.flist

	#Get all the transcripts in one place

	(                                                                              
    find $transcripts_train -iname '*.txt';
    find $transcripts_dev -iname '*.txt';
    find $transcripts_test -iname '*.txt';
    )  > $tmpdir/callhome_train_transcripts.flist 

fi

if [ $stage -le 1 ]; then
	$local/callhome_make_trans.pl $tmpdir
	mkdir -p $dir/callhome_train_all
	mv $tmpdir/callhome_reco2file_and_channel $dir/callhome_train_all/
fi

if [ $stage -le 2 ]; then                                                        
  sort $tmpdir/callhome.text.1 | grep -v '((' | \
  awk '{if (NF > 1){ print; }}' | \
  sed 's:<\s*[/]*\s*\s*for[ei][ei]g[nh]\s*\w*>::g' | \
  sed 's:<lname>\([^<]*\)<\/lname>:\1:g' | \
  sed 's:<lname[\/]*>::g' | \
  sed 's:<laugh>[^<]*<\/laugh>:[laughter]:g' | \
  sed 's:<\s*cough[\/]*>:[noise]:g' | \
  sed 's:<sneeze[\/]*>:[noise]:g' | \
  sed 's:<breath[\/]*>:[noise]:g' | \
  sed 's:<lipsmack[\/]*>:[noise]:g' | \
  sed 's:<background>[^<]*<\/background>:[noise]:g' | \
  sed -r 's:<[/]?background[/]?>:[noise]:g' | \
  #One more time to take care of nested stuff
  sed 's:<laugh>[^<]*<\/laugh>:[laughter]:g' | \
  sed -r 's:<[/]?laugh[/]?>:[laughter]:g' | \
  #now handle the exceptions, find a cleaner way to do this?
  sed 's:<foreign langenglish::g' | \
  sed 's:</foreign::g' | \
  sed -r 's:<[/]?foreing\s*\w*>::g' | \
  sed 's:</b::g' | \
  sed 's:<foreign langengullís>::g' | \
  sed 's:foreign>::g' | \
  sed 's:>::g' | \
  #How do you handle numbers?
  grep -v '()' | \
  #Now go after the non-printable characters
  sed -r 's:¿::g' > $tmpdir/callhome.text.2

  CHARS=$(python -c 'print u"\u00BF\u00A1".encode("utf8")')
  sed -i 's/['"$CHARS"']//g' $tmpdir/callhome.text.2

  cp $tmpdir/callhome.text.2 $dir/callhome_train_all/callhome.text


  #Create segments file and utt2spk file
  ! cat $dir/callhome_train_all/callhome.text | perl -ane 'm:([^-]+)-([AB])-(\S+): || die "Bad line $_;"; print "$1-$2-$3 $1-$2\n"; ' > $dir/callhome_train_all/callhome_utt2spk \
  && echo "Error producing utt2spk file" && exit 1;

  cat $dir/callhome_train_all/callhome.text | perl -ane 'm:((\S+-[AB])-(\d+)-(\d+))\s: || die; $utt = $1; $reco = $2;
 $s = sprintf("%.2f", 0.01*$3); $e = sprintf("%.2f", 0.01*$4); print "$utt $reco $s $e\n"; ' >$dir/callhome_train_all/callhome_segments

  $utils/utt2spk_to_spk2utt.pl <$dir/callhome_train_all/callhome_utt2spk > $dir/callhome_train_all/callhome_spk2utt
fi

if [ $stage -le 3 ]; then
  cat $tmpdir/callhome_train_sph.flist | perl -ane 'm:/([^/]+)\.SPH$: || die "bad line $_; ";  print lc($1)," $_"; ' > $tmpdir/callhome_sph.scp
  cat $tmpdir/callhome_sph.scp | awk -v sph2pipe=$sph2pipe '{printf("%s-A %s -f wav -p -c 1 %s |\n", $1, sph2pipe, $2); printf("%s-B %s -f wav -p -c 2 %s |\n", $1, sph2pipe, $2);}' | \
  sort -k1,1 -u  > $dir/callhome_train_all/callhome_wav.scp || exit 1;
fi

if [ $stage -le 4 ]; then
  # Build the speaker to gender map, the temporary file with the speaker in gender information is already created by fsp_make_trans.pl.
  cd $cdir
  #TODO: needs to be rewritten
  $local/callhome_make_spk2gender > $dir/callhome_train_all/callhome_spk2gender
fi

# Rename files from the callhome directory
if [ $stage -le 5 ]; then
    cd $dir/callhome_train_all
    mv callhome.text text
    mv callhome_segments segments
    mv callhome_spk2utt spk2utt
    mv callhome_wav.scp wav.scp
    mv callhome_reco2file_and_channel reco2file_and_channel
    mv callhome_spk2gender spk2gender
    mv callhome_utt2spk utt2spk
fi

echo "CALLHOME spanish Data preparation succeeded."

exit 1;

#--------------------END OF FILE -----------------------------------#
#-----Data that follows is from the RM recipe and will be deleted---#

dir=data/train
mkdir -p $dir



# make_trans.pl also creates the utterance id's and the kaldi-format scp file.
local/make_trans.pl trn $tmpdir/train_sph.flist $RMROOT/rm1_audio1/rm1/doc/al_sents.snr >(sort -k1 >$dir/text) \
 >(sort -k1 > $dir/sph.scp)


sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
[ ! -f $sph2pipe ] && echo "Could not find the sph2pipe program at $sph2pipe" && exit 1;

awk '{printf("%s '$sph2pipe' -f wav %s |\n", $1, $2);}' < $dir/sph.scp > $dir/wav.scp
rm $dir/sph.scp

cat $dir/wav.scp | perl -ane 'm/^((\w+)\w_\w+_\w+) / || die; print "$1 $2\n"' > $dir/utt2spk
utils/utt2spk_to_spk2utt.pl $dir/utt2spk > $dir/spk2utt


for ntest in 1_mar87 2_oct87 4_feb89 5_oct89 6_feb91 7_sep92; do
  n=`echo $ntest | cut -d_ -f 1` # e.g. n = 1, 2, 4, 5..
  test=`echo $ntest | cut -d_ -f 2` # e.g. test=mar87, oct87...
  dir=data/test_${test}
  mkdir $dir
  root=$RMROOT/rm1_audio2/2_4_2
  for x in `grep -v ';' $root/rm1/doc/tests/$ntest/${n}_indtst.ndx`; do
    echo "$root/$x ";
  done | sort > $dir/sph.flist

  local/make_trans.pl ${test} $dir/sph.flist $RMROOT/rm1_audio1/rm1/doc/al_sents.snr \
     >(sort -k1 >$dir/text) >(sort -k1 >$dir/sph.scp)

  awk '{printf("%s '$sph2pipe' -f wav %s |\n", $1, $2);}' < $dir/sph.scp >$dir/wav.scp
  rm $dir/sph.flist $dir/sph.scp

  cat $dir/wav.scp | perl -ane 'm/^((\w+)\w_\w+_\w+) / || die; print "$1 $2\n"' > $dir/utt2spk
  utils/utt2spk_to_spk2utt.pl $dir/utt2spk > $dir/spk2utt
done

cat $RMROOT/rm1_audio2/2_5_1/rm1/doc/al_spkrs.txt \
    $RMROOT/rm2_audio/3-1.2/rm2/doc/al_spkrs.txt | \
    perl -ane 'tr/A-Z/a-z/;print;' | grep -v ';' | \
    awk '{print $1, $2}' | sort | uniq > $tmpdir/spk2gender.map || exit 1;

for t in train test_mar87 test_oct87 test_feb89 test_oct89 test_feb91 test_sep92; do
  utils/filter_scp.pl data/$t/spk2utt $tmpdir/spk2gender.map >data/$t/spk2gender.map
done

local/make_rm_lm.pl $RMROOT/rm1_audio1/rm1/doc/wp_gram.txt  > $tmpdir/G.txt || exit 1;

mkdir data/local/dict

# Getting lexicon
local/make_rm_dict.pl  $RMROOT/rm1_audio2/2_4_2/score/src/rdev/pcdsril.txt \
   > data/local/dict/lexicon.txt || exit 1;

# Get phone lists...
grep -v -w sil data/local/dict/lexicon.txt | \
  awk '{for(n=2;n<=NF;n++) { p[$n]=1; }} END{for(x in p) {print x}}' | sort > data/local/dict/nonsilence_phones.txt
echo sil > data/local/dict/silence_phones.txt
echo sil > data/local/dict/optional_silence.txt
touch data/local/dict/extra_questions.txt # no extra questions, as we have no stress or tone markers.

echo RM_data_prep succeeded.
