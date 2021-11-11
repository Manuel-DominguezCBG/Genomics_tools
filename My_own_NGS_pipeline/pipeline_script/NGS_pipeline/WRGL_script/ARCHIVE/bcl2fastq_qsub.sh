#!/bin/bash
#PBS -l walltime=24:00:00,nodes=8:ppn=1
cd $PBS_O_WORKDIR

module load bcl2fastq2/2.16

bcl2fastq --no-lane-splitting --sample-sheet *SampleSheet*csv


