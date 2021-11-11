#!/bin/bash -e

cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Maintainer: ben.sanders@salisbury.nhs.uk
#Status: Release
#Update: 19 May 2017, Ben Sanders
#Update note: In GATK3.7 HaplotypeCaller -stand_emit_conf is deprecated, with no replacement. Argument removed from call.
#Updated 08 May 2018, Ben Sanders
#Update note: Created config file with params and paths for all scripts
#Mode: BY_SAMPLE

# Clumpify requires Java
module load jdk/1.8.0

# Load pipeline settings - load before variables and any duplicate valures
#                          will be replaced with the variables file ones.
. *.config

# Check for correct number of inputs
if [ "$#" != 1 ]; then
    >&2 echo "ERROR: Script takes exactly one argument"
    >&2 echo "USAGE: compress <sample ID>"
    exit 1
fi

# Check the dolder exists
if [ ! -d "$1" ]; then
    >&2 echo "ERROR: Sample folder $1 does not exist or cannot be opened"
    >&2 echo "USAGE: compress <sample ID>"
    exit 1
fi

# get name of target sample folder from arguments
targetdir=$1

# Go to sample folder (so we can load the variables file)
cd "$targetdir"

# Load sample variables
. *.variables

>&2 echo "INFO: compressing sample $Sample_ID"

# BAM > CRAM
# DEV TODO: put these paths into the config file
>&2 echo "DEV: Converting BAM to CRAM..."
/scratch/WRGL/software/samtools-1.9/bin/samtools view -T "$refgenome" -C --output-fmt-option nthreads=8 -o "$runID"_"$Sample_ID".cram "$runID"_"$Sample_ID".bam
rm "$runID"_"$Sample_ID".ba*

# index CRAM
>&2 echo "DEV: Indexing CRAM"
/scratch/WRGL/software/samtools-1.9/bin/samtools index "$runID"_"$Sample_ID".cram

# clumpify reads
>&2 echo "DEV: Clumpify-ing reads..."
/scratch/WRGL/software/bbtools/38.63/clumpify.sh in="$R1Filename" out=clumped."$R1Filename" groups=16
/scratch/WRGL/software/bbtools/38.63/clumpify.sh in="$R2Filename" out=clumped."$R2Filename" groups=16
mv clumped."$R1Filename" "$R1Filename"
mv clumped."$R2Filename" "$R2Filename"
md5sum "$R1Filename" > "$R1Filename".md5
md5sum "$R2Filename" > "$R2Filename".md5

# extract variant positions from gVCF
grep "^#" "$runID"_"$Sample_ID".vcf > temp.vcf
grep ",<NON_REF>" "$runID"_"$Sample_ID".vcf >> temp.vcf
mv temp.vcf "$runID"_"$Sample_ID".vcf

# get rid of script error/output files
rm *.sh.*

# return to run folder
cd ..

# zip whole folder
>&2 echo "DEV: Compressing folder..."
tar -czvf "$targetdir"_TEST.tar.gz "$targetdir"
md5sum "$targetdir"_TEST.tar.gz > "$targetdir"_TEST.tar.gz.md5
rm -rf "$targetdir"
