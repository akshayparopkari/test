#!/usr/bin/bash

# For reliable, robust and maintainable bash scripts, start with following commands
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# set -euo pipefail
# IFS=$'\n\t'

#########################################################################################
# HEADER
#########################################################################################
#%
#% DESCRIPTION
#
#% This bash file that stiches together the preprocessing steps for RNA-seq sequences
#% from 3'RNA-seq project.
#%
#% USAGE and EXAMPLE
#% sh ${SCRIPT_NAME} [-h] inputs
#% ./${SCRIPT_NAME} [-h]  inputs
#%
#% OPTIONS
#% inputs:    Directory containing all raw sequence FASTQ files, this will be updated in the
#%            next version
#
#% NOTE: Care should be taken to supply full or relative path to the script file (this
#%       file) and input directory.
#%
# ---------------------------------------------------------------------------------------
#+ SCRIPT INFORMATION
#
#+ VERSION: 0.0.4
#+ AUTHOR:  Akshay Paropkari
#+ LICENSE: MIT
#
# ---------------------------------------------------------------------------------------
#% REFERENCES
#
#% 1. BBTools Suite - https://jgi.doe.gov/data-and-tools/bbtools/
#% 2. FastQC - http://www.bioinformatics.babraham.ac.uk/projects/fastqc/
#% 3. STAR - manual: https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf
#% 4. featureCounts - http://bioinf.wehi.edu.au/featureCounts/
#%
#########################################################################################
# END_HEADER
#########################################################################################

# Help output
#== needed variables ==#
SCRIPT_HEADSIZE=$(head -50 "${0}" |grep -n "^# END_HEADER" | cut -f1 -d:)
SCRIPT_NAME=$(basename "${0}")

#== usage functions ==#
usagefull() { head -"${SCRIPT_HEADSIZE}" "${0}"| grep -e "^#%" | sed -e "s/^#[%+]\ //g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ; }
scriptinfo() { head -"${SCRIPT_HEADSIZE}" "${0}" | grep -e "^#+" | sed -e "s/^#+\ //g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g"; }

if [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]] ; then
    usagefull
    scriptinfo
    exit 0
fi


# Testing for input
if [[ -z "$1" ]] ; then
    echo '\n$(date "+%a %D %r"): Input directory not supplied. Please supply a directory with raw FASTQ files'
    exit 1
fi


# Changing working directory to input directory
dir=$(realpath "$1")
echo -e "\n$(date "+%a %D %r"): Input directory:" "$dir"  # print the directory name which is being processed
# cd into each directory in the directory
cd "$dir" || { echo "\n$(date "+%a %D %r"): cd into input directory failed! Please check your working directory." ; exit 1 ; }


# Starting preprocessing
for f in ./*001.fastq
do

  in_file=$(basename "$f")

  echo -e "\n$(date "+%a %D %r"): Processing $in_file"
  echo

  # •••••••••••••••••••••••••••••••••• #
  # Step 1: Adapter and polyA trimming #
  # •••••••••••••••••••••••••••••••••• #

  echo -e '\n$(date "+%a %D %r"): Adapter and polyA trimming'

  # Create output file name and command to run
  trimmed_file=$(basename "$f" .fastq)_trimmed.fastq
  CMD1="bbduk.sh in=$in_file out=$trimmed_file ref=/opt/anaconda_shared_envs/RNA-seq/opt/bbmap-38.76-0/resources/truseq.fa.gz,/opt/anaconda_shared_envs/RNA-seq/opt/bbmap-38.76-0/resources/polyA.fa.gz k=13 ktrim=r mink=5 qtrim=r trimq=20 minlength=20"

  # Echo and run command
  echo "\n$(date "+%a %D %r"): $CMD1"
  $CMD1
  echo

  # •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• #
  # Step 2: Fastqc generates a report of sequencing read quality #
  # •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• #

  echo -e '\n$(date "+%a %D %r"): Read quality assessment'

  # Create directory to save the quality reports, one per FASTQ file and create command to run
  mkdir -p "$(basename "$f" .fastq)"_qc
  CMD2="fastqc -t 24 --nogroup -o $(basename "$f" .fastq)_qc $trimmed_file"

  # Echo and run command
  echo "\n$(date "+%a %D %r"): $CMD2"
  $CMD2
  echo

  # ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• #
  # Step 3: STAR aligns to  the reference genome and calculates gene counts #
  # ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• #

  echo -e '\n$(date "+%a %D %r"): Aligning QC reads to Candida albicans A21 genome'

  # Create command to run
  CMD3="STAR --runThreadN 18 --genomeDir /home/aparopkari/rnaseq_pipeline/ca21_genome_index --readFilesIn $trimmed_file --outFilterType BySJout --outFilterMultimapNmax 25 --alignSJoverhangMin 8 --alignSJDBoverhangMin 1 --outFilterMismatchNmax 999 --outFilterMismatchNoverLmax 0.3 --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000 --outSAMattributes NH HI NM MD --outSAMtype BAM SortedByCoordinate --quantMode TranscriptomeSAM GeneCounts --outFileNamePrefix $(basename "$f" .fastq) > $(basename "$f" .fastq)_alignment.log"

  # Echo and run command
  echo "\n$(date "+%a %D %r"): $CMD3"
  $CMD3
  echo

done


# •••••••••••••••••••••••••••••••• #
# Collect all counts into one file #
# •••••••••••••••••••••••••••••••• #
echo -e '\n$(date "+%a %D %r"): Collecting gene counts for all samples'

# Create command to run
CMD4="python /home/aparopkari/rnaseq_pipeline/RNAseq/format_counts_table.py $dir -o $dir"

# Echo and run command
echo "\n$(date "+%a %D %r"): $CMD4"
$CMD4
echo


# •••••••••••••••••••••••••••••• #
# Organize files created by STAR #
# •••••••••••••••••••••••••••••• #

# Remove temporary directory
rm -r ./*_STARtmp

# Move log files into a directory
mkdir -p ./STAR_log
mv -t STAR_log/ ./*Log.out ./*Log.progress.out ./*Log.final.out

echo -e '\n$(date "+%a %D %r"): Output files organized'
echo

# •••••••••••••••••••••••••••••••••••••••••••••• #
# Run differential expression analysis with DESeq2 #
# •••••••••••••••••••••••••••••••••••••••••••••• #
echo -e "\n$(date "+%a %D %r"): Running differential expression analysis using DESeq2"
METADATA=$(find . -type f -name "*metadata*" -exec realpath {} +)
GENE_COUNTS=$(find . -type f -name "gene_raw_counts.txt" -exec realpath {} +)
CMD5="Rscript --vanilla /home/aparopkari/rnaseq_pipeline/RNAseq/deseq.R $GENE_COUNTS $METADATA deseq2_lfc.txt MA_plot.pdf"

# Echo and run command
echo "\n$(date "+%a %D %r"): $CMD5"
$CMD5
echo
