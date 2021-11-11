#!/bin/bash -e

#PBS -l walltime=02:00:00
#PBS -l nodes=1:ppn=16
#PBS -l mem=32GB
cd $PBS_O_WORKDIR

#Description: CEP Pipeline
#Author: Matthew Lyon
#Maintainer: ben.sanders@salisbury.nhs.uk
#Status: Release
#Updated 10 May 2018, Ben Sanders
#Update note: Uses CEP_PIPELINE.config file for settings
#Updated 04 Feb 2019, Ben Sanders
#Update note: Moved module loads to config file. Chagned cp to mv when copying fastqs - faster and originals not needed.
#Mode: BY_RUN

# make this file to record the start time
# ideally would do as qsub-ed, but I don't know if that's possible.
# This will account for all runtime excepting script 0 queueing time
touch started

module load bcl2fastq2/2.16

# set up variables
. *.config

# Check that there is a samplesheet in the folder
if (( $( find . -mindepth 1 -name "*.csv" | wc -l ) != 1)); then
    echo "no CSV found"
    exit 1
fi

# Ensure samplesheet is complete
# we have to use cat and pipe into the checker in order to use a wildcard to
# select the CSV. Otherwise it doesn't accept it as the input filename. I assume
# the glob returns an array of length 1, rather than a string of the only filename?
cat *.csv | python "$auxscripts"/aux2_samplesheet_checker.py "$runID" > "$runID".csv

# run bcl2fastq
bcl2fastq --no-lane-splitting --sample-sheet "$runID".csv

# go to folder with fastqs
cd "$runfolder"

# generate md5 for each (looked for in variables making script)
for folder in $( find . -mindepth 1 -type "d"); do
	cd "$folder"
	for f in *.fastq.gz; do
        md5sum "$f" > "$f".md5
	done
	cd ..
done

# return to root run folder
cd ../../../..

# copy in other needed files
cp "$bedpath"/"$targetbed" .

# DEV: Don't do this until the scripts are all sorted out and working
cp "$pipelinescripts"/*.sh .

# generate IDs.txt
cat "$runID".csv | awk 'BEGIN{FS=",";IDs=0}{if (IDs == 1) print $1; if ($1 == "Sample_ID") IDs = 1}' > IDs.txt

# copy fastq files to sample-specific folders
while read p; do
    mkdir "$p"
    cp "$bedpath"/"$targetbed" "$p"
    mv "$runfolder"/"$p"/* "$p"
    cp *.sh "$p"
    cp *.config "$p"
done < IDs.txt

# delete raw data - must be before making variables
rm -rf Config
rm -rf Data
rm -rf Images
rm -rf InterOp
rm -rf Logs
rm -rf RTALogs
rm -rf Recipe
rm RTA*.txt RTA*.xml Run*.xml

# generate variables files for CEP scripts
"$auxscripts"/aux1_CEP_make_variables.sh

# DEV: Not needed with pipeline_runner.sh
# now trigger script 1 for each sample
#while read p; do
#    cd "$p"
#    "$auxscripts"/aux0_Start_Pipeline.sh
#    cd ..
#done < IDs.txt
