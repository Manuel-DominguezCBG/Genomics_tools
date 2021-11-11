#!/bin/bash

# DEV: debug options - ignore certain errors if using ShellCheck for linting
# shellcheck disable=SC1090
# shellcheck disable=SC1091
# shellcheck disable=SC2140
# shellcheck disable=SC2154

# This should (hopefully) run and monitor running of the WRGL2 pipeline.
# It doesn't need to be a complex, general system for running scripts - it
# is exclusively for our needs.

# Scripts and config files are already in the sample folders from upload
# Is it worth checking this first?

###########################
#
# Check queue status of job
# =========================

## Checks qstat to get the queue status of the specified job ID (i.e. Q, R, or C)
## When complete, checks the exit status of the script, which should be 0 if it
## completed fully.
## Returns a code based on status.

getqueuestatus() {
    jobid="$1"
    # qstat -f outut includes some whitespace, which we remove with sed
    queuestatus=$( qstat -f "$jobid" | grep "job_state" | cut -d "=" -f 2 | sed 's/^[ \t]*//;s/[ \t]*$//' )

    # Bash functions can only return a numeric value
    # So we have to decide on some coded values
    #   0 - complete (because 0 is the bash standard for completed without errors)
    #   1 - queued
    #   2 - running
    #   3 - ERROR (-1 is apparently invalid for bash return value)
    if [ "$queuestatus" = "C" ]; then
        # Check exit status of complete job - should be 0 if no errors
        exitstatus=$( qstat -f "$jobid" | grep exit_status | cut -d "=" -f 2 | sed 's/^[ \t]*//;s/[ \t]*$//' )
        if [ "$exitstatus" -eq "0" ]; then
            return 0
        else
            return 3
        fi
    fi

    if [ "$queuestatus" = "Q" ]; then
        return 1
    else
        # = "R"
        return 2
    fi
}

####################################
#
# Monitor a job until it is complete
# ==================================

## Persistently monitors the queue status of a given Job ID
## Every 10 seconds (might increase this) uses getqueuestatus() to poll qstat
## until job status is complete (either 0 (success) or -1 (error) returned)
## Returns 0 if apparently succesful, or -1 otherwise.
## Prints a message to stderr when the queue status of the monitored job has changed.

monitorqueue() {
    jobid="$1"
    RunID="$2"
    sampleid="$3"

    # initial state will always be Q for queued
    queuestatus=1
    laststatus="$queuestatus"

    # Check until a complete status is received
    # Complete = 0, complete with errors = -1
    while [ "$queuestatus" -ne 0 ] && [ "$queuestatus" -ne 3 ] ; do
        # Wait 2 minutes seconds between checks
        sleep 120

        # We have to use $? to get the return status
        getqueuestatus "$jobid"
        queuestatus="$?"

        # Check for a change in queue status and print
        if [ "$queuestatus" -ne "$laststatus" ]; then
            status=$( qstat -f "$jobid" | grep "job_state" | cut -d "=" -f 2 | sed 's/^[ \t]*//;s/[ \t]*$//' )
            >&2 echo -e "$( date )""\t"INFO: "$RunID" "$sampleid": Queue status has changed: "$status"
            laststatus="$queuestatus"
        fi
    done

    # Check the error status
    if [ "$queuestatus" -eq 0 ]; then
        # Job has completed with no errors
        return 0
    else
        # Return -1 if an error seems to have happened
        return 3
    fi
}

#########################
#
# bcl2fastq (exomes only)
# =======================

## Exome runs from the NextSeq don't have fastq files by default, so
## we must run bcl2fastq to generate them prior to analysis

bcl2fastq() {
    # Check that the required files which indicate an exome run are present
    if [ -f 0_WCEP_bcl2fastq.sh ]; then
        hascsv=false
        for file in *.csv; do
            if [ -e "$file" ]; then
                hascsv=true
            fi
        done
        if [ "$hascsv" = true ]; then
        # Just as a double check (because that could have been copied in by mistake e.g. *.sh)
        # exomes also require a samplesheet.csv (which regular panels don't upload)
            ## *triple* check (as this is a very time consuming process) that there are no fastq files
            hasfastqs=false
            for file in */*.fastq.gz; do
                if [ -e "$file" ]; then
                    hasfastqs=true
                fi
            done
            if [ "$hasfastqs" = false ]; then
                # Use the folder name as the run id for this step - it should be correct
                RunID="$( basename "$PWD")"

                >&2 echo -e "$( date )""\t"INFO: "$RunID": Detected as an exome run. Starting bcl2fastq.

                # And submit (bcl2fastq has resource requests specified in the script)
                jobid=$( qsub 0_WCEP_bcl2fastq.sh )
                >&2 echo -e "$( date )""\t"INFO: "$RunID": bcl2fastq job started with ID "$jobid"

                # Monitor this new job
                monitorqueue "$jobid" "$RunID"
                exitstatus="$?"
                if [ "$exitstatus" -ne 0 ]; then
                    >&2 echo -e "$( date )""\t"ERROR: "$RunID": An error occurred while running bcl2fastq.
                    exit 3
                fi

                >&2 echo -e "$( date )""\t"INFO: "$RunID": bcl2fastq completed successfully.

                # Use a return so we avoid the end of this function where we are reporting an error
                return 0
            fi
        fi
    fi

    # Quit, as this folder cannot be analysed.
    >&2 echo -e "$( date )""\t"ERROR: "$( basename "$PWD" )": Folder does not appear to be a valid run.
    exit 1
}

##################################
#
# Align read (for a single sample)
# ================================

## Runs the alignment task for a single sample, starting the job with the appropriate qsub command
## If sample appears to have failed, repeats with more walltime before returning an error code if
## that also fails.

alignreads() {
    sampleid="$1"
    RunID="$2"

    # Load sample specific details
    cd "$sampleid"
    . ./*.variables
    . ./*.config

    # Check target script exists
    if [ ! -f "$alignmentscript" ]; then
        >&2 echo -e "$( date )""\t"ERROR: Script "$alignmentscript" could not be found.
        exit 3
    fi

    # Submit alignment job
    jobid=$( qsub -l walltime="$alignmentwtime",nodes="$alignmentnodes":ppn="$alignmentppn",mem="$alignmentmem" "$alignmentscript" )
    >&2 echo -e "$( date )""\t"INFO: "$RunID" "$sampleid": Alignment job started with ID "$jobid"

    # Monitor this job
    monitorqueue "$jobid" "$RunID" "$sampleid"
    exitstatus="$?"

    # The most common failure with a previously working pipeline is reaching the walltime limit
    # Therefore, if the job fails, try resubmitting.
    # Increasing walltime is a bit tricky because of the formatting, but since previous steps before
    # the point of failure will be skipped, we can just resubmit with the same time and effectively
    # gain extra runtime.
    # If queue monitor returns -1, repeat submission.
    # Only repeat once, then flag the error
    if [ "$exitstatus" -ne 0 ]; then
        >&2 echo -e "$( date )""\t"WARNING: "$RunID" "$sampleid": Alignment did not complete successfully. Resbumitting job.
        # Resubmit the job
        jobid=$( qsub -l walltime="$alignmentwtime",nodes="$alignmentnodes":ppn="$alignmentppn",mem="$alignmentmem" "$alignmentscript" )
        >&2 echo -e "$( date )""\t"INFO: "$RunID" "$sampleid": Alignment job started with ID "$jobid"

        # Monitor this new job
        monitorqueue "$jobid" "$RunID" "$sampleid"
        exitstatus="$?"
        if [ "$exitstatus" -ne 0 ]; then
            >&2 echo -e "$( date )""\t"ERROR: "$RunID" "$sampleid": An error occurred while aligning this sample.
        fi
    fi

    >&2 echo -e "$( date )""\t"INFO: "$RunID" "$sampleid": Alignment completed successfully.
}

#####################################
#
# Analyse covariation (for whole run)
# ===================================

## Checks that previous steps are all complete, then covariation analysis

covariation() {
    RunID="$1"

    . ./*.config

    # Check length of sample map file to ensure all samples completed alignment successfully
    # First, ensure the file exists
    if [ ! -f BAMsforBQSR.list  ]; then
        >&2 echo -e "$( date )""\t"ERROR: "$RunID": BAMsforBQSR.list  not found. Cannot proceed.
        exit 3
    fi
    # Now work out the length and compare to number of samples expected
    completedsamples=$( wc -l BAMsforBQSR.list  | cut -d " " -f1 )
    if [ ${#AnalysisDirs[@]} -ne "$completedsamples" ]; then
        >&2 echo -e "$( date )""\t"ERROR: "$RunID": Not all samples have aligned correctly. Cannot proceed.
        exit 3
    fi

    # Check target script exists
    if [ ! -f "$analysecovariationscript"  ]; then
        >&2 echo -e "$( date )""\t"ERROR: Script "$analysecovariationscript"  could not be found. Cannot proceed.
        exit 3
    fi

    # And submit
    jobid=$( qsub -l walltime="$analysecovariationwtime",nodes="$analysecovariationnodes":ppn="$analysecovariationppn",mem="$analysecovariationmem" "$analysecovariationscript" )
    >&2 echo -e "$( date )""\t"INFO: "$RunID": Genotyping job started with ID "$jobid"

    # Monitor this new job
    monitorqueue "$jobid" "$RunID"
    exitstatus="$?"
    if [ "$exitstatus" -ne 0 ]; then
        >&2 echo -e "$( date )""\t"ERROR: "$RunID": An error occurred while analysing covariation.
        exit 3
    fi

    >&2 echo -e "$( date )""\t"INFO: "$RunID": Covariation analysis completed successfully.
}

#######################################
#
# Variant calling (for a single sample)
# =====================================

## Runs the variant caller

variantcaller() {
    sampleid="$1"
    RunID="$2"

    # Load sample specific details
    cd "$sampleid"
    . ./*.variables
    . ./*.config

    # Check target script exists
    if [ ! -f "$variantcallerscript" ]; then
        >&2 echo -e "$( date )""\t"ERROR: Script "$variantcallerscript" could not be found.
        exit 3
    fi

    # Submit alignment job
    jobid=$( qsub -l walltime="$variantcallerwtime",nodes="$variantcallernodes":ppn="$variantcallerppn",mem="$variantcallermem" "$variantcallerscript" )
    >&2 echo -e "$( date )""\t"INFO: "$RunID" "$sampleid": Variant calling job started with ID "$jobid"

    # Monitor this job
    monitorqueue "$jobid" "$RunID" "$sampleid"
    exitstatus="$?"

    # The most common failure with a previously working pipeline is reaching the walltime limit
    # Therefore, if the job fails, try resubmitting.
    # Increasing walltime is a bit tricky because of the formatting, but since previous steps before
    # the point of failure will be skipped, we can just resubmit with the same time and effectively
    # gain extra runtime.
    # If queue monitor returns -1, repeat submission.
    # Only repeat once, then flag the error
    if [ "$exitstatus" -ne 0 ]; then
        >&2 echo -e "$( date )""\t"WARNING: "$RunID" "$sampleid": Post-alignment processing did not complete successfully. Resbumitting job.
        # Resubmit the job
        jobid=$( qsub -l walltime="$variantcallerwtime",nodes="$variantcallernodes":ppn="$variantcallerppn",mem="$variantcallermem" "$variantcallerscript" )
        >&2 echo -e "$( date )""\t"INFO: "$RunID" "$sampleid": Variant calling job started with ID "$jobid"

        # Monitor this new job
        monitorqueue "$jobid" "$RunID" "$sampleid"
        exitstatus="$?"
        if [ "$exitstatus" -ne 0 ]; then
            >&2 echo -e "$( date )""\t"ERROR: "$RunID" "$sampleid": An error occurred while calling variants in this sample.
        fi
    fi

    >&2 echo -e "$( date )""\t"INFO: "$RunID" "$sampleid": Variant calling completed successfully.
}

#################################
#
# Filter variants (for whole run)
# ===============================

## Checks that previous steps are all complete, then covariation analysis

varfiltration() {
    RunID="$1"

    . ./*.config

    # Check length of sample map file to ensure all samples completed alignment successfully
    # First, ensure the file exists
    if [ ! -f VCFsforFiltering.list  ]; then
        >&2 echo -e "$( date )""\t"ERROR: "$RunID": VCFsforFiltering.list  not found. Cannot proceed.
        exit 3
    fi
    # Now work out the length and compare to number of samples expected
    completedsamples=$( wc -l VCFsforFiltering.list  | cut -d " " -f1 )
    if [ ${#AnalysisDirs[@]} -ne "$completedsamples" ]; then
        >&2 echo -e "$( date )""\t"ERROR: "$RunID": Not all samples have aligned correctly. Cannot proceed.
        exit 3
    fi

    # Check target script exists
    if [ ! -f "$varprocessingscript"  ]; then
        >&2 echo -e "$( date )""\t"ERROR: Script "$varprocessingscript"  could not be found. Cannot proceed.
        exit 3
    fi

    # And submit
    jobid=$( qsub -l walltime="$varprocessingwtime",nodes="$varprocessingnodes":ppn="$varprocessingppn",mem="$varprocessingmem" "$varprocessingscript" )
    >&2 echo -e "$( date )""\t"INFO: "$RunID": Genotyping job started with ID "$jobid"

    # Monitor this new job
    monitorqueue "$jobid" "$RunID"
    exitstatus="$?"
    if [ "$exitstatus" -ne 0 ]; then
        >&2 echo -e "$( date )""\t"ERROR: "$RunID": An error occurred while processing variants.
        exit 3
    fi

    >&2 echo -e "$( date )""\t"INFO: "$RunID": Variant processing completed successfully.
}

###############
#
# Run QC script
# =============

qcscript(){
    RunID="$1"
    # Do post-run QC
    # This can happily go while the run is downloading, as it's only
    # sent to a database on Iridis
    # If that changes (e.g. to generate a PDF QC report for download)
    # just shift the above `echo > complete` to the end of the qc script

    # DEV: This might need to be split into a qsub componenet (which does the heavy lifting)
    #      and a regular shell script on the login node for internet access to the database.
    #      Will definitely need to work out how to get the QC database URL from the API.
    #      Currently plotly.dash app only returns "loading", so need to get better control over Flask.
    #      There was a tutorial on this but I don't have the link to hand.
    >&2 echo -e "$( date )""\t"INFO: "$RunID": QC analysis started with ID "$jobid"
    #jobid=$( qsub "$scriptspath"/WRGL2_QC_monitor/collect_qc.sh )
    "$scriptspath"/WRGL2_QC_monitor/collect_qc.sh 2> qc.log

    # Monitor this new job
    #monitorqueue "$jobid" "$RunID"

    # Report on the exit code
    exitstatus="$?"
    if [ "$exitstatus" -ne 0 ]; then
        >&2 echo -e "$( date )""\t"ERROR: "$RunID": An error occurred while QC checking this run.
        exit 3
    fi

    >&2 echo -e "$( date )""\t"INFO: "$RunID": QC analysis completed successfully.
}

############
#
#
# Run Backup
# ==========

backup(){
    RunID="$1"
    >&2 echo -e "$( date )""\t"INFO: "$RunID": Compressing run for backup and BAM storage
    jobid=$( qsub "$scriptspath"/create_run_backup/create_run_backup.sh )

    # Monitor this new job
    monitorqueue "$jobid" "$RunID"

    # Report on the exit code
    exitstatus="$?"
    if [ "$exitstatus" -ne 0 ]; then
        >&2 echo -e "$( date )""\t"ERROR: "$RunID": An error occurred while backing up this run..
        exit 3
    fi

}

##################
#
# Run the analysis
# ================

# Check if any variables files exist - this suggests either a non-exome run or an exome
# run where bcl2fastq has already completed. Either way, we don't then need to run it.
hasvariables=false
for file in */*.variables; do
    if [ -e "$file" ]; then
        hasvariables=true
    fi
done
if [ "$hasvariables" = false ]; then
    # If there's no variable file, we may be looking at an exome run
    # try bcl2fastq first, which will quit if not the case
    >&2 echo -e "$( date )""\t"WARNING: "$( basename "$PWD" )": No variables files found. Checking if exome run.
    bcl2fastq
fi

. ./*/*.variables

>&2 echo -e "$( date )""\t"INFO: "$RunID": Run analysis started.

# TODO: Add some pre-run verification that the run ID is unique and will not clash with
#       any previous data (e.g. enforce "RPT" for repeats)
#       Possibly also have some kind of flag for backup and archiving? So it's not needed for most repeats.

# Start alignment & processing for each sample
# alignreads is put into the background so we can start each sample in parallel
# The work is done by a qsub job, but alignreads monitors this until it completes
# so there is no need to worry about starting 24x multi-core tasks on the login node

# ? add check to skip this step if previously completed?

# Could use the sample paths as defined in .variables for this
for p in $( find . -mindepth 1 -maxdepth 1 -type d | grep -v "GenomicsDB" | sed s/"\.\/"/""/g ); do
    # Start alignment and monitoring job
    alignreads "$p" "$RunID" &
done
wait

# Run the joint genotyping step
covariation "$RunID"

# Call variants
for p in $( find . -mindepth 1 -maxdepth 1 -type d | grep -v "GenomicsDB" | sed s/"\.\/"/""/g ); do
    # Start alignment and monitoring job
    variantcaller "$p" "$RunID" &
done
wait

varfiltration "$RunID"

# DEV: Once qsub backup has been written (and maybe qsub for all non-internet parts of QC)
#      run both these concurrently in the background
# TODO: add QC script call ( plus monitoring)
qcscript "$RunID"

# Compress run data for cloud archiving
#backup "$RunID"

wait

# DEV: may need to add a chmod - check settings in scripts
chgrp -R wrgl .
chmod -R 770 .

>&2 echo -e "$( date )""\t"INFO: "$RunID": Run analysis complete.
