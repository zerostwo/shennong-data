# views and base methods are metadata-only

    <ShennongData>
    Resource: toil
    Title:    TCGA TARGET GTEx Toil RNA-seq complete cohort
    Kind:     Dataset   Status: available   Version: 2018-05-08
    Model:    bulk      Assay: rna
    Shape:    60,498 features x 19,131 samples
    View:     observations (19131 x 6)
    Measurements:
    - log2_tpm_plus_0.001
    Context fields:
    - disease, primary_site, sample_type, study, detailed_category
    Ready operations:
    - gene_expression_by_sample
    - tumor_normal_expression_by_cancer
    - survival_expression
    - gene_resolution
    Query plan:
    - no data materialized
    Server: http://example.test   API: v1

