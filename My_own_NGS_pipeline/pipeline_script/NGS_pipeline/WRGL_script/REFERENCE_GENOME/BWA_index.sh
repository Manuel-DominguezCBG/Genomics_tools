#!/bin/bash -e
#PBS -l walltime=10:00:00
#PBS -l mem=25GB
cd $PBS_O_WORKDIR

module load bwa/0.7.12

bwa index -p GRCH37_no_gl000201 -a bwtsw GRCh37_no_gl000201.fa
