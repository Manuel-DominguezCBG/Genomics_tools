#!/bin/bash

####
#
# This script processes exome sequence data as uploaded from the NextSeq and processed with bcl2fastq.sh
# (bcl2fastq step *could* be integrated, but I just haven't done it)
#
# Generates md5 files for each fastq, copies all into sample-specfic folders, and triggers CEP analysis scripts
# NOTE: IDs.txt must be present, and a copy of each analysis script
#       I should look into retrieving the scripts from a designated repository.
#       CEP scripts should also be updated, as they take some files from the WRGL folders, and should really be separate
#       Altough these could just be separate incidences of the same git repo.
#
###

runfolder="Data/Intensities/BaseCalls/TSOrun011_20160930"
runID="160930_NB501007_0026_AH2Y7CBGXY"

# go to folder with fastqs
cd "$runfolder"

# generate md5 for each (looked for in variables making script)
for f in *.fastq.gz; do
	md5sum "$f" > "$f".md5
done

# return to root run folder
cd ../../../..

# copy fastq files to sample-specific folders
while read p; do
	mkdir "$p"
	cp "$runfolder"/"$p"* "$p"
	cp *CEP*.sh "$p"
done < IDs.txt

# generate variables files for CEP scripts
./make_CEP_variables.sh "$runID"

# now trigger script 1 for each sample
while read p; do
	cd "$p"
	qsub 1_CEP_ReadAlignment.sh
	cd ..
done < IDs.txt
