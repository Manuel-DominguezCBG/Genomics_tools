# Checks if a given folder is likely a WRGL run
# This won't be foolproof, but it should be good
# enough to avoid e.g. running reset_run in the
# main WRGL folder.

testfolder="$1"

>&2 echo INFO: Testing folder "$1"

# Is this even a folder that exists?
if [ ! -d "$testfolder" ]; then
    >&2 echo ERROR: Does not appear to be a folder or does not exist
    exit 1
fi

# Check for indicators of a COMPLETE run
completefile=$( find "$testfolder" -mindepth 1 -maxdepth 1 -name "complete" | head -1 )
# In the very unlikely chance there are multiple annotated vcfs take the first one
vcffile=$( find "$testfolder" -mindepth 1 -maxdepth 1 -name "*_Filtered_Annotated.vcf" | head -1 )
# Check for config files
# count fastqs
fastqs=$( find "$testfolder" -mindepth 2 -maxdepth 2 -name "*.fastq.gz" | wc -l )

if [ -f "$completefile" ] && [ -f "$vcffile" ] && [ "$fastqs" -gt 1 ]; then
    >&2 echo INFO: looks like a complete run
    exit 0
elif [ "$fastqs" -gt 1 ]; then
    >&2 echo INFO: Might not be a complete run but does have fastq files
    exit 0
else
    >&2 echo WARNING: This doesnt look like a run folder
    exit 1
fi

