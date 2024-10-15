# create a workflow to test the Terra platform
version 1.0
workflow test {
    input {
        File fn_pheno
        File fn_pgen
        File fn_pvar
        File fn_psam
        String output_name
    }
    
    call genotype_qc{
        input: 
            fn_pgen = fn_pgen,
            fn_pvar = fn_pvar,
            fn_psam = fn_psam,
            output_name = output_name + ".plink_qc"
    }
    
    
    
}
