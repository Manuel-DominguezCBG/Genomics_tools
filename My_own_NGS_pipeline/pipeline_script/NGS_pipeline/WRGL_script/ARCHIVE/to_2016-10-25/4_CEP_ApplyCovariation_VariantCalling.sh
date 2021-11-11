#!/bin/bash
#PBS -l walltime=30:00:00
#PBS -l nodes=1:ppn=12
#PBS -l mem=20gb
#PBS -W umask=0007
cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Status: Dev
#Updated: 30 November 2015, Ben Sanders
#Update note: Added umask to PBS settings, to allow multiple users to access output.
#Updated: 21 Jan 2016, Reuben Pengelly
#Update note: Edit input filenames, GATK memory and core allocation PBS parameters
#Mode: BY_SAMPLE
module load jdk/1.7.0

#load sample variables
. *.variables

#Apply the recalibration to your sequence data
java -Xmx4000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T PrintReads \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-I "$RunID"_"$Sample_ID"_trim.bam \
-BQSR ../"$RunID"_recal_data.table \
-L "$BEDFilename" \
-o "$RunID"_"$Sample_ID"_recal.bam \
-ip 100 \
-compress 0 \
-dt NONE

#set read group headers correctly
java -Xmx2000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/picard-tools-1.118/AddOrReplaceReadGroups.jar \
INPUT="$RunID"_"$Sample_ID"_recal.bam \
OUTPUT="$RunID"_"$Sample_ID".bam \
CREATE_INDEX=true \
RGID="$RunID" \
RGLB="$ExperimentName" \
RGPL="$Platform" \
RGPU="$RunID" \
RGSM="$Sample_ID" \
VALIDATION_STRINGENCY=LENIENT

#variant calling with Haplotypecaller
java -Xmx16g -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T HaplotypeCaller \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
--dbsnp /scratch/WRGL/bundle2.8/b37/dbsnp_138.b37.vcf \
-I "$RunID"_"$Sample_ID".bam \
-L "$BEDFilename" \
-o "$RunID"_"$Sample_ID".vcf \
--genotyping_mode DISCOVERY \
-stand_emit_conf 10 \
-stand_call_conf 30 \
--emitRefConfidence GVCF \
--variant_index_type LINEAR \
--variant_index_parameter 128000 \
-dt NONE \
-nct 12

#clean up
#rm "$RunID"_"$Sample_ID"_trim.bam
#rm "$RunID"_"$Sample_ID"_trim.bai
#rm "$RunID"_"$Sample_ID"_recal.bam
#rm "$RunID"_"$Sample_ID"_recal.bai

#create VCFs list for recalibration
find `pwd` -name "$RunID"_"$Sample_ID".vcf >> ../VCFsforFiltering.list
find `pwd` -name "$RunID"_"$Sample_ID".bam >> ../BAMsforDepthAnalysis.list

#check if all VCFs are written
if [ ${#AnalysisDirs[@]} -eq $(wc -l ../VCFsforFiltering.list | cut -f1 -d' ') ]
  then
      cp 5_CEP_VariantProcessing.sh ..
      cd ..
      qsub 5_CEP_VariantProcessing.sh
fi
