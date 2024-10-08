version 1.0

## Version 03-11-2022
##
## This WDL workflow runs Regenie.
## This workflow assumes users have thoroughly read the Regenie docs for caveats and details.
## Regenie's documentation: https://rgcgithub.github.io/regenie/options/
##
##  Step1 - Made with BGEN files in mind to use as the input genetic data file. - (BGEN version 1.2, 8-bit probabilities).
##  Step2 - Use separate .bed, .bim, .fam files for each chromosome. (If testing chr 1-22, there should be 22 separate files).
##  PLINK can be used to convert bed, bim, and fam files to BGEN files outside of this workflow.
##  PLINK can also be used to convert pgen, pvar, and psam files to BGEN files outside of this workflow.
##
## Cromwell version support - Successfully tested on v77
##
## Distributed under terms of the MIT License
## Copyright (c) 2021 Brian Sharber
## Contact <brian.sharber@vumc.org>

workflow Regenie {
    # Refer to Regenie's documentation for the descriptions to most of these parameters.
    input {
        File bgen_step1
        File bed_files_step2_file # File containing tab-separated list of: .bed file, .bim file, .fam file, and corresponding chromosome number - for all files used for Step2.
        String fit_bin_out_name = "fit_bin_out" # File prefix for the list of predictions produced in Step1.
        File? sample
        File? keep
        File? remove
        File? extract
        File? exclude
        File? phenoFile
        String? phenoCol
        String? phenoColList
        File? covarFile
        String? covarCol
        String? covarColList
        String? catCovarList
        File? pred
        Array[Int] chr_list # List of chromosomes used for analysis.
        Array[String] phenotype_names # Phenotypes you want to analyze. (Column names).

        String regenie_docker = "briansha/regenie:v3.0_boost" # Compiled with Boost IOSTREAM: https://github.com/rgcgithub/regenie/wiki/Using-docker
        String r_base_docker = "briansha/regenie_r_base:4.1.0"  # Ubuntu 18.04, R 4.1.0, and a few Ubuntu and R packages.
    }
    Array[Array[String]] bed_files_step2 = read_tsv(bed_files_step2_file)

    call RegenieStep1WholeGenomeModel {
        input:
            bgen_step1 = bgen_step1,
            keep = keep,
            fit_bin_out_name = fit_bin_out_name,
            covarFile = covarFile,
            exclude = exclude,
            phenoFile = phenoFile,
            remove = remove,
            docker = regenie_docker
    }

    scatter (files in bed_files_step2) {
      call RegenieStep2AssociationTesting {
          input:
              bed_step2 = files[0],
              bim_step2 = files[1],
              fam_step2 = files[2],
              chr_name = files[3],
              keep = keep,
              covarFile = covarFile,
              exclude = exclude,
              phenoFile = phenoFile,
              remove = remove,
              pred = RegenieStep1WholeGenomeModel.fit_bin_out,
              docker = regenie_docker,
              output_locos = RegenieStep1WholeGenomeModel.output_locos
      }
    }

}

# In Step 1, the whole genome regression model is fit to the traits
# and a set of genomic predictions are produced as output.
task RegenieStep1WholeGenomeModel {
    # Refer to Regenie's documentation for the descriptions to most of these parameters.
    input {
        String fit_bin_out_name # File prefix for the list of predictions produced.

        # Basic options
        File bgen_step1
        File? sample
        Boolean ref_first = false
        File? keep
        File? remove
        File? extract
        File? exclude
        File? extract_or
        File? exclude_or
        File? phenoFile
        String? phenoCol
        String? phenoColList
        String? phenoExcludeList
        File? covarFile
        String? covarCol
        String? covarColList
        String? catCovarList
        String? covarExcludeList
        File? pred
        String? tpheno_file
        Int? tpheno_indexCol
        Int? tpheno_ignoreCols

        # Options
        Boolean bt = false # Specifies both phenotype file and covariate files contain binary values.
        Boolean cc12 = false
        Int bsize = 1000  # 1000 is recommended by regenie's documentation
        Int? cv
        Boolean loocv = false
        Boolean lowmem = false
        String? lowmem_prefix
        String? split_l0
        File? run_l0
        File? run_l1
        Boolean keep_l0 = false
        Boolean print_prs = false
        Boolean force_step1 = false
        Int? minCaseCount
        Boolean apply_rint = false
        Int? nb
        Boolean strict = false
        Boolean ignore_pred = false
        Boolean use_relative_path = false
        Boolean use_prs = false
        Boolean gz = false
        Boolean force_impute = false
        Boolean write_samples = false
        Boolean print_pheno = false
        Boolean firth = false
        Boolean approx = false
        Boolean firth_se = false
        Boolean write_null_firth = false
        File? use_null_firth
        Boolean spa = false
        Float? pThresh
        String? test
        Int? chr
        String? chrList
        String? range
        Float? minMAC
        Float? minINFO
        String? sex_specific
        Boolean af_cc = false
        Boolean no_split = false
        Int? starting_block
        Int? nauto
        Int? maxCatLevels
        Int? niter
        Int? maxstep_null
        Int? maxiter_null
        Boolean debug = false
        Boolean verbose = false
        Boolean help = false

        # Interaction testing
        String? interaction
        String? interaction_snp
        File? interaction_file
        File? interaction_file_sample
        Boolean interaction_file_reffirst = false
        Boolean no_condtl = false
        Boolean force_condtl = false
        Float? rare_mac

        # Conditional analyses
        File? condition_list
        File? condition_file
        Int? max_condition_vars

        # Runtime
        String docker
        Float memory = 3.5
        Int? disk_size_override
        Int cpu = 1
        Int preemptible = 1
        Int maxRetries = 0
    }
    Float genotype_size = size(bgen_step1, "GiB")
    Int disk = select_first([disk_size_override, ceil(10.0 + 2.0 * genotype_size)])

    command <<<
        set -euo pipefail
        regenie \
        --step 1 \
        --threads=~{cpu} \
        --bgen=~{bgen_step1} \
        ~{if defined(sample) then "--sample=~{sample} " else " "} \
        ~{if ref_first then "--ref-first " else " "} \
        ~{if defined(keep) then "--keep=~{keep} " else " "} \
        ~{if defined(remove) then "--remove=~{remove} " else " "} \
        ~{if defined(extract) then "--extract=~{extract} " else " "} \
        ~{if defined(exclude) then "--exclude=~{exclude} " else " "} \
        ~{if defined(extract_or) then "--extract-or=~{extract_or} " else " "} \
        ~{if defined(exclude_or) then "--exclude-or=~{exclude_or} " else " "} \
        --phenoFile=~{phenoFile} \
        ~{if defined(phenoCol) then "--phenoCol=~{phenoCol} " else " "} \
        ~{if defined(phenoColList) then "--phenoColList=~{phenoColList} " else " "} \
        ~{if defined(phenoExcludeList) then "--phenoExcludeList=~{phenoExcludeList} " else " "} \
        ~{if defined(covarFile) then "--covarFile=~{covarFile} " else " "} \
        ~{if defined(covarCol) then "--covarCol=~{covarCol} " else " "} \
        ~{if defined(covarColList) then "--covarColList=~{covarColList} " else " "} \
        ~{if defined(catCovarList) then "--catCovarList=~{catCovarList} " else " "} \
        ~{if defined(covarExcludeList) then "--covarExcludeList=~{covarExcludeList} " else " "} \
        ~{if defined(pred) then "--pred=~{pred} " else " "} \
        ~{if defined(tpheno_file) then "--tpheno-file=~{tpheno_file} " else " "} \
        ~{if defined(tpheno_indexCol) then "--tpheno-indexCol=~{tpheno_indexCol} " else " "} \
        ~{if defined(tpheno_ignoreCols) then "--tpheno-ignoreCols=~{tpheno_ignoreCols} " else " "} \
        ~{if bt then "--bt " else " "} \
        ~{if cc12 then "--cc12 " else " "} \
        --bsize=~{bsize} \
        ~{if defined(cv) then "--cv=~{cv} " else " "} \
        ~{if loocv then "--loocv " else " "} \
        ~{if lowmem then "--lowmem " else " "} \
        ~{if defined(lowmem_prefix) then "--lowmem-prefix=~{lowmem_prefix} " else " "} \
        ~{if defined(split_l0) then "--split-l0=~{split_l0} " else " "} \
        ~{if defined(run_l0) then "--run-l0=~{run_l0} " else " "} \
        ~{if defined(run_l1) then "--run-l1=~{run_l1} " else " "} \
        ~{if keep_l0 then "--keep-l0 " else " "} \
        ~{if print_prs then "--print-prs " else " "} \
        ~{if force_step1 then "--force-step1 " else " "} \
        ~{if defined(nb) then "--nb=~{nb} " else " "} \
        ~{if strict then "--strict " else " "} \
        ~{if ignore_pred then "--ignore-pred " else " "} \
        ~{if use_relative_path then "--use-relative-path " else " "} \
        ~{if use_prs then "--use-prs " else " "} \
        ~{if gz then "--gz " else " "} \
        ~{if force_impute then "--force-impute " else " "} \
        ~{if write_samples then "--write-samples " else " "} \
        ~{if print_pheno then "--print-pheno " else " "} \
        ~{if firth then "--firth " else " "} \
        ~{if approx then "--approx " else " "} \
        ~{if firth_se then "--firth-se " else " "} \
        ~{if write_null_firth then "--write-null-firth " else " "} \
        ~{if defined(use_null_firth) then "--use-null-firth=~{use_null_firth} " else " "} \
        ~{if spa then "--spa " else " "} \
        ~{if defined(pThresh) then "--pThresh=~{pThresh} " else " "} \
        ~{if defined(test) then "--test=~{test} " else " "} \
        ~{if defined(chr) then "--chr=~{chr} " else " "} \
        ~{if defined(chrList) then "--chrList=~{chrList} " else " "} \
        ~{if defined(range) then "--range=~{range} " else " "} \
        ~{if defined(minMAC) then "--minMAC=~{minMAC} " else " "} \
        ~{if defined(minINFO) then "--minINFO=~{minINFO} " else " "} \
        ~{if defined(sex_specific) then "--sex-specific=~{sex_specific} " else " "} \
        ~{if af_cc then "--af-cc " else " "} \
        ~{if no_split then "--no-split " else " "} \
        ~{if defined(starting_block) then "--starting-block=~{starting_block} " else " "} \
        ~{if defined(nauto) then "--nauto=~{nauto} " else " "} \
        ~{if defined(maxCatLevels) then "--maxCatLevels=~{maxCatLevels} " else " "} \
        ~{if defined(niter) then "--niter=~{niter} " else " "} \
        ~{if defined(maxstep_null) then "--maxstep-null=~{maxstep_null} " else " "} \
        ~{if defined(maxiter_null) then "--maxiter-null=~{maxiter_null} " else " "} \
        ~{if debug then "--debug " else " "} \
        ~{if verbose then "--verbose " else " "} \
        ~{if help then "--help " else " "} \
        ~{if defined(interaction) then "--interaction=~{interaction} " else " "} \
        ~{if defined(interaction_snp) then "--interaction-snp=~{interaction_snp} " else " "} \
        ~{if defined(interaction_file) then "--interaction-file=~{interaction_file} " else " "} \
        ~{if defined(interaction_file_sample) then "--interaction-file-sample=~{interaction_file_sample} " else " "} \
        ~{if interaction_file_reffirst then "--interaction-file-reffirst " else " "} \
        ~{if no_condtl then "--no-condtl " else " "} \
        ~{if force_condtl then "--force-condtl " else " "} \
        ~{if defined(rare_mac) then "--rare-mac=~{rare_mac} " else " "} \
        ~{if defined(condition_list) then "--condition-list=~{condition_list} " else " "} \
        ~{if defined(condition_file) then "--condition-file=~{condition_file} " else " "} \
        ~{if defined(max_condition_vars) then "--max-condition-vars=~{max_condition_vars} " else " "} \
        --out fit_bin_out
    >>>

    output {
        File fit_bin_out = "${fit_bin_out_name}_pred.list" # Refers to the list of loco files written. Lists the files as being located in the current working directory.
        Array[File] output_locos = glob("*.loco") # Writes n loco files for n phenotypes.
    }

    runtime {
        docker: docker
        memory: memory + " GiB"
	    disks: "local-disk " + disk + " HDD"
        cpu: cpu
        preemptible: preemptible
        maxRetries: maxRetries
    }
}

# In Step 2, a set of imputed SNPs are tested for association using a Firth logistic regression model.
task RegenieStep2AssociationTesting {
    # Refer to Regenie's documentation for the descriptions to most of these parameters.
    input {
        File bed_step2
        File bim_step2
        File fam_step2
        Array[File] output_locos
        String? chr_name

        # Basic options
        File? sample
        Boolean ref_first = false
        File? keep
        File? remove
        File? extract
        File? exclude
        File? extract_or
        File? exclude_or
        File? phenoFile
        String? phenoCol
        String? phenoColList
        String? phenoExcludeList
        File? covarFile
        String? covarCol
        String? covarColList
        String? catCovarList
        String? covarExcludeList
        File? pred     # File containing predictions from Step 1
        String? tpheno_file
        Int? tpheno_indexCol
        Int? tpheno_ignoreCols

        # Options
        Boolean bt = false    # Specifies both phenotype file and covariate files contain binary values.
        Boolean cc12 = false
        Int bsize = 1000      # 1000 is recommended by regenie's documentation
        Int? cv
        Boolean loocv = false
        Boolean lowmem = false
        String? lowmem_prefix
        String? split_l0
        File? run_l0
        File? run_l1
        Boolean keep_l0 = false
        Boolean print_prs = false
        Boolean force_step1 = false
        Int? minCaseCount
        Boolean apply_rint = false
        Int? nb
        Boolean strict = false
        Boolean ignore_pred = false
        Boolean use_relative_path = false
        Boolean use_prs = false
        Boolean gz = false
        Boolean force_impute = false
        Boolean write_samples = false
        Boolean print_pheno = false
        Boolean firth = false
        Boolean approx = false
        Boolean firth_se = false
        Boolean write_null_firth = false
        File? use_null_firth
        Boolean spa = false
        Float? pThresh
        String? test
        Int? chr
        String? chrList
        String? range
        Float? minMAC
        Float? minINFO
        String? sex_specific
        Boolean af_cc = false
        Boolean no_split = false
        Int? starting_block
        Int? nauto
        Int? maxCatLevels
        Int? niter
        Int? maxstep_null
        Int? maxiter_null
        Boolean debug = false
        Boolean verbose = false
        Boolean help = false

        # Interaction testing
        String? interaction
        String? interaction_snp
        File? interaction_file
        File? interaction_file_sample
        Boolean interaction_file_reffirst = false
        Boolean no_condtl = false
        Boolean force_condtl = false
        Float? rare_mac

        # Conditional analyses
        File? condition_list
        File? condition_file
        Int? max_condition_vars

        # Gene-based testing
        File? anno_file
        File? set_list
        File? extract_sets
        File? exclude_sets
        String? extract_setlist
        String? exclude_setlist
        File? aaf_file
        File? mask_def

        # Options
        Float? aaf_bins
        String? build_mask
        Boolean singleton_carrier = false
        Boolean write_mask = false
        String? vc_tests
        Float? vc_maxAAF
        Float? skat_params
        Float? skat_rho
        Float? vc_MACthr
        String? joint
        Boolean skip_test = false
        String? mask_lovo
        Boolean mask_lodo = false
        Boolean write_mask_snplist = false
        Boolean check_burden_files = false
        Boolean strict_check_burden = false

        # Runtime
        String docker
        Float memory = 3.5
        Int? disk_size_override
        Int cpu = 1
        Int preemptible = 1
        Int maxRetries = 0
    }
    Float dosage_size = size(bed_step2, "GiB")
    Int disk = select_first([disk_size_override, ceil(10.0 + 2.0 * dosage_size)])

    # Loco files are moved to the current working directory due to the list of predictions (pred) expecting them to be there.
    command <<<
        set -euo pipefail
        for file in ~{sep=' ' output_locos}; do \
          mv $file .; \
        done
        regenie \
        --step 2 \
        --threads=~{cpu} \
        --bed=~{sub(bed_step2,'\\.bed$','')} \
        ~{if defined(sample) then "--sample=~{sample} " else " "} \
        ~{if ref_first then "--ref-first " else " "} \
        ~{if defined(keep) then "--keep=~{keep} " else " "} \
        ~{if defined(remove) then "--remove=~{remove} " else " "} \
        ~{if defined(extract) then "--extract=~{extract} " else " "} \
        ~{if defined(exclude) then "--exclude=~{exclude} " else " "} \
        ~{if defined(extract_or) then "--extract-or=~{extract_or} " else " "} \
        ~{if defined(exclude_or) then "--exclude-or=~{exclude_or} " else " "} \
        --phenoFile=~{phenoFile} \
        ~{if defined(phenoCol) then "--phenoCol=~{phenoCol} " else " "} \
        ~{if defined(phenoColList) then "--phenoColList=~{phenoColList} " else " "} \
        ~{if defined(phenoExcludeList) then "--phenoExcludeList=~{phenoExcludeList} " else " "} \
        ~{if defined(covarFile) then "--covarFile=~{covarFile} " else " "} \
        ~{if defined(covarCol) then "--covarCol=~{covarCol} " else " "} \
        ~{if defined(covarColList) then "--covarColList=~{covarColList} " else " "} \
        ~{if defined(catCovarList) then "--catCovarList=~{catCovarList} " else " "} \
        ~{if defined(covarExcludeList) then "--covarExcludeList=~{covarExcludeList} " else " "} \
        ~{if defined(pred) then "--pred=~{pred} " else " "} \
        ~{if defined(tpheno_file) then "--tpheno-file=~{tpheno_file} " else " "} \
        ~{if defined(tpheno_indexCol) then "--tpheno-indexCol=~{tpheno_indexCol} " else " "} \
        ~{if defined(tpheno_ignoreCols) then "--tpheno-ignoreCols=~{tpheno_ignoreCols} " else " "} \
        ~{if bt then "--bt " else " "} \
        ~{if cc12 then "--cc12 " else " "} \
        --bsize=~{bsize} \
        ~{if defined(cv) then "--cv=~{cv} " else " "} \
        ~{if loocv then "--loocv " else " "} \
        ~{if lowmem then "--lowmem " else " "} \
        ~{if defined(lowmem_prefix) then "--lowmem-prefix=~{lowmem_prefix} " else " "} \
        ~{if defined(split_l0) then "--split-l0=~{split_l0} " else " "} \
        ~{if defined(run_l0) then "--run-l0=~{run_l0} " else " "} \
        ~{if defined(run_l1) then "--run-l1=~{run_l1} " else " "} \
        ~{if keep_l0 then "--keep-l0 " else " "} \
        ~{if print_prs then "--print-prs " else " "} \
        ~{if force_step1 then "--force-step1 " else " "} \
        ~{if defined(nb) then "--nb=~{nb} " else " "} \
        ~{if strict then "--strict " else " "} \
        ~{if ignore_pred then "--ignore-pred " else " "} \
        ~{if use_relative_path then "--use-relative-path " else " "} \
        ~{if use_prs then "--use-prs " else " "} \
        ~{if gz then "--gz " else " "} \
        ~{if force_impute then "--force-impute " else " "} \
        ~{if write_samples then "--write-samples " else " "} \
        ~{if print_pheno then "--print-pheno " else " "} \
        ~{if firth then "--firth " else " "} \
        ~{if approx then "--approx " else " "} \
        ~{if firth_se then "--firth-se " else " "} \
        ~{if write_null_firth then "--write-null-firth " else " "} \
        ~{if defined(use_null_firth) then "--use-null-firth=~{use_null_firth} " else " "} \
        ~{if spa then "--spa " else " "} \
        ~{if defined(pThresh) then "--pThresh=~{pThresh} " else " "} \
        ~{if defined(test) then "--test=~{test} " else " "} \
        ~{if defined(chr) then "--chr=~{chr} " else " "} \
        ~{if defined(chrList) then "--chrList=~{chrList} " else " "} \
        ~{if defined(range) then "--range=~{range} " else " "} \
        ~{if defined(minMAC) then "--minMAC=~{minMAC} " else " "} \
        ~{if defined(minINFO) then "--minINFO=~{minINFO} " else " "} \
        ~{if defined(sex_specific) then "--sex-specific=~{sex_specific} " else " "} \
        ~{if af_cc then "--af-cc " else " "} \
        ~{if no_split then "--no-split " else " "} \
        ~{if defined(starting_block) then "--starting-block=~{starting_block} " else " "} \
        ~{if defined(nauto) then "--nauto=~{nauto} " else " "} \
        ~{if defined(maxCatLevels) then "--maxCatLevels=~{maxCatLevels} " else " "} \
        ~{if defined(niter) then "--niter=~{niter} " else " "} \
        ~{if defined(maxstep_null) then "--maxstep-null=~{maxstep_null} " else " "} \
        ~{if defined(maxiter_null) then "--maxiter-null=~{maxiter_null} " else " "} \
        ~{if debug then "--debug " else " "} \
        ~{if verbose then "--verbose " else " "} \
        ~{if help then "--help " else " "} \
        ~{if defined(interaction) then "--interaction=~{interaction} " else " "} \
        ~{if defined(interaction_snp) then "--interaction-snp=~{interaction_snp} " else " "} \
        ~{if defined(interaction_file) then "--interaction-file=~{interaction_file} " else " "} \
        ~{if defined(interaction_file_sample) then "--interaction-file-sample=~{interaction_file_sample} " else " "} \
        ~{if interaction_file_reffirst then "--interaction-file-reffirst " else " "} \
        ~{if no_condtl then "--no-condtl " else " "} \
        ~{if force_condtl then "--force-condtl " else " "} \
        ~{if defined(rare_mac) then "--rare-mac=~{rare_mac} " else " "} \
        ~{if defined(condition_list) then "--condition-list=~{condition_list} " else " "} \
        ~{if defined(condition_file) then "--condition-file=~{condition_file} " else " "} \
        ~{if defined(max_condition_vars) then "--max-condition-vars=~{max_condition_vars} " else " "} \
        ~{if defined(anno_file) then "--anno-file=~{anno_file} " else " "} \
        ~{if defined(set_list) then "--set-list=~{set_list} " else " "} \
        ~{if defined(extract_sets) then "--extract-sets=~{extract_sets} " else " "} \
        ~{if defined(exclude_sets) then "--exclude-sets=~{exclude_sets} " else " "} \
        ~{if defined(extract_setlist) then "--extract-setlist=~{extract_setlist} " else " "} \
        ~{if defined(exclude_setlist) then "--exclude-setlist=~{exclude_setlist} " else " "} \
        ~{if defined(aaf_file) then "--aaf-file=~{aaf_file} " else " "} \
        ~{if defined(mask_def) then "--mask-def=~{mask_def} " else " "} \
        ~{if defined(aaf_bins) then "--aaf-bins=~{aaf_bins} " else " "} \
        ~{if defined(build_mask) then "--build-mask=~{build_mask} " else " "} \
        ~{if singleton_carrier then "--singleton-carrier " else " "} \
        ~{if write_mask then "--write-mask " else " "} \
        ~{if defined(vc_tests) then "--vc-tests=~{vc_tests} " else " "} \
        ~{if defined(vc_maxAAF) then "--vc-maxAAF=~{vc_maxAAF} " else " "} \
        ~{if defined(skat_params) then "--skat-params=~{skat_params} " else " "} \
        ~{if defined(skat_rho) then "--skat-rho=~{skat_rho} " else " "} \
        ~{if defined(vc_MACthr) then "--vc-MACthr=~{vc_MACthr} " else " "} \
        ~{if defined(joint) then "--joint=~{joint} " else " "} \
        ~{if skip_test then "--skip-test " else " "} \
        ~{if defined(mask_lovo) then "--mask-lovo=~{mask_lovo} " else " "} \
        ~{if mask_lodo then "--mask-lodo " else " "} \
        ~{if write_mask_snplist then "--write-mask-snplist " else " "} \
        ~{if check_burden_files then "--check-burden-files " else " "} \
        ~{if strict_check_burden then "--strict-check-burden " else " "} \
        --out ~{chr_name}
    >>>

    output {
        Array[File] test_bin_out_firth = glob("*.regenie")
    }

    runtime {
        docker: docker
        memory: memory + " GiB"
	    disks: "local-disk " + disk + " HDD"
        cpu: cpu
        preemptible: preemptible
        maxRetries: maxRetries
    }
}

