#!/bin/bash
#PBS -l walltime=10:00:00
#PBS -l nodes=1:ppn=1
#PBS -l mem=4000mb
#PBS -W umask=0007
cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Status: Dev
#Updated: 30 November 2015, Ben Sanders
#Update note: Added umask to PBS settings, to allow multiple users to access output.
#Updated: 21 Jan 16, Reuben Pengelly
#Update note: Adjusted PBS parameters
#Mode: BY_COHORT

module load jdk/1.7.0
module load samtools/0.1.19

#load sample variables
. *.variables

#merge calls from HC VCFs
java -Xmx2000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T GenotypeGVCFs \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
--dbsnp /scratch/WRGL/bundle2.8/b37/dbsnp_138.b37.vcf \
-V VCFsforFiltering.list \
-L "$BEDFilename" \
-o "$RunID".vcf \
-dt NONE

#extract SNPs
java -Xmx2000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T SelectVariants \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-V "$RunID".vcf \
-L "$BEDFilename" \
-o "$RunID"_SNPs.vcf \
-selectType SNP \
-dt NONE

#filter SNPs
java -Xmx2000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T VariantFiltration \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-V "$RunID"_SNPs.vcf \
-L "$BEDFilename" \
-o "$RunID"_SNPs_Filtered.vcf \
--filterExpression "QD < 2.0" \
--filterName "LowQD" \
--filterExpression "FS > 60.0" \
--filterName "SB" \
--filterExpression "MQ < 40.0" \
--filterName "LowMQ" \
--filterExpression "MQRankSum < -12.5" \
--filterName "MQRankSum" \
--filterExpression "ReadPosRankSum < -8.0" \
--filterName "ReadPosRankSum" \
-dt NONE

#extract INDELs
java -Xmx2000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T SelectVariants \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-V "$RunID".vcf \
-L "$BEDFilename" \
-o "$RunID"_INDELs.vcf \
-selectType INDEL \
-dt NONE

#filter INDELs
java -Xmx2000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T VariantFiltration \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-V "$RunID"_INDELs.vcf \
-L "$BEDFilename" \
-o "$RunID"_INDELs_Filtered.vcf \
--filterExpression "QD < 2.0" \
--filterName "LowQD" \
--filterExpression "FS > 200.0" \
--filterName "SB" \
--filterExpression "ReadPosRankSum < -20.0" \
--filterName "ReadPosRankSum" \
-dt NONE

#combine filtered variants
java -Xmx2000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T CombineVariants \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-o "$RunID"_Filtered.vcf \
--variant "$RunID"_SNPs_Filtered.vcf \
--variant "$RunID"_INDELs_Filtered.vcf \
-dt NONE

#Annotate VCF using SNPEff4
java -Xmx4000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/snpEff_4E/snpEff.jar eff \
-v GRCh37.75 \
-noStats \
-no-downstream \
-no-intergenic \
-no-upstream \
-spliceSiteSize 10 \
-onlyTr "$PreferredTranscriptsFile" \
-noLog \
"$RunID"_Filtered.vcf > "$RunID"_Filtered_Annotated.vcf

#calculate coverage
samtools depth -b "$BEDFilename" -q 20 -Q 40 -f BAMsforDepthAnalysis.list > "$RunID"_Coverage.txt

#write finish flag for download
echo > complete

#Set permissions for WCEP 
chgrp -c wcep . ; chgrp -Rc wcep * ; chmod -c g+rwX . ; chmod -Rc g+rwX *
