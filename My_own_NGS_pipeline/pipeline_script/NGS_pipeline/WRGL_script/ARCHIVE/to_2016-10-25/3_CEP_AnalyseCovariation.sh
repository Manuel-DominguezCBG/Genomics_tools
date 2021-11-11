#!/bin/bash
#PBS -l walltime=60:00:00
#PBS -l nodes=1:ppn=4
#PBS -l mem=8000mb
#PBS -W umask=0007
cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Status: Dev
#Updated: 30 November 2015, Ben Sanders
#Update note: Added umask to PBS settings, to allow multiple users to access output.
#Updated: 21 Jan 2016, Reuben Pengelly
#Update note: adjusted PBS parameters
#Mode: BY_LANE

module load jdk/1.7.0
module load R/3.0.2

#load sample variables
. *.variables

#Analyze patterns of covariation in the sequence dataset
java -Xmx8000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T BaseRecalibrator \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-knownSites /scratch/WRGL/bundle2.8/b37/dbsnp_138.b37.vcf \
-knownSites /scratch/WRGL/bundle2.8/b37/1000G_phase1.indels.b37.vcf \
-knownSites /scratch/WRGL/bundle2.8/b37/Mills_and_1000G_gold_standard.indels.b37.vcf \
-I BAMsforBQSR.list \
-L "$BEDFilename" \
-o "$RunID"_recal_data.table \
-ip 100 \
-nct 4 \
-dt NONE

#Do a second pass to analyze covariation remaining after recalibration
java -Xmx8000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T BaseRecalibrator \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-knownSites /scratch/WRGL/bundle2.8/b37/dbsnp_138.b37.vcf \
-knownSites /scratch/WRGL/bundle2.8/b37/1000G_phase1.indels.b37.vcf \
-knownSites /scratch/WRGL/bundle2.8/b37/Mills_and_1000G_gold_standard.indels.b37.vcf \
-BQSR "$RunID"_recal_data.table \
-I BAMsforBQSR.list \
-L "$BEDFilename" \
-o "$RunID"_post_recal_data.table \
-ip 100 \
-dt NONE \
-nct 4

#Generate before/after plots
java -Xmx4000m -Djava.io.tmpdir=/scratch/WRGL/JavaTmp -jar /scratch/WRGL/software/GenomeAnalysisTK-3.2-2/GenomeAnalysisTK.jar \
-T AnalyzeCovariates \
-R /scratch/WRGL/bundle2.8/b37/human_g1k_v37.fasta \
-before "$RunID"_recal_data.table \
-after "$RunID"_post_recal_data.table \
-plots "$RunID"_recalibration_plots.pdf \
-L "$BEDFilename" \
-ip 100 \
-dt NONE

#Proceed with per-sample recalibration
for i in "${AnalysisDirs[@]}"
do
    cd "$i"
    qsub 4_CEP_ApplyCovariation_VariantCalling.sh
done
