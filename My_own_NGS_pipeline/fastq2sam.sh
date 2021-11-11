#!/bin/bash -e



# https://gatk.broadinstitute.org/hc/en-us/articles/360036351132-FastqToSam-Picard-

java -jar picard.jar FastqToSam \
       F1="./files/GATK_tutorial1.fastq" \
       F2="./files/GATK_tutorial2.fastq" \
       O="./files/output/bam.bam" \
       SM=sample001 \
       RG=rg0013
