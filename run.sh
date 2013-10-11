#!/bin/bash
#
# Johns Hopkins University (Author : Gaurav Kumar, Daniel Povey)
# Recipe for Fisher-Spanish
# Made to integrate KALDI with JOSHUA for end-to-end ASR and SMT

. cmd.sh
. path.sh
mfccdir=`pwd`/mfcc
set -e

# call the next line with the directory where the Spanish Fisher data is
# (the values below are just an example).  This should contain
# subdirectories named as follows:
# DISC1 DIC2

sfisher_speech=/home/mpost/data/LDC/LDC2010S01
sfisher_transcripts=/home/mpost/data/LDC/LDC2010T04
spanish_lexicon=/export/a04/gkumar/corpora/LDC96L16
split=/export/a04/gkumar/corpora/fishcall/jack-splits/split-matt

callhome_speech=/export/corpora/LDC/LDC96S35
callhome_transcripts=/export/corpora/LDC/LDC96T17
split_callhome=/export/a04/gkumar/corpora/fishcall/jack-splits/split-callhome

local/fsp_data_prep.sh $sfisher_speech $sfisher_transcripts

local/callhome_data_prep.sh $callhome_speech $callhome_transcripts

local/fsp_prepare_dict.sh $spanish_lexicon

# Rewrite ----------------------------- This section is no longer needed----
# At this point, it might make sense to use a bigger lexicon
# The one I will use is derived from this exercise (spanish fisher) and 
# the LDC spanish lexicon along with the most frequent words derived from the 
# gigaword corpus such that the total number of entries in the lexicon
# are 64k

# To generate the merged lexicon, run
# /export/a04/gkumar/corpora/gigaword/bin/merge_lexicons.py
# you might have to set the locations of the three lexicons within this
# file. Note that the LDC rule base phoneme generator works only from its 
# own directory. So the merged lexicon is actually created in 
# /export/a04/gkumar/corpora/LDC9..../spanish_lexicon../lexicon64k
# This can be easily fixed and will be done. #TODO
# Also run the clean lexicon script to take care of non stressable vowels

# First make a copy of the old lexicon
#mv data/local/dict/lexicon.txt data/local/dict/lexicon.txt.bak
#cp /export/a04/gkumar/corpora/gigaword/bin/clean-merged-lexicon data/local/dict/lexicon.txt
# ------------ Rewrite -----------------------

# Added c,j, v to the non silences phones manually
utils/prepare_lang.sh data/local/dict "<unk>" data/local/lang data/lang


# Make sure that you do not use your test and your dev sets to train the LM
# Some form of cross validation is possible where you decode your dev/set based on an 
# LM that is trained on  everything but that that conversation
# When in doubt about what your data partitions should be use local/fsp_ideal_data_partitions.pl
# to get the numbers. Depending on your needs, you might have to change the size of 
# the splits within that file. The default paritions are based on the Kaldi + Joshua 
# requirements which means that I have very large dev and test sets
local/fsp_train_lms.sh $split
local/fsp_create_test_lang.sh

utils/fix_data_dir.sh data/local/data/train_all

steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" data/local/data/train_all exp/make_mfcc/train_all $mfccdir || exit 1;

utils/fix_data_dir.sh data/local/data/train_all
utils/validate_data_dir.sh data/local/data/train_all

cp -r data/local/data/train_all data/train_all

# For the CALLHOME corpus
utils/fix_data_dir.sh data/local/data/callhome_train_all

steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" data/local/data/callhome_train_all exp/make_mfcc/callhome_train_all $mfccdir || exit 1;

utils/fix_data_dir.sh data/local/data/callhome_train_all
utils/validate_data_dir.sh data/local/data/callhome_train_all

cp -r data/local/data/callhome_train_all data/callhome_train_all

# Creating data partitions for the pipeline
# We need datasets for both the ASR and SMT system
# We have 257455 utterances left, so the partitions are roughly as follows
# ASR Train : 100k utterances
# ASR Tune : 17455 utterances
# ASR Eval : 20k utterances
# MT Train : 100k utterances
# MT Tune : Same as the ASR eval set (Use the lattices from here)
# MT Eval : 20k utterances
# The dev and the test sets need to be carefully chosen so that there is no conversation/speaker
# overlap. This has been setup and the script local/fsp_ideal_data_partitions provides the numbers that are needed below. 
# As noted above, the LM has not been trained on the dev and the test sets.
#utils/subset_data_dir.sh --first data/train_all 158126 data/dev_and_test
#utils/subset_data_dir.sh --first data/dev_and_test 37814 data/asr_dev_and_test
#utils/subset_data_dir.sh --last data/dev_and_test 120312 data/mt_train_and_test
#utils/subset_data_dir.sh --first data/asr_dev_and_test 17662 data/dev
#utils/subset_data_dir.sh --last data/asr_dev_and_test 20152 data/test
#utils/subset_data_dir.sh --first data/mt_train_and_test 100238 data/mt_train
#utils/subset_data_dir.sh --last data/mt_train_and_test 20074 data/mt_test
#rm -r data/dev_and_test
#rm -r data/asr_dev_and_test
#rm -r data/mt_train_and_test

local/create_splits $split
local/callhome_create_splits $split_callhome

# Now compute CMVN stats for the train, dev and test subsets
steps/compute_cmvn_stats.sh data/dev exp/make_mfcc/dev $mfccdir
steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir
steps/compute_cmvn_stats.sh data/dev2 exp/make_mfcc/dev2 $mfccdir
#steps/compute_cmvn_stats.sh data/mt_train exp/make_mfcc/mt_train $mfccdir
#steps/compute_cmvn_stats.sh data/mt_test exp/make_mfcc/mt_test $mfccdir

#n=$[`cat data/train_all/segments | wc -l` - 158126]
#utils/subset_data_dir.sh --last data/train_all $n data/train
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir

steps/compute_cmvn_stats.sh data/callhome_dev exp/make_mfcc/callhome_dev $mfccdir
steps/compute_cmvn_stats.sh data/callhome_test exp/make_mfcc/callhome_test $mfccdir
steps/compute_cmvn_stats.sh data/callhome_train exp/make_mfcc/callhome_train $mfccdir

# Again from Dan's recipe : Reduced monophone training data
# Now-- there are 1.6 million utterances, and we want to start the monophone training
# on relatively short utterances (easier to align), but not only the very shortest
# ones (mostly uh-huh).  So take the 100k shortest ones, and then take 10k random
# utterances from those.

utils/subset_data_dir.sh --shortest data/train 90000 data/train_100kshort
utils/subset_data_dir.sh  data/train_100kshort 10000 data/train_10k
local/remove_dup_utts.sh 100 data/train_10k data/train_10k_nodup
utils/subset_data_dir.sh --speakers data/train 30000 data/train_30k
utils/subset_data_dir.sh --speakers data/train 90000 data/train_100k  

steps/train_mono.sh --nj 10 --cmd "$train_cmd" \                                 
  data/train_10k_nodup data/lang exp/mono0a    

steps/align_si.sh --nj 30 --cmd "$train_cmd" \                                   
   data/train_30k data/lang exp/mono0a exp/mono0a_ali || exit 1;                 
                                                                                 
steps/train_deltas.sh --cmd "$train_cmd" \                                       
    2500 20000 data/train_30k data/lang exp/mono0a_ali exp/tri1 || exit 1;  


(utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph
 steps/decode.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
   exp/tri1/graph data/dev exp/tri1/decode_dev)&

steps/align_si.sh --nj 30 --cmd "$train_cmd" \
   data/train_30k data/lang exp/tri1 exp/tri1_ali || exit 1;

steps/train_deltas.sh --cmd "$train_cmd" \
    2500 20000 data/train_30k data/lang exp/tri1_ali exp/tri2 || exit 1;

(
  utils/mkgraph.sh data/lang_test exp/tri2 exp/tri2/graph || exit 1;             
  steps/decode.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
   exp/tri2/graph data/dev exp/tri2/decode_dev || exit 1;
)&


steps/align_si.sh --nj 30 --cmd "$train_cmd" \
  data/train_100k data/lang exp/tri2 exp/tri2_ali || exit 1;

# Train tri3a, which is LDA+MLLT, on 100k data.
steps/train_lda_mllt.sh --cmd "$train_cmd" \
   --splice-opts "--left-context=3 --right-context=3" \
   3000 40000 data/train_100k data/lang exp/tri2_ali exp/tri3a || exit 1;
(
  utils/mkgraph.sh data/lang_test exp/tri3a exp/tri3a/graph || exit 1;
  steps/decode.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
   exp/tri3a/graph data/dev exp/tri3a/decode_dev || exit 1;
)&

# Next we'll use fMLLR and train with SAT (i.e. on 
# fMLLR features)

steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
  data/train_100k data/lang exp/tri3a exp/tri3a_ali || exit 1;

steps/train_sat.sh  --cmd "$train_cmd" \
  4000 60000 data/train_100k data/lang exp/tri3a_ali  exp/tri4a || exit 1;
                                                                                 
(
  utils/mkgraph.sh data/lang_test exp/tri4a exp/tri4a/graph
  steps/decode_fmllr.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
   exp/tri4a/graph data/dev exp/tri4a/decode_dev
)&


steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
  data/train data/lang exp/tri4a exp/tri4a_ali || exit 1;

# Reduce the number of gaussians
steps/train_sat.sh  --cmd "$train_cmd" \
  5000 120000 data/train data/lang exp/tri4a_ali  exp/tri5a || exit 1;

(
  utils/mkgraph.sh data/lang_test exp/tri5a exp/tri5a/graph
  steps/decode_fmllr.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
   exp/tri5a/graph data/dev exp/tri5a/decode_dev
)&

steps/decode_fmllr.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
exp/tri5a/graph data/test exp/tri5a/decode_test

# Decode CALLHOME
steps/decode_fmllr.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
exp/tri5a/graph data/callhome_test exp/tri5a/decode_callhome_test
steps/decode_fmllr.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
exp/tri5a/graph data/callhome_dev exp/tri5a/decode_callhome_dev
steps/decode_fmllr.sh --nj 25 --cmd "$decode_cmd" --config conf/decode.config \
exp/tri5a/graph data/callhome_train exp/tri5a/decode_callhome_train

exit 1;

#TODO:Incomplete
local/rm_data_prep.sh /export/corpora5/LDC/LDC93S3A/rm_comp || exit 1;

utils/prepare_lang.sh data/local/dict '!SIL' data/local/lang data/lang || exit 1;

local/rm_prepare_grammar.sh || exit 1;

# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
featdir=mfcc

for x in test_mar87 test_oct87 test_feb89 test_oct89 test_feb91 test_sep92 train; do
  steps/make_mfcc.sh --nj 8 --cmd "run.pl" data/$x exp/make_mfcc/$x $featdir  || exit 1;
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $featdir  || exit 1;
  #steps/make_plp.sh data/$x exp/make_plp/$x $featdir 4
done

# Make a combined data dir where the data from all the test sets goes-- we do
# all our testing on this averaged set.  This is just less hassle.  We
# regenerate the CMVN stats as one of the speakers appears in two of the 
# test sets; otherwise tools complain as the archive has 2 entries.
utils/combine_data.sh data/test data/test_{mar87,oct87,feb89,oct89,feb91,sep92}
steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $featdir  

utils/subset_data_dir.sh data/train 1000 data/train.1k  || exit 1;

steps/train_mono.sh --nj 4 --cmd "$train_cmd" data/train.1k data/lang exp/mono  || exit 1;

#show-transitions data/lang/phones.txt exp/tri2a/final.mdl  exp/tri2a/final.occs | perl -e 'while(<>) { if (m/ sil /) { $l = <>; $l =~ m/pdf = (\d+)/|| die "bad line $l";  $tot += $1; }} print "Total silence count $tot\n";'



utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph

steps/decode.sh --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
  exp/mono/graph data/test exp/mono/decode


# Get alignments from monophone system.
steps/align_si.sh --nj 8 --cmd "$train_cmd" \
  data/train data/lang exp/mono exp/mono_ali || exit 1;

# train tri1 [first triphone pass]
steps/train_deltas.sh --cmd "$train_cmd" \
 1800 9000 data/train data/lang exp/mono_ali exp/tri1 || exit 1;

# decode tri1
utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1;
steps/decode.sh --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
  exp/tri1/graph data/test exp/tri1/decode

#draw-tree data/lang/phones.txt exp/tri1/tree | dot -Tps -Gsize=8,10.5 | ps2pdf - tree.pdf

# align tri1
steps/align_si.sh --nj 8 --cmd "$train_cmd" \
  --use-graphs true data/train data/lang exp/tri1 exp/tri1_ali || exit 1;

# train tri2a [delta+delta-deltas]
steps/train_deltas.sh --cmd "$train_cmd" 1800 9000 \
 data/train data/lang exp/tri1_ali exp/tri2a || exit 1;

# decode tri2a
utils/mkgraph.sh data/lang exp/tri2a exp/tri2a/graph
steps/decode.sh --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
  exp/tri2a/graph data/test exp/tri2a/decode

#TODO: Use tri2alignments

# train and decode tri2b [LDA+MLLT]
steps/train_lda_mllt.sh --cmd "$train_cmd" \
  --splice-opts "--left-context=3 --right-context=3" \
 1800 9000 data/train data/lang exp/tri1_ali exp/tri2b || exit 1;
utils/mkgraph.sh data/lang exp/tri2b exp/tri2b/graph
steps/decode.sh --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b/decode

# Align all data with LDA+MLLT system (tri2b)
steps/align_si.sh --nj 8 --cmd "$train_cmd" --use-graphs true \
   data/train data/lang exp/tri2b exp/tri2b_ali || exit 1;

#  Do MMI on top of LDA+MLLT.
steps/make_denlats.sh --nj 8 --cmd "$train_cmd" \
  data/train data/lang exp/tri2b exp/tri2b_denlats || exit 1;
steps/train_mmi.sh data/train data/lang exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mmi || exit 1;
steps/decode.sh --config conf/decode.config --iter 4 --nj 20 --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mmi/decode_it4
steps/decode.sh --config conf/decode.config --iter 3 --nj 20 --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mmi/decode_it3

# Do the same with boosting.
steps/train_mmi.sh --boost 0.05 data/train data/lang \
   exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mmi_b0.05 || exit 1;
steps/decode.sh --config conf/decode.config --iter 4 --nj 20 --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mmi_b0.05/decode_it4 || exit 1;
steps/decode.sh --config conf/decode.config --iter 3 --nj 20 --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mmi_b0.05/decode_it3 || exit 1;

# Do MPE.
steps/train_mpe.sh data/train data/lang exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mpe || exit 1;
steps/decode.sh --config conf/decode.config --iter 4 --nj 20 --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mpe/decode_it4 || exit 1;
steps/decode.sh --config conf/decode.config --iter 3 --nj 20 --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mpe/decode_it3 || exit 1;


## Do LDA+MLLT+SAT, and decode.
steps/train_sat.sh 1800 9000 data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
utils/mkgraph.sh data/lang exp/tri3b exp/tri3b/graph || exit 1;
steps/decode_fmllr.sh --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
  exp/tri3b/graph data/test exp/tri3b/decode || exit 1;



# Align all data with LDA+MLLT+SAT system (tri3b)
steps/align_fmllr.sh --nj 8 --cmd "$train_cmd" --use-graphs true \
  data/train data/lang exp/tri3b exp/tri3b_ali || exit 1;

## MMI on top of tri3b (i.e. LDA+MLLT+SAT+MMI)
steps/make_denlats.sh --config conf/decode.config \
   --nj 8 --cmd "$train_cmd" --transform-dir exp/tri3b_ali \
  data/train data/lang exp/tri3b exp/tri3b_denlats || exit 1;
steps/train_mmi.sh data/train data/lang exp/tri3b_ali exp/tri3b_denlats exp/tri3b_mmi || exit 1;

steps/decode_fmllr.sh --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
  --alignment-model exp/tri3b/final.alimdl --adapt-model exp/tri3b/final.mdl \
   exp/tri3b/graph data/test exp/tri3b_mmi/decode || exit 1;

# Do a decoding that uses the exp/tri3b/decode directory to get transforms from.
steps/decode.sh --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
  --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_mmi/decode2 || exit 1;


#first, train UBM for fMMI experiments.
steps/train_diag_ubm.sh --silence-weight 0.5 --nj 8 --cmd "$train_cmd" \
  250 data/train data/lang exp/tri3b_ali exp/dubm3b

# Next, various fMMI+MMI configurations.
steps/train_mmi_fmmi.sh --learning-rate 0.0025 \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_b || exit 1;

for iter in 3 4 5 6 7 8; do
 steps/decode_fmmi.sh --nj 20 --config conf/decode.config --cmd "$decode_cmd" --iter $iter \
   --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_fmmi_b/decode_it$iter &
done

steps/train_mmi_fmmi.sh --learning-rate 0.001 \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_c || exit 1;

for iter in 3 4 5 6 7 8; do
 steps/decode_fmmi.sh --nj 20 --config conf/decode.config --cmd "$decode_cmd" --iter $iter \
   --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_fmmi_c/decode_it$iter &
done

# for indirect one, use twice the learning rate.
steps/train_mmi_fmmi_indirect.sh --learning-rate 0.01 --schedule "fmmi fmmi fmmi fmmi mmi mmi mmi mmi" \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_d || exit 1;

for iter in 3 4 5 6 7 8; do
 steps/decode_fmmi.sh --nj 20 --config conf/decode.config --cmd "$decode_cmd" --iter $iter \
   --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_fmmi_d/decode_it$iter &
done

# You don't have to run all 3 of the below, e.g. you can just run the run_sgmm2x.sh
local/run_sgmm.sh
local/run_sgmm2.sh
local/run_sgmm2x.sh

# you can do:
# local/run_nnet_cpu.sh


