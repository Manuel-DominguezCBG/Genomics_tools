installpath="$( dirname "$( dirname "$(readlink -f "$0")" )" )"

# Check the current folder is a valid run (or as good as we can tell)
"$installpath"/aux_scripts/aux6_Check_Is_Run.sh "$PWD"

if [ "$?" -eq 0 ]; then
    >&2 echo INFO: Folder OK. Continuing.
else
    >&2 echo INFO: Folder doenst pass run test
    exit 1
fi

# Reset the run in the current folder
"$installpath"/aux_scripts/aux5_Reset_Run.sh

# Run aux0_Start_Pipeline.sh in each folder
# This starts the main analysis pipeline when the number
# of bed files matches the number of samples, so we have
# to rename the existing BED file to avoid this

# PreferredTranscripts *might* be missings
if [ ! -f PreferredTranscripts.txt ]; then
    >&2 echo INFO: PreferredTranscripts file not found - copying in default
    cp "$installpath"/PreferredTranscripts_v2.txt PreferredTranscripts.txt
fi

# Rename BED file in all folders
for p in $( find . -mindepth 1 -maxdepth 1 -type d ); do
    cd "$p"
    # First get the name of the file
    bedname=$( find . -name "*.bed" -exec basename {} .bed \; )
    # Now move BED to BED2
    mv "$bedname".bed "$bedname".bed2
    cd ..
done

# Now change name *back*, and run aux0_Start_Pipeine.sh
# This will ensure that the actual pipeline will only run
# when we reach the last sample - as it is supposed to go
for p in $( find . -mindepth 1 -maxdepth 1 -type d ); do
    cd "$p"
    # First get the name of the file
    bedname=$( find . -name "*.bed2" -exec basename {} .bed2 \; )
    # Now move BED to BED2
    mv "$bedname".bed2 "$bedname".bed

    # Start the pipeline
    "$installpath"/aux_scripts/aux0_Start_Pipeline.sh

    cd ..
done

