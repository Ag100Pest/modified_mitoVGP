#!/bin/bash

#this script (map10x2.sh) is used for the final step of short read polishing. This step
#requires the output of the script map10x1.sh to be trimmed at the overlapping ends. This
#can be achieved using mummer or BLAST to determine the coordinates for trimming.
#Experimental script trimmer.sh may also be employed.
#Ends should be trimmed leaving about 100 bp of overlapping ends, in order to achieve a good
#alignment, and those overlapping ends should then be removed from the final assembly.

#it requires the following software (and their dependencies) installed:
#bowtie2/2.1.0, samtools/1.7, freebayes/1.1.0-46-g8d2b3a0-dirty, bcftools/1.9

#reads are aligned to the reference, Similarly to script map10x1.sh, a final round of
#freebayes and bcftools consensus is required to obtain the polished contig using the 
#aligned outcome of the script (this step is currently not included in the script).

#required positional arguments are:
#1) the species name (e.g. Calypte_anna)
#2) the VGP species ID (e.g. bCalAnn1)
#3) the filename of the mitocontig generated by the script trimmer.sh.
#4) the number of threads

set -e

SPECIES=$1
ABBR=$2
CONTIG=$3
NPROC=$4

#define working directory
W_URL=${SPECIES}/assembly_MT/intermediates

if ! [[ -e "${W_URL}/bowtie2_round2" ]]; then

mkdir ${W_URL}/bowtie2_round2

#align
bowtie2-build ${W_URL}/trimmed/${CONTIG} ${W_URL}/bowtie2_round2/${ABBR}
bowtie2 -x ${W_URL}/bowtie2_round2/${ABBR} -1 ${W_URL}/bowtie2_round1/fq/aligned_${ABBR}_all_1.fq -2 ${W_URL}/bowtie2_round1/fq/aligned_${ABBR}_all_2.fq -p ${NPROC} --no-mixed | samtools view -bSF4 - > "${W_URL}/bowtie2_round2/aligned_${ABBR}_all_trimmed.bam"

#sort and index the alignment
samtools sort ${W_URL}/bowtie2_round2/aligned_${ABBR}_all_trimmed.bam -o ${W_URL}/bowtie2_round2/aligned_${ABBR}_all_trimmed_sorted.bam -@ ${NPROC}
samtools index ${W_URL}/bowtie2_round2/aligned_${ABBR}_all_trimmed_sorted.bam
rm ${W_URL}/bowtie2_round2/aligned_${ABBR}_all_trimmed.bam

fi

if ! [[ -e "${W_URL}/freebayes_round2/" ]]; then

mkdir ${W_URL}/freebayes_round2/

~/miniconda3/bin/freebayes --bam ${W_URL}/bowtie2_round2/aligned_${ABBR}_all_trimmed_sorted.bam --fasta-reference ${W_URL}/trimmed/${CONTIG} --vcf ${W_URL}/freebayes_round2/aligned_${ABBR}_all_trimmed_sorted.vcf --theta 0.001 --ploidy 1

bgzip ${W_URL}/freebayes_round2/aligned_${ABBR}_all_trimmed_sorted.vcf

tabix -p vcf ${W_URL}/freebayes_round2/aligned_${ABBR}_all_trimmed_sorted.vcf.gz

/home/gformenti/bin/bcftools/bcftools consensus ${W_URL}/freebayes_round2/aligned_${ABBR}_all_trimmed_sorted.vcf.gz -f ${W_URL}/trimmed/${CONTIG} -o ${W_URL}/freebayes_round2/${CONTIG%.*}_10x2.fasta

fi