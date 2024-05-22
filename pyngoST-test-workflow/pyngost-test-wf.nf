process PYNGOSTDOWNLOAD {
    label 'process_single'

    // Must create the container first from the def file
    // `singularity build singularityIMG/pyngost%24eb4485a76f34a9b9cbd345e940d01a.sif singularityIMG/pyngost%24eb4485a76f34a9b9cbd345e940d01a.def`
    container '../singularityIMG/pyngost%24eb4485a76f34a9b9cbd345e940d01a.sif'
    containerOptions "--bind /etc/pki/tls/certs/ca-bundle.crt --env REQUESTS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt"

    input:

    output:
    path 'pyngostdb', emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    pyngoST.py \
        -d \
        -n pyngostdb \
        $args
    """
}

process PYNGOST {
    label 'process_medium'
    publishDir 'pyngost-out', mode: 'copy', overwrite: true
    errorStrategy 'ignore'

    container '/scicomp/home-pure/rqu4/TESTING/SOFTWARE/pyngoST/pyngost%24eb4485a76f34a9b9cbd345e940d01a.sif'
    //containerOptions "--bind /etc/pki/tls/certs/ca-bundle.crt --env REQUESTS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt"

    input:
    tuple val(meta), path(fasta)
    path(db)

    output:
    tuple val(meta), path("*.pyngoST.out"), emit: results

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    pyngoST.py \
        -i $fasta \
        -p $db \
        -t $task.cpus \
        -o ${prefix}.pyngoST.out
        $args
    """
}

process GUNZIP {
    tag "$archive"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(archive)

    output:
    tuple val(meta), path("*.fasta"), emit: gunzip
    path "versions.yml"             , emit: versionss

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    gunzip = archive.toString() - '.gz'
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Not calling gunzip itself because it creates files
    # with the original group ownership rather than the
    # default one for that user / the work directory
    gzip \\
        -cd \\
        $args \\
        $archive \\
        > ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """

    stub:
    gunzip = archive.toString() - '.gz'
    """
    touch $gunzip
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """
}

workflow PYNGOSTDOWNLOADTEST {
    
    // Download pyngoST database
    PYNGOSTDOWNLOAD()

    // Create input channel
    Channel
        .fromPath(params.input)
        .map { file -> [[id: file.getSimpleName()], file] }
        .set { pyngost_ch }

    // Unzip
    GUNZIP(pyngost_ch)

    // Perform MLST
    PYNGOST(
        GUNZIP.out.gunzip,
        PYNGOSTDOWNLOAD.out.db
    )
}

workflow {
    PYNGOSTDOWNLOADTEST()
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
