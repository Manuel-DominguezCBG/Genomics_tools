## Script to prepare WRGL style variables files.
## All directories must be samples, with on set of FastQ in each, with md5 checksums and BED file. 

## Variables
runID=$1
samplesFile='IDs.txt'
BEDpath='/scratch/WCEP/PIPELINE'
BED='TruSight_One_v1.1+-300bp.bed'
prefTranscripts='/scratch/WRGL/151211_M01875_0176_000000000-AKP70/PreferredTranscripts.txt'
experimentName='TruSightOne'

echo
echo "Run ID for variables files is '$1', as defined by argument 1 of you calling this script."
echo 

for ID in `cat $samplesFile`; do
	cd $ID
	cp ${BEDpath}/${BED} .
	cp /scratch/WCEP/PIPELINE/*_CEP_*.sh .
	pwd
	echo '## Variables file for CEP pipeline' > ${ID}.variables
	echo '#Sample_ID' >> ${ID}.variables
	echo "Sample_ID=${ID}" >> ${ID}.variables
	echo "" >> ${ID}.variables

	echo '#FASTQ MD5 checksum' >> ${ID}.variables
	echo "R1MD5Filename=`ls *R1*.fastq.gz.md5`" >> ${ID}.variables
	echo "R2MD5Filename=`ls *R2*.fastq.gz.md5`" >> ${ID}.variables
	echo '' >> ${ID}.variables

	echo '#FASTQ filenames' >> ${ID}.variables
	echo "R1Filename=`ls *_R1_*.fastq.gz`" >> ${ID}.variables
	echo "R2Filename=`ls *_R2_*.fastq.gz`" >> ${ID}.variables
	echo '' >> ${ID}.variables

	echo '#Capture ROI' >> ${ID}.variables
	echo "BEDFilename=${BED}" >> ${ID}.variables
	echo '' >> ${ID}.variables

	echo '#RunDetails' >> ${ID}.variables
	echo "RunID=$runID" >> ${ID}.variables
	echo "ExperimentName=$experimentName" >> ${ID}.variables
	echo "Platform=ILLUMINA" >> ${ID}.variables
	echo '' >> ${ID}.variables

	echo '#Annotation' >> ${ID}.variables
	echo "PreferredTranscriptsFile=$prefTranscripts" >> ${ID}.variables
	echo '' >> ${ID}.variables 
	
	cd ..
	echo '#AnalysisFolders' >> ${ID}/${ID}.variables
	echo 'AnalysisDirs=(' >> ${ID}/${ID}.variables
	find `pwd` -mindepth 1 -maxdepth 1 -type d | sed 's/^/\t"/g' | sed 's/$/\"/g' >> ${ID}/${ID}.variables
	echo ')' >> ${ID}/${ID}.variables
done
