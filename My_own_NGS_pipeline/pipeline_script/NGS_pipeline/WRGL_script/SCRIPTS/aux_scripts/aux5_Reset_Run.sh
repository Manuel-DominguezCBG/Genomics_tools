RunID=$( basename "$PWD" )

>&2 echo INFO: Resetting run "$RunID"

# Remove files from the run-level folder
>&2 echo INFO: Tidying run-level folder...
rm -f *.sh
rm -f *.sh.*
rm -f -rf "$RunID"_GenomicsDB
rm -f *"$RunID"*
rm -f VCFs_For_Merging.map
rm -f *.variables
rm -f *.config
rm -f sample-names.args
rm -f *.list
rm -f complete
rm -f qc.log

# Clear the sample-level folders
>&2 echo INFO: Clearing sample folders...
rm -f */*.sh.*
rm -f */*.sh
rm -f */*/config
rm -f */*"$RunID"*
rm -f */*.QCmetrics.txt
rm -f */*.interval_list
rm -f */*_VerifyBamId*

# Get the path to the folder with the latest scripts
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Putting scripts back in (from latest version)
# This is in place of the files that would be uploaded by the MiSeq
>&2 echo INFO: Copying script files to sample folders...
for p in $( find . -mindepth 1 -maxdepth 1 -type d ); do
    cd "$p"
#    cp "$DIR"/aux0_Start_Pipeline.sh .
#    cp "$DIR"/../Combined/*Nextera*.sh .
    cp "$DIR"/../Combined/WRGLPipeline.config .

    cd ..
done

# Update variables files with new run location
>&2 echo INFO: Regenerating variables file for current location
"$DIR"/../aux_scripts/aux1_CEP_make_variables.sh

# Delete bed file from root after creating variables
# this should be kept in the sample level folders though
rm -f *.bed
