#!/usr/bin/env bash
set -e

#PBS -W umask=002
#PBS -W group_list=wrgl

cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Maintainer: ben.sanders@salisbury.nhs.uk
#Status: Release
#Updated 18 May 2017, Ben Sanders
#Update note: Changed version of SNPEff to v4.3
#Updated 07 March 2018, Ben Sanders
#Update note: Moved normalise step to avoid MIXED filering bug
#Updated 08 May 2018, Ben Sanders
#Update note: Created config file with params and paths for all scripts
#Mode: BY_COHORT

# Load pipeline settings - load before variables and any duplicate valures
#                          will be replaced with the variables file ones.
. *.config

# Load sample variables
. *.variables

# Merge calls from HC VCFs
java -Xmx4000m "$javatmp" -jar "$gatkpath" \
-T GenotypeGVCFs \
-R "$refgenome" \
--dbsnp "$dbsnpfile" \
-V VCFsforFiltering.list \
-L "$BEDFilename" \
-ip 100 \
-o "$RunID".vcf \
-nt "$varprocessingppn" \
-dt NONE

# Extract SNPs
java -Xmx8000m "$javatmp" -jar "$gatkpath" \
-T SelectVariants \
-R "$refgenome" \
-V "$RunID".vcf \
-L "$BEDFilename" \
-ip 100 \
-o "$RunID"_SNPs.vcf \
-selectType SNP \
-dt NONE

# Filter SNPs
java -Xmx2000m "$javatmp" -jar "$gatkpath" \
-T VariantFiltration \
-R "$refgenome" \
-V "$RunID"_SNPs.vcf \
-L "$BEDFilename" \
-ip 100 \
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

# Extract INDELs
java -Xmx2000m "$javatmp" -jar "$gatkpath" \
-T SelectVariants \
-R "$refgenome" \
-V "$RunID".vcf \
-L "$BEDFilename" \
-ip 100 \
-o "$RunID"_INDELs.vcf \
-selectType INDEL \
-dt NONE

# Filter INDELs
java -Xmx2000m "$javatmp" -jar "$gatkpath" \
-T VariantFiltration \
-R "$refgenome" \
-V "$RunID"_INDELs.vcf \
-L "$BEDFilename" \
-ip 100 \
-o "$RunID"_INDELs_Filtered.vcf \
--filterExpression "QD < 2.0" \
--filterName "LowQD" \
--filterExpression "FS > 200.0" \
--filterName "SB" \
--filterExpression "ReadPosRankSum < -20.0" \
--filterName "ReadPosRankSum" \
-dt NONE

# Extract MIXED
java -Xmx2000m "$javatmp" -jar "$gatkpath" \
-T SelectVariants \
-R "$refgenome" \
-V "$RunID".vcf \
-L "$BEDFilename" \
-ip 100 \
-o "$RunID"_MIXED.vcf \
-selectType MIXED \
-dt NONE

# Filter MIXED
java -Xmx2000m "$javatmp" -jar "$gatkpath" \
-T VariantFiltration \
-R "$refgenome" \
-V "$RunID"_MIXED.vcf \
-L "$BEDFilename" \
-ip 100 \
-o "$RunID"_MIXED_Filtered.vcf \
--filterExpression "QD < 2.0" \
--filterName "LowQD" \
--filterExpression "FS > 60.0" \
--filterName "SB" \
-dt NONE

# Combine filtered variants
# NOTE: genotypemergeoption UNSORTED is a new requirement in v3.7, to match the default behaviour of v3.2
java -Xmx2000m "$javatmp" -jar "$gatkpath" \
-T CombineVariants \
-R "$refgenome" \
-o "$RunID"_Combined.vcf \
--variant "$RunID"_SNPs_Filtered.vcf \
--variant "$RunID"_INDELs_Filtered.vcf \
--variant "$RunID"_MIXED_Filtered.vcf \
-dt NONE \
--genotypemergeoption UNSORTED

# Split multiallelic variants and normalise
bcftools norm -f "$refgenome" -m -any -O v -o "$RunID"_preNormalised.vcf "$RunID"_Combined.vcf
bcftools norm -f "$refgenome" -m -any -O v -o "$RunID"_Filtered.vcf "$RunID"_preNormalised.vcf

# Change 1/0 variant calls to 0/1
# NOTE: this may not be necessary for exoems, but if being pulled back for low-throughput analysis it will help with reporting module
sed -i s/"1\/0"/"0\/1"/g "$RunID"_Filtered.vcf

# Set ./. genotypes to 0/0, again for low-throughput compatibility
sed -i s/"\.\/\."/"0\/0"/g "$RunID"_Filtered.vcf

# bcftools can replace NaN ("Not a Number" a valid Java numeric value) with nan (which isn't)
# Replace to prevent downstream processing errors.
sed -i s/"nan"/"NaN"/g "$RunID"_Filtered.vcf

# Use bedtools to cut down to reporting ROI from the +-100bp padded intervals used during analysis
# Use of -wa flag should include overlapping variants
# Other possibility is to use vcftools instead
bedtools intersect \
-a "$RunID"_Filtered.vcf \
-b "$BEDFilename" \
-wa \
-header \
-u > "$RunID"_Filtered_trimmed.vcf

# Annotate VCF using SNPEff4.3
java -Xmx4000m "$javatmp" -jar "$snpeffpath" \
eff \
-v "$snpeffdb" \
-noStats \
-no-downstream \
-no-intergenic \
-no-upstream \
-no INTRAGENIC \
-spliceSiteSize 10 \
-onlyTr "$PreferredTranscriptsFile" \
-noLog \
-formatEff \
"$RunID"_Filtered_trimmed.vcf > "$RunID"_Filtered_SNPEff.vcf

# Add REVEL score
>&2 echo INFO: Adding REVEL scores to "$RunID"_Filtered_SNPEff.vcf...
vep \
 --cache \
 --dir_cache /scratch/WRGL/.vep \
 --dir_plugins /scratch/WRGL/.vep/Plugins \
 --species homo_sapiens \
 --merged \
 --assembly GRCh37 \
 --format vcf \
 --vcf \
 --force_overwrite \
 --plugin REVEL,/scratch/WRGL/.vep/Plugins/new_tabbed_revel.tsv.gz \
 --use_given_ref \
 --no_stats \
 --fork 8 \
 --offline \
 --fasta /scratch/WRGL/REFERENCE_FILES/REFERENCE_GENOME/GRCh37/GRCh37_no_gl000201.fa \
 --exclude_predicted \
 --input_file "$RunID"_Filtered_SNPEff.vcf \
 --output_file TEMP."$RunID"_Filtered_REVEL.vcf

# Extract the REVEL score from the VEP CSQ field, and put it into its own INFO field
# i.e. REVEL=
"$auxdir"/aux8_Extract_Revel_Scores.py TEMP."$RunID"_Filtered_REVEL.vcf > "$RunID"_Filtered_Annotated.vcf

# Tidy up REVEL temp files
rm TEMP."$RunID"_Filtered_REVEL.vcf

# create a BAMsforDepthAnalysis.list with the same order as the coverage file
find $( pwd ) -name "*.coverage.txt" | sed s/".coverage.txt"/".bam"/g > BAMsforDepthAnalysis.list

# Collate individual sample coverage files
# Use BAMsforDepthAnalysis to ensure they are in the right
# order for downstream analysis
# Merges the files and prints the chr + pos columns, then the 3rd depth column from each
paste $( find $( pwd ) -name "*.coverage.txt" ) | \
awk '{printf "%s\t%s",$1,$2;for (i=3;i<=NF+1;i+=3){printf "\t%s",$i;} print ""}' > "$RunID"_Coverage.txt

# If running a WRGL2 panel, we want to use a transcript-specific coverage BED file
# Otherwise, we just want to use the standard BED file.
# Check the first part of the BED file being used - if it's WRGL2 then don't do anything - the
# coverage file is defined in the config file. Otherwise (for any other panel), set coveragebed to
# the general run BED file, as it is already specific enough.
if [[ $( echo "$BEDFilename" | cut -d "_" -f 1 ) != "WRGL2" ]]; then
    >&2 echo INFO: Not using WRGL2, coverage bed can be set to run bed file.
    coveragebed="$BEDFilename"
fi

# Run coverage analysis on the transcript specific bed file
"$scriptspath"/coverage_integrated/coverage "$coveragebed" "$RunID"_Coverage.txt

# Write finish flag for download
echo > complete

# chmod everything again, so that all created files are acessible
chmod -f -R 770 .
chgrp -f -R wrgl .
