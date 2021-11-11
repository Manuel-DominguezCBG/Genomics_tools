# DEV: There are going to be some issues here with not being able to load the config file, unless that is uploaded.
#      However that means keeping a local copy, which means fragmentation. Perhaps this could be run by the pipeline
#      without copying in to the sample folder, and then pull the location of the scripts from the location of this script?
#      TODO: test.
installpath="$( dirname "$( dirname "$(readlink -f "$0")" )" )"

if [ -f *.variables ]; then
    . *.variables
fi
if [ ! -f *.config ]; then
    #>&2 echo ERROR: No config file detected. Cannot proceed.
    >&2 echo WARNING: No config file detected. Copying in WRGLPipeline.config default.
    cp "$installpath"/Combined/WRGLPipeline.config .
    #exit 1
fi

. *.config

# Copy in scripts - want to run this for all samples, so do before checking run is uploaded completely.

cp "$installpath"/Combined/*Nextera*.sh .

# Bed file is the last file uploaded, so if the number of bed files matches the number of samples
# we can be (almost certainly) sure the run is completely uploaded and ready for analysis.
# But we also want to be sure that the pipeline hasn't already been started (just in case).
# So don't run if the log file already exists
if [ ${#AnalysisDirs[@]} -eq $( ls -lah ../*/*.bed | wc -l ) ] && [ ! -f "$RunID".runner.log ]; then
    # Copy config file to the root run directory
    cp *.config ..

    # move up to run directory
    cd ..

    # Copy in the pipeline runner
    cp "$installdir"/SCRIPTS/Combined/pipeline_runner.sh .
    # DEV: Could copy in scripts from Iridis repo here too?

    # Create the runner.log file, so that it can be set to WRGL group and made accesible to other users
    echo "WRGL Pipeline runner log file" > "$RunID".runner.log
    echo "-----------------------------" >> "$RunID".runner.log

    chgrp wrgl "$RunID".runner.log
    chmod 770 "$RunID".runner.log

    # Start the pipeline runner with nohup - so it will continue to run once connection from
    # miseq PC closes. Pipe the output to a local file, rather than just nohup.out - redirect
    # both output streams.
    nohup pipeline_runner.sh &>> "$RunID".runner.log &
    # Save the pid in case we need to kill the nohup job
    echo $! > pipeline_runner.pid

    echo -e $( date )"\t"INFO: "$RunID": Pipeline started. View runner.log file for progress details.
fi
