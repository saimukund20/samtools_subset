version 1.0

#######################
## SAMTOOLS WDL STEP ##
#######################
task samtools {
  input {
    File tumor_cram
    File tumor_cram_index
    File fusion_sites
    File reference
    File reference_fai
  }
  Int cores = 1
  Float cram_size = size([tumor_cram, tumor_cram_index], "GB")
  Float regions_size = size([fusion_sites], "GB")
  Float ref_size = size([reference,reference_fai], "GB")
  Int size_needed_gb = 20 + 4 * round(cram_size + regions_size + ref_size)
  runtime {
    memory: "16GB"
    cpu: cores
    preemptible: 1
    docker: "chrisamiller/docker-genomic-analysis:latest"
    disks: "local-disk ~{size_needed_gb} SSD"
  }
  command <<<
    set -o pipefail
    set -o errexit
    ln -s ~{tumor_cram} tumor.cram
    ln -s ~{tumor_cram_index} tumor.crai
    ln -s ~{tumor_cram_index} tumor.cram.crai
    samtools view -T ~{reference} -H tumor.cram > tmp.sam
    cat ~{fusion_sites} | while read chr start stop ; do samtools view -T ~{reference} tumor.cram $chr:$start-$stop >> input.sam ; done
    sort -S 8G input.sam | uniq >> tmp.sam
    samtools sort -O bam -o tumor.filtered.sorted.bam tmp.sam
    samtools index tumor.filtered.sorted.bam
    rm tmp.sam
    rm input.sam
  >>>
  output {
    File sorted_bam_tumor = "tumor.filtered.sorted.bam"
    File sorted_bam_tumor_bai = "tumor.filtered.sorted.bam.bai"
  }
}


##################
## WDL WORKFLOW ##
##################
workflow wf {
  input {
    File tumor_cram
    File tumor_cram_index
    File fusion_sites
    File reference
    File reference_fai
    File reference_dict
  }
  call samtools {
    input:
    tumor_cram=tumor_cram,
    tumor_cram_index=tumor_cram_index,
    fusion_sites=fusion_sites,
    reference=reference,
    reference_fai=reference_fai
  }
  output {
    File sorted_bam_tumor = samtools.sorted_bam_tumor
    File sorted_bam_tumor_bai = samtools.sorted_bam_tumor_bai
  }
}
