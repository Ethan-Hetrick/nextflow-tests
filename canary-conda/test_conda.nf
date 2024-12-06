
workflow { FASTQC() }

process FASTQC {
    label 'process_medium'
    shell '/bin/bash'

    publishDir( params.outdir, mode: 'copy' )

    conda "bioconda::fastqc=0.11.9"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.11.9--0' :
        'biocontainers/fastqc:0.11.9--0' }"

    output:
    path("conda.log")

    script:
    """
    fastqc --version 2>&1 >> conda.log
    which -a conda 2>&1 >> conda.log
    conda info --all >> conda.log
    conda config --show >> conda.log
    """
}

workflow.onComplete {

   println ( workflow.success ? """
       Pipeline execution summary
       ---------------------------
       Completed at: ${workflow.complete}
       Duration    : ${workflow.duration}
       Success     : ${workflow.success}
       workDir     : ${workflow.workDir}
       exit status : ${workflow.exitStatus}
       """ : """
       Failed: ${workflow.errorReport}
       exit status : ${workflow.exitStatus}
       """
   )
}
