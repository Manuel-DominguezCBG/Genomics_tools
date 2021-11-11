#!/bin/bash
#PBS -l walltime=40:00:00
#PBS -l nodes=1:ppn=1
#PBS -l mem=5000mb
#PBS -W umask=0007
cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Status: Dev
#Updated: 30 November 2015, Ben Sanders
#Update note: Added umask to PBS settings, to allow multiple users to access output.
#Updated: 21 Jan 2016, Reuben Pengelly
#Update note: Added clipping of read overlap in pairs and PBS parameters.
#Mode: BY_SAMPLE

module load jdk/1.7.0
module load bamUtil/1.0.10
module load samtools/1.1

#load sample variables
. *.variables

#Sort reads and convert to BAM
java -Xmx4000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/picard-tools-1.118/SortSam.jar \
INPUT="$RunID"_"$Sample_ID".sam \
OUTPUT="$RunID"_"$Sample_ID"_sorted.bam \
SORT_ORDER=coordinate \
COMPRESSION_LEVEL=0

#Mark duplicate reads
java -Xmx4000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/picard-tools-1.118/MarkDuplicates.jar \
INPUT="$RunID"_"$Sample_ID"_sorted.bam \
OUTPUT="$RunID"_"$Sample_ID"_rmdup.bam \
METRICS_FILE="$RunID"_"$Sample_ID"_dupMetrics.txt \
CREATE_INDEX=true \
COMPRESSION_LEVEL=0

#Identify regions requiring realignment
java -Xmx2000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T RealignerTargetCreator \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-known /scratch/WRGL/bundle2.8/b37/1000G_phase1.indels.b37.vcf \
-known /scratch/WRGL/bundle2.8/b37/Mills_and_1000G_gold_standard.indels.b37.vcf \
-I "$RunID"_"$Sample_ID"_rmdup.bam \
-o "$RunID"_"$Sample_ID".intervals \
-L "$BEDFilename" \
-ip 100 \
-dt NONE

#Realign around indels
java -Xmx4000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T IndelRealigner \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-known /scratch/WRGL/bundle2.8/b37/1000G_phase1.indels.b37.vcf \
-known /scratch/WRGL/bundle2.8/b37/Mills_and_1000G_gold_standard.indels.b37.vcf \
-targetIntervals "$RunID"_"$Sample_ID".intervals \
-I "$RunID"_"$Sample_ID"_rmdup.bam \
-o "$RunID"_"$Sample_ID"_realigned.bam \
--LODThresholdForCleaning 0.4 \
--maxReadsForRealignment 60000 \
--maxConsensuses 90 \
--maxReadsForConsensuses 360 \
-compress 0 \
-dt NONE

#Trim overlap between read pairs
bam clipOverlap \
--in "$RunID"_"$Sample_ID"_realigned.bam \
--out "$RunID"_"$Sample_ID"_trim.bam

#Index final trimmed bam
samtools index "$RunID"_"$Sample_ID"_trim.bam

#cleanup
rm "$RunID"_"$Sample_ID".sam
rm "$RunID"_"$Sample_ID"_sorted.bam
rm "$RunID"_"$Sample_ID"_rmdup.bam
rm "$RunID"_"$Sample_ID"_rmdup.bai
rm "$RunID"_"$Sample_ID"_realigned.bam
rm "$RunID"_"$Sample_ID"_realigned.bam.bai

#create BAMs list for recalibration
find `pwd` -name "$RunID"_"$Sample_ID"_trim.bam >> ../BAMsforBQSR.list

#check if all realignments are done
if [ ${#AnalysisDirs[@]} -eq $(wc -l ../BAMsforBQSR.list | cut -f1 -d' ') ]
  then
      cp 3_CEP_AnalyseCovariation.sh ..
      cp *.variables ..
      cp *.bed ..
      cd ..
      qsub 3_CEP_AnalyseCovariation.sh
fi
