#!/usr/bin/env python

# Extracts one best output for a set of files
# What do you need?
# Location of the timing files
# The list of files in the conversations for which 1 best output has to be extracted
# words.txt 

import os
import sys

oracleDir = "exp/tri5a/decode_dev2/oracle"
wordsFile = open('exp/tri5a/graph/words.txt')
conversationList = open('/export/a04/gkumar/corpora/fishcall/jack-splits/split-matt/dev2')
oracleTmp = 'exp/tri5a/one-best/oracle-dev2'
provFile = open('/export/a04/gkumar/corpora/fishcall/jack-splits/split-matt/oracle.dev2', 'w+')
timLocation = '/export/a04/gkumar/corpora/fishcall/fisher/tim'

def findTranscription(timeDetail):
	file1 = open(oracleDir + "/oracle.tra")
	for line in file1:
		lineComp = line.split()
		if lineComp[0] == timeDetail:
			return " ".join(lineComp[1:])
	# No result found
	return -1

words = {}

# Extract word list
for line in wordsFile:
	lineComp = line.split()
	words[int(lineComp[1])] = lineComp[0].strip()

# Now read list of files in conversations
fileList = []
for line in conversationList: 
    line = line.strip()
    line = line[:-4]
    fileList.append(line)

# IN what order were the conversations added to the spanish files?
# TODO: Make sure they match the order in which these english files are being written

# Now get timing information to concatenate the ASR outputs
if not os.path.exists(oracleTmp):
	os.makedirs(oracleTmp)

#provFile = open('/export/a04/gkumar/corpora/fishcall/fisher_provisional_dev.es', 'w+')
for item in fileList:
	timingFile = open(timLocation + '/' + item + '.es')
	newFile = open(oracleTmp + '/' + item + '.es', 'w+')
	for line in timingFile:
		timeInfo = line.split()
		mergedTranslation = ""
		for timeDetail in timeInfo:
			#Locate this in ASR dev/test, this is going to be very slow
			tmp = findTranscription(timeDetail)
			if tmp != -1:
				mergedTranslation = mergedTranslation + " " + tmp
		mergedTranslation = mergedTranslation.strip()
		transWords = [words[int(x)] for x in mergedTranslation.split()]
		newFile.write(" ".join(transWords) + "\n")
		provFile.write(" ".join(transWords) + "\n")

	newFile.close()
provFile.close()
