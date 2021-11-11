
#Description: CEP Pipeline
#Author: Reuben Pengelly
#Maintainer: ben.sanders@salisbury.nhs.uk
#Status: Release
#Updated 10 May 2018, Ben sanders
#Update note: Uses CEP_PIPELINE.config file for settings
#Mode: BY_RUN

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -f *.config ]; then
    # Load variables
    . *.config
elif [ -f SCRIPTS/*.config ]; then
    # In a validation run, these should be in the SCRIPTS
    # folder, and I want them to overwrite
    . SCRIPTS/*.config
    pipelinescripts="$PWD"/SCRIPTS
elif [ -f "$DIR/../Combined/WRGLPipeline.config" ]; then
    . "$DIR"/../Combined/*.config
    pipelinescripts="$DIR"/../Combined
else
    >&2 echo ERROR: Could not find a valid .config file
    exit 1
fi

runID=$( basename $( pwd ) )
experimentName="$runID"
# We want to get the BED file (and preferred transcript file)
# from any that already exist in the project
targetbed=$( find . -mindepth 1 -maxdepth 1 -name "*.bed" | head )
transcripts=$( find . -mindepth 1 -maxdepth 1 -name "PreferredTranscripts*" | head | sed s/"\.\/"/""/g )
if [ ! -f "$transcripts" ]; then
    >&2 echo WARNING: No preferred transcripts file found
    transcripts=PreferredTranscripts.txt
fi

# Generate a .variables file for each sample
# See existing runs for examples
for ID in $( find . -mindepth 1 -maxdepth 1 -type d | sed s/"\.\/"/""/g ); do
    out="$ID".variables
	cd $ID
    >&2 echo INFO: Writing variables file for "${ID}"
	echo '## Variables file for CEP pipeline' > "$out"
	echo '#Sample_ID' >> "$out"
	echo "Sample_ID=${ID}" >> "$out"
	echo "" >> "$out"

	echo '#FASTQ MD5 checksum' >> "$out"
	echo "R1MD5Filename=`ls *R1*.fastq.gz.md5`" >> "$out"
	echo "R2MD5Filename=`ls *R2*.fastq.gz.md5`" >> "$out"
	echo '' >> "$out"

	echo '#FASTQ filenames' >> "$out"
	echo "R1Filename=`ls *_R1_*.fastq.gz`" >> "$out"
	echo "R2Filename=`ls *_R2_*.fastq.gz`" >> "$out"
	echo '' >> "$out"

	echo '#Capture ROI' >> "$out"
	echo "BEDFilename=$targetbed" >> "$out"
	echo '' >> "$out"

	echo '#RunDetails' >> "$out"
	echo "RunID=$runID" >> "$out"
	echo "ExperimentName=$experimentName" >> "$out"
	echo "Platform=ILLUMINA" >> "$out"
	echo '' >> "$out"

	echo '#Annotation' >> "$out"
	echo "PreferredTranscriptsFile=$transcripts" >> "$out"
	echo '' >> "$out"

	cd ..
	echo '#AnalysisFolders' >> ${ID}/"$out"
	echo 'AnalysisDirs=(' >> ${ID}/"$out"
	# when generating the analysis dirs list we want to ignore QC and validation folders
	find `pwd` -mindepth 1 -maxdepth 1 -type d  >> ${ID}/"$out"
	echo ')' >> ${ID}/"$out"
done
