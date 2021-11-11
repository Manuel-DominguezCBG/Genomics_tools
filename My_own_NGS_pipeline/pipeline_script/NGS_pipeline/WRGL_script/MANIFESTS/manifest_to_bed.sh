#!/bin/bash -e

###
#
# Converts Illumina manifest file into BED file suitable for use in CEP pipeline
#
###

# check manifest file is included
if [ $# -ne 1 ]; then
	echo "ERROR: No manifest filename given"
	echo "USAGE: manifest_to_bed.sh <manifest file name>"
	exit 1
fi

# check manifest file can be opened
if [ -f "$1" ]; then
	manifest=$1
else
	echo "ERROR: Specified manifest file could not be opened"
	echo "USAGE: manifest_to_bed.sh <manifest file name>"
fi

bedname=$( basename "$manifest" ".txt" ).bed

echo "$bedname"

# grep to remove any comment lines
# remove rs targets
# rearrange columns
# remove "chr" prefix, and convert X & Y to numbers for sorting
# sort by chrom, start, then end
# revert back to X & Y
grep -v "^#" "$manifest" | \
grep -v "rs" | \
awk 'BEGIN{FS="\t"; OFS="\t"}{print $2,$3,$4,$1}' | \
sed -e s/"^chr"/""/g -e s/"^X"/"23"/g -e s/"^Y"/"24"/g -e s/".chr"/"_"/g | \
sort -k1n -k2n -k3n | \
sed -e s/"^23"/"X"/g -e s/"^24"/"Y"/g > "$bedname"
