#! /bin/bash

echo "Arguments given: $@"

# Inputs:
# 1 Working directory where files can be written to
# 2 Path to the normal bam
# 3 Path to the normal minibam
# 4 Path to the directory containing the tumour bam (this script should only process 1 tumour at a time!)
# 5 Path to the directory containing the tumour minibam.
# 6... space-separate list of absolute paths to pass-filtered SNVs (except for MuSE
#    which is not pass-filtered, so include the original; and smufin, which will only have
#    an INDEL that should be included) that are associated with the given tumour


WORKING_DIR=$0
shift
PATH_TO_NORMAL=$1
shift
PATH_TO_NORMAL_MINIBAM=$2
shift
PATH_TO_TUMOUR_BAM=$3
shift
PATH_TO_TUMOUR_MINIBAM=$4
shift

if [ "$#" -eq 0 ] ; then
	echo "ERROR: No arguments given!"
	exit 1
fi

# Store the inputs in an array.
VCFS=( "$@" )

echo "VCFs: $@"

for vcf in ${VCFS[@]}; do
	echo "----------------------------------------------------------------"
	echo "Checking file: $vcf"
	OUTFILE=$(basename $vcf)
	OUTFILE=${OUTFILE/\.vcf\.gz/.chr22.positions.txt}

	# Working just with Chromosome 22 - this it not a comprehensive in-depth reconciliation, just a quick sanity-check that should catch most problems.
	zcat $vcf | grep ^22 | cut -f2 > $WORKING_DIR/$OUTFILE

	while read location; do
		echo "for location $location:"
		# Get the count in the normal bam for this location, using samtools
		# PATH_TO_NORMAL=$( ( [ -f /datastore/bam/normal/*/*.bam ] && echo /datastore/bam/normal/*/*.bam) || ([ -f /datastore/bam/normal/*.bam ] && echo /datastore/bam/normal/*.bam))
		COUNT_IN_NORMAL=$(samtools view $PATH_TO_NORMAL 22:$location-$location -c)
		echo "count in normal - original bam: $COUNT_IN_NORMAL"

		# Get count in normal minibam, using samtools
		# NORMAL_FILE_BASENAME=$(basename /datastore/bam/normal/*/*.bam)
		NORMAL_FILE_BASENAME=$(basename $PATH_TO_NORMAL)
		# COUNT_IN_NORMAL_MINIBAM=$(samtools view /datastore/variantbam_results/${NORMAL_FILE_BASENAME/\.bam/_minibam.bam} 22:$location-$location -c)
		COUNT_IN_NORMAL_MINIBAM=$(samtools view $PATH_TO_NORMAL_MINIBAM 22:$location-$location -c)
		echo "count in normal - minibam: $COUNT_IN_NORMAL_MINIBAM"

		if [ "$COUNT_IN_NORMAL" != "$COUNT_IN_NORMAL_MINIBAM" ] ; then
			echo "MISMATCH in normal original vs normal minibam ! Something may have gone wrong in vcf merge or in variantbam!"
			exit 1;
		fi
		# for the tumour (now only run this script with ONE tumour), get count in original and mini BAMs.
		for tumour in $(ls $PATH_TO_TUMOUR_BAM) ; do
			TUMOUR_FILE_BASENAME=$(basename $tumour)
			COUNT_IN_TUMOUR_1=$(samtools view $tumour 22:$location-$location -c)
			echo "count in tumour ${TUMOUR_FILE_BASENAME}: $COUNT_IN_TUMOUR_1"
			COUNT_IN_TUMOUR_1_MINIBAM=$(samtools view $PATH_TO_TUMOUR_MINIBAM/mini-$TUMOUR_FILE_BASENAME 22:$location-$location -c)
			echo "count in tumour mini-$TUMOUR_FILE_BASENAME: $COUNT_IN_TUMOUR_1_MINIBAM"
			if [ "$COUNT_IN_TUMOUR_1" != "$COUNT_IN_TUMOUR_1_MINIBAM" ] ; then
				echo "MISMATCH in tumour original vs tumour minibam! Something may have gone wrong in vcf merge or in variantbam!"
				exit 1;
			fi
		done
	done <$WORKING_DIR/$OUTFILE
done
