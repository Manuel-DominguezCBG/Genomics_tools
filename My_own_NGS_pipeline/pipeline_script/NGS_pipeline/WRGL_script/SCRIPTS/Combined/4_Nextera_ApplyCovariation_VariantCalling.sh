#!/bin/bash -e

#PBS -W umask=002
#PBS -W group_list=wrgl

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

# Load pipeline settings - load before variables and any duplicate valures
#                          will be replaced with the variables file ones.
. *.config

# Load sample variables
. *.variables

# Apply the recalibration to your sequence data
if [ -f "$RunID"_"$Sample_ID"_realigned.bam ]; then
    java -Xmx4000m "$javatmp" -jar "$gatkpath" \
    -T PrintReads \
    -R "$refgenome" \
    -I "$RunID"_"$Sample_ID"_realigned.bam \
    -BQSR ../"$RunID"_recal_data.table \
    -L "$BEDFilename" \
    -o "$RunID"_"$Sample_ID".bam \
    -ip 100 \
    -compress 5 \
    -dt NONE

    rm "$RunID"_"$Sample_ID"_realigned.ba*
fi

# Variant calling with Haplotypecaller
java -Xmx4000m "$javatmp" -jar "$gatkpath" \
-T HaplotypeCaller \
-R "$refgenome" \
--dbsnp "$dbsnpfile" \
-I "$RunID"_"$Sample_ID".bam \
-L "$BEDFilename" \
-o "$RunID"_"$Sample_ID".vcf \
--genotyping_mode DISCOVERY \
-stand_call_conf 30 \
--emitRefConfidence BP_RESOLUTION \
--variant_index_type LINEAR \
--variant_index_parameter 128000 \
-ip 100 \
-dt NONE

# DEV: multithreading may be resulting in missed indel calls
#      so it has been temporarily disabled.
# -nct "$varprocessingppn" \

# DEV: take a copy of all sample VCFs to trial joint genotyping for a variant database (gives better negative coverage than using run VCF)
panel=$( basename $( find . -maxdepth 1 -name "*.bed" ) | cut -d "_" -f 1 )
# DEV: This is a test to see if we can successfully get the panel name.
#      Once checked, update the commands below to send ther compressed files directly
#      to a the folder for the correct panel
mkdir -p /scratch/WRGL/DEVELOPMENT/joint_genotyping/"$panel"
cat "$RunID"_"$Sample_ID".vcf | bgzip > /scratch/WRGL/DEVELOPMENT/joint_genotyping/"$panel"/"$RunID"_"$Sample_ID".vcf.gz
tabix -p vcf /scratch/WRGL/DEVELOPMENT/joint_genotyping/"$panel"/"$RunID"_"$Sample_ID".vcf.gz

# Run per-sample coverage analysis
"$scriptspath"/gvcf_coverage/gvcf_to_summary.sh "$BEDFilename" "$genomefile" "$RunID"_"$Sample_ID".vcf

# Create VCFs list for recalibration
# This should be the last thing to ensure that script 5 is only started once
find `pwd` -name "$RunID"_"$Sample_ID".vcf >> ../VCFsforFiltering.list
find `pwd` -name "$RunID"_"$Sample_ID".bam >> ../BAMsforDepthAnalysis.list

# Check if all VCFs are written
if [ ${#AnalysisDirs[@]} -eq $(wc -l ../VCFsforFiltering.list | cut -f1 -d' ') ]; then
    # Copy script 5 to the run directory (could be put into script 2 instead)
    cp 5_Nextera_VariantProcessing.sh ..
    cd ..
fi
