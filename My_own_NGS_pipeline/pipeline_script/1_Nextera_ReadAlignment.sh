#!/bin/bash -e

#PBS -W umask=002
#PBS -W group_list=wrgl

cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Maintainer: ben.sanders@salisburry.nhs.uk
#Status: Release
#Updated 08 May 2018, Ben Sanders
#Update note: Created config file with params and paths for all scripts
#Mode: BY_SAMPLE

# Load pipeline settings - load before variables and any duplicate valures
#                          will be replaced with the variables file ones.
. *.config

# Load sample variables
. *.variables

# Only do alignment if it hasn't already been done
if [ ! -f "$RunID"_"$Sample_ID".sam ] && [ ! -f *.bam ]; then
    # Check FASTQ MD5sums
    md5sum -c "$R1MD5Filename"
    if [ $? -ne 0 ];then
       exit -1
    fi

    md5sum -c "$R2MD5Filename"
    if [ $? -ne 0 ];then
       exit -1
    fi

    # Align reads with BWA-MEM
    # number of threads is dynamically set from config
    bwa mem \
    -t "$alignmentppn" \
    -R '@RG\tID:'"$RunID"'_'"$Sample_ID"'\tSM:'"$Sample_ID"'\tPL:'"$Platform"'\tLB:'"$ExperimentName" \
    "$bwarefgenome" \
    "$R1Filename" "$R2Filename" \
    > "$RunID"_"$Sample_ID".sam
fi

# Sort reads and convert to BAM
if [ -f "$RunID"_"$Sample_ID".sam ]; then
    java -Xmx4000m "$javatmp" -jar "$picardpath" SortSam \
    INPUT="$RunID"_"$Sample_ID".sam \
    OUTPUT="$RunID"_"$Sample_ID"_sorted.bam \
    SORT_ORDER=coordinate \
    COMPRESSION_LEVEL=5

    rm "$RunID"_"$Sample_ID".sam
fi

# Mark duplicate reads
if [ -f "$RunID"_"$Sample_ID"_sorted.bam ]; then
    java -Xmx4000m "$javatmp" -jar "$picardpath" MarkDuplicates \
    INPUT="$RunID"_"$Sample_ID"_sorted.bam \
    OUTPUT="$RunID"_"$Sample_ID"_rmdup.bam \
    METRICS_FILE="$RunID"_"$Sample_ID"_dupMetrics.txt \
    CREATE_INDEX=true \
    COMPRESSION_LEVEL=5

    rm "$RunID"_"$Sample_ID"_sorted.ba*
fi

# Identify regions requiring realignment
if [ -f "$RunID"_"$Sample_ID"_rmdup.bam ]; then
    java -Xmx2000m "$javatmp" -jar "$gatkpath" \
    -T RealignerTargetCreator \
    -R "$refgenome" \
    -known "$knownindels1" \
    -known "$knownindels2" \
    -I "$RunID"_"$Sample_ID"_rmdup.bam \
    -o "$RunID"_"$Sample_ID".intervals \
    -L "$BEDFilename" \
    -ip 100 \
    -dt NONE

    # Realign around indels
    java -Xmx4000m "$javatmp" -jar "$gatkpath" \
    -T IndelRealigner \
    -R "$refgenome" \
    -known "$knownindels1" \
    -known "$knownindels2" \
    -targetIntervals "$RunID"_"$Sample_ID".intervals \
    -I "$RunID"_"$Sample_ID"_rmdup.bam \
    -o "$RunID"_"$Sample_ID"_realigned.bam \
    --LODThresholdForCleaning 0.4 \
    --maxReadsForRealignment 60000 \
    --maxConsensuses 90 \
    --maxReadsForConsensuses 360 \
    -compress 5 \
    -dt NONE

    rm "$RunID"_"$Sample_ID"_rmdup.ba*
fi

# Create BAMs list for recalibration
find `pwd` -name "$RunID"_"$Sample_ID"_realigned.bam >> ../BAMsforBQSR.list

# Check if all realignments are done
if [ ${#AnalysisDirs[@]} -eq $(wc -l ../BAMsforBQSR.list | cut -f1 -d' ') ]; then
    # Copy files to run directory needed for next script
	cp 3_Nextera_AnalyseCovariation.sh ..
	cp *.variables ..
	cp *.bed ..
	cp *.config ..
	cd ..
fi

