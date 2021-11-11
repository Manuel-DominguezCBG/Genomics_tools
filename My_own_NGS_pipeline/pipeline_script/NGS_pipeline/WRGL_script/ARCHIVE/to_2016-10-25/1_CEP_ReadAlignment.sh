#!/bin/bash 
#PBS -l walltime=20:00:00
#PBS -l nodes=1:ppn=16
#PBS -l mem=20GB
#PBS -W umask=0007
cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Status: Dev
#Updated: 30 November 2015, Ben Sanders
#Update note: Added umask to PBS settings, to allow multiple users to access output.
#Updated 20 Jan 2016, Reuben Pengelly
#Update note: improved multithreading with MPI due to poor speed of processing
#Updated 3 Mar 2016, Reuben Pengelly
#Update note: Changed to BWA-mem for alignment
#Mode: BY_SAMPLE

module load bwa/0.7.5a

#load sample variables
. *.variables

#check FASTQ MD5sums
md5sum -c "$R1MD5Filename"
if [ $? -ne 0 ];then
   exit -1
fi

md5sum -c "$R2MD5Filename"
if [ $? -ne 0 ];then
   exit -1
fi


## Align reads with BWA-MEM
cp /scratch/WCEP/REF_GENOME/GRCh37.amb /scratch/WCEP/REF_GENOME/GRCh37.ann /scratch/WCEP/REF_GENOME/GRCh37.bwt /scratch/WCEP/REF_GENOME/GRCh37.pac /scratch/WCEP/REF_GENOME/GRCh37.sa .
#cp /scratch/WCEP/REF_GENOME/human_g1k_v37.fasta .

bwa mem \
-t 16 \
-M \
-R '@RG\tID:'"$RunID"'_'"$Sample_ID"'\tSM:'"$Sample_ID"'\tPL:'"$Platform"'\tLB:'"$ExperimentName" \
GRCh37 \
$R1Filename $R2Filename \
> "$RunID"_"$Sample_ID".sam

##Globally align reads to reference genome
#mpiexec -n 6 $novoalign_path -c 2 \
#-d /scratch/WRGL/bundle2.8/b37/human_g1k_v37.nix \
#-f "$R1Filename" "$R2Filename" \
#-F ILM1.8 \
#--Q2Off \
#-o FullNW \
#-r None \
#-c 8 \
#-i PE 300,200 \
#-o SAM '@RG\tID:'"$RunID"'\tSM:'"$RunID"'\tPL:'"$Platform"'\tLB:'"$ExperimentName" \
#1> "$RunID"_"$Sample_ID".sam


rm GRCh37.amb GRCh37.ann GRCh37.bwt GRCh37.pac GRCh37.sa
qsub 2_CEP_IndelRealignment.sh
