#!/bin/bash -e

#PBS -l walltime=02:00:00
#PBS -l nodes=1:ppn=1
#PBS -l mem=4000mb
#PBS -W umask=0007

cd $PBS_O_WORKDIR

##
## For processing WCEP runs to move samples to WRGL low throughput service.
## * Requires a samplesheet with the samples of interest (which is also needed locally, on the MiSeq, for GetData)
## * Requires a list of genes, to generate ROI bed file (should check that these are present on the capture kit, and use the same symbols)
## VCF and Coverage files are split by sample, then limited to genes of interest only
## VCF is then filtered against list of variants at >=2% AF in ExAC to remove common polys.
## Files are moved to WRGL folder and formatted ready for GetData download through MiSeq pipeline.
##

#####
#
# SECTION 1: INITIAL SETUP
#
#####

# load variables file.
. *.variables
. *.config

# set up script variables
wrglpath=/scratch/WRGL
wceppath=/scratch/WCEP/Phase_2
wrglfolder="$wrglpath"/"$RunID"
genelist=gene_list.txt
runbed="$wrglfolder"/"$RunID"_ROIs.bed
runvcf="$RunID"_Filtered.vcf
# create run folder in WRGL and copy files over
mkdir -p "$wrglfolder"
echo "WRGL run folder made"

#####
#
# SECTION 2: PREPARE REQUIRED FILES
#
#####

# need to make BED file for the run
# folder should have a gene list

# Gene list may be mix of comma delimited and new lines
# Replace all commas with newlines
# want to remove spaces too, in case of comma-space separation?
cat "$genelist" | sed s/","/"\n"/g | sed s/"\t"/"\n"/g | sort -u > "$wrglfolder"/"$RunID"_gene_list.txt

echo "gene list processed"

# Now lookup genes in TSO bed file (with names)
while read p; do
        grep "\b${p}_" "$bedpath"/"$targetbed" >> "$runbed".unsorted
done < "$wrglfolder"/"$RunID"_gene_list.txt

echo "unsorted list made"

# sort the bed file. Should be sorted already, but doesn't seem to be for some reason.
cat "$runbed".unsorted | sort -u -k1,1V -k2,2n > "$runbed"

echo "ROIs for gene list found. BED file created"

#####
#
# SECTION 3: PROCESS FILES AND MOVE TO WRGL
#
#####

# intersect VCF
# -u flag prevents duplicate variants where bed regions overlap
# The Filtered file has already been normalised, so this doesn't need to be done here
bedtools intersect -header -u -a "$runvcf" -b "$runbed" > "$wrglfolder"/"$RunID"_Filtered.vcf

java -Xmx4000m "$javatmp" -jar "$snpeffpath" \
eff \
-v "$snpeffdb" \
-noStats \
-no-downstream \
-no-intergenic \
-no-upstream \
-spliceSiteSize 10 \
-onlyTr PreferredTranscripts.txt \
-noLog \
-formatEff \
"$wrglfolder"/"$RunID"_Filtered.vcf > "$wrglfolder"/"$RunID"_Annotated.vcf

# remove variants with AC=0 (i.e. no variants called in these samples)
grep -v "AC=0" "$wrglfolder"/"$RunID"_Annotated.vcf > "$wrglfolder"/"$RunID"_Filtered_Annotated.vcf

# Use the new coverage output - this is backwards compatible!
# For some reason there are duplicate entries even when using bedtools -u
# so I've had to add a call to uniq. This doesn't add much time
# NOTE: This appears to have an awk "pipe broken" error, that only occurs
#       while running through qsub. Output has been checked and is complete.
awk 'BEGIN{FS="\t"}{printf "%s\t%d\t%d\t%d",$1,$2-1,$2,$3;for (i=4;i<=NF;i+=1){printf ",%d",$i;} print ""}' "$RunID"_Coverage.txt | \
bedtools intersect -u -g "$genomefile" -sorted -a stdin -b "$runbed" | \
cut -f 1,3,4 | \
uniq | \
sed s/","/"\t"/g > "$wrglfolder"/"$RunID"_Coverage.txt

echo "large files processed"

# smaller files can be copied without processing
cp complete BAMsforDepthAnalysis.list PreferredTranscripts.txt *.bed *.sh *.sh.* *.csv *.config "$wrglfolder"

# prep a folder with files needed for local download
mkdir -p "$wrglfolder"/for_download
echo "$runID" > "$wrglfolder"/for_download/runID.txt
cp "$runID".csv  "$wrglfolder"/for_download/"$runID".csv
cp "$runbed"  "$wrglfolder"/for_download/"$RunID"_ROIs.bed
# Copy through the coverage summaries - this should be zipped by the analysis script now
cp "$runID"_genecoverage.zip "$wrglfolder"
#zip -j "$wrglfolder"/"$runID"_genecoverage.zip */*.summary.txt

# copy sample folders and output files

while read p; do
	mkdir -p "$wrglfolder"/"$p"
	cp "$p"/*.sh.* "$wrglfolder"/"$p"
    # DEV: If downloading BAMs through the pipeline, will need to add
    #      an empty placeholder here as exome BAMs are too big to be practical
    #TODO
done < IDs.txt

echo "small files processed"

# chmod and chgrp the files as needed
chmod -R 770 "$wrglfolder"
chgrp -R wrgl "$wrglfolder"

echo "complete"

#####
#
# SECTION 4: TIDY TEMP FILES
#
#####

rm "$runbed".unsorted "$wrglfolder"/"$RunID"_Annotated.vcf

chmod -R 770 "$wrglfolder"
chgrp -R wrgl "$wrglfolder"
