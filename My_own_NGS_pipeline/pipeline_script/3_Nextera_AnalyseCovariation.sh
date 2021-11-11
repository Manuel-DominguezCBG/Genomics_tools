#!/bin/bash -e

#PBS -W umask=002
#PBS -W group_list=wrgl

cd $PBS_O_WORKDIR

#Description: Nextera Pipeline
#Author: Matthew Lyon
#Maintainer: ben.sanders@nhs.net
#Status: Release
#Updated 08 May 2018, Ben Sanders
#Update note: Created config file with params and paths for all scripts
#Mode: BY_LANE

# Load pipeline settings - load before variables and any duplicate valures
#                          will be replaced with the variables file ones.
. *.config

# Load sample variables
. *.variables

# Analyze patterns of covariation in the sequence dataset
java -Xmx8000m "$javatmp" -jar "$gatkpath" \
-T BaseRecalibrator \
-R "$refgenome" \
-knownSites "$dbsnpfile" \
-knownSites "$knownindels1" \
-knownSites "$knownindels2" \
-I BAMsforBQSR.list \
-L "$BEDFilename" \
-o "$RunID"_recal_data.table \
-ip 100 \
-nct "$analysecovariationppn" \
-dt NONE
