rule group_data:
    input: 
        controls = 'output/suit/controls/swc{modality}_S001-C001.nii',
        patients = 'output/suit/patients/swc{modality}_S004-M101.nii'  
    output:
        controls = 'output/suit/controls/swc{modality}_grouped.nii',
        patients = 'output/suit/patients/swc{modality}_grouped.nii' 
    group: 'pre-palm'
    run:
        for g, group in enumerate(['controls','patients']):
            cmd = "export FSLOUTPUTTYPE=NIFTI && fslmerge -t {} `ls output/suit/{}/*{}*.nii | tr '\n' ' '`".format(
                output[g], group, wildcards.modality)
            shell(cmd)

rule palm_concatenate:
    input:
        controls = 'output/suit/controls/swc{modality}_grouped.nii',
        patients = 'output/suit/patients/swc{modality}_grouped.nii'
    output:
        concatenated = 'output/palm/{modality}_input.nii'
    group: 'pre-palm'        
    threads: 8
    resources:
        mem_mb = 32000
    shell:
        "export FSLOUTPUTTYPE=NIFTI && fslmerge -t {output.concatenated} {input.controls} {input.patients}"           

rule palm_gm:
    input: expand('output/palm/{modality}_input.nii', modality=modalities)
    output: 'output/palm/gm_mdtb/multivariate_elapsed.csv' #multivariate_clustere_npc_fisher_cfwep_c1.nii'
    params:
        gm = 'resources/gm_mask_t1w_mdtb.nii',
        design = 'resources/design_univariate.mat',
        contrasts = 'resources/design_univariate.con',
        palm = '-T -C 4.3 -corrcon -corrmod -npc -savedof -n 500 -accel tail -nouncorrected'
    log: join('logs/palm/palm_gm.txt')        
    threads: 8
    resources:
        mem_mb = 32000,
        time = 1620
    shell:
        "module load matlab && "
        "palm -i {input[0]} -i {input[2]} -d {params.design} -t {params.contrasts} -m {params.gm} {params.palm} -o `dirname {output}`/multivariate &> {log}"  

rule palm_wm:
    input: expand('output/palm/{modality}_input.nii', modality=modalities)
    output: 'output/palm/wm/multivariate_elapsed.csv' #multivariate_clustere_npc_fisher_cfwep_c1.nii'
    params:
        wm = 'resources/wm_mask_t1w.nii',
        design = 'resources/design_univariate.mat',
        contrasts = 'resources/design_univariate.con',
        palm = '-T -C 4.3 -corrcon -corrmod -npc -savedof -n 500 -accel tail -nouncorrected'
    log: join('logs/palm/palm_wm.txt')
    threads: 8
    resources:
        mem_mb = 32000,
        time = 1620
    shell:
        "module load matlab && "
        "palm -i {input[1]} -i {input[2]} -d {params.design} -t {params.contrasts} -m {params.wm} {params.palm} -o `dirname {output}`/multivariate &> {log}"

rule extract_clusters:
    input: 'output/palm/gm_mdtb/multivariate_clustere_npc_fisher_cfwep_c1.nii'
    output: 'output/palm/gm/clustermap.nii'
    params:
        pvalue = 0.05
    group: 'post-palm'
    run:
        import numpy as np
        import nibabel as nib

        palm = nib.load(input[0])
        data = palm.get_data()
        
        clustermap = np.zeros(data.shape)
        for label, pval in enumerate(np.unique(data)):
            if pval <= params.pvalue:
                clustermap[data==pval] = label

        img = nib.Nifti1Image(clustermap, header=palm.header, affine=palm.affine)
        nib.save(img, output[0])

rule map_results:
    input:
        'output/palm/gm/multivariate_vox_npc_fisher_c1.nii',
        'output/palm/gm/multivariate_vox_tstat_m1_c1.nii',
        'output/palm/gm/multivariate_vox_tstat_m2_c1.nii',
        rules.extract_clusters.output
    output:
        'output/palm/gm/multivariate.func.gii',
        'output/palm/gm/gm_density.func.gii',
        'output/palm/gm/r1.func.gii',
        'output/palm/gm/clustermap.func.gii',
    params:
        script = 'scripts/run_map2surf.m',
        method = ['minORmax','minORmax','minORmax','mode']
    group: 'post-palm'   
    threads: 8
    resources:
        mem_mb = 32000            
    run:
        for (in_file, out_file, method) in zip(input, output, params.method):
            shell("bash scripts/run_map2surf.sh {params.script} {in_file} {out_file} {method}")

rule reslice_results_anat:
    input:
        affine = rules.suit_normalise.output.affine,
        flowfield = rules.suit_normalise.output.flowfield,
        ref = rules.invert_t1.output.r1,
        clustermap = rules.extract_clusters.output
    output:
        clustermap = 'output/palm/gm/{subject}/{subject}_clustermap.nii'  
    params:
        out_dir = directory('output/palm/gm/{subject}'),
        script = 'scripts/run_reslice_results.m'
    group: 'post-palm'   
    threads: 8
    resources:
        mem_mb = 32000            
    run:
        for in_file, out_file in zip(input.clustermap, output):
            shell("bash scripts/run_reslice_results.sh {params.script} {input.affine} {input.flowfield} {input.ref} {in_file} {out_file} {params.out_dir} {wildcards.subject}")

rule reslice_results_epi:
    input:
        clustermap = rules.reslice_results_anat.output.clustermap,
        epi = rules.apply_topup.output.gdc,
        inverse_mat = rules.inverse_bbr.output.inverse_mat
    output: 'output/palm/gm/{subject}/{subject}_clustermap_epi.nii.gz' 
    group: 'post-palm'  
    singularity: config['fmriprep']
    threads: 8
    resources:
        mem_mb = 32000     
    shell:
        "flirt -interp spline -in {input.clustermap} -ref {input.epi} -applyxfm -init {input.inverse_mat} -out {output}"    

rule reslice_results_mni:
    input:
        clustermap = rules.reslice_results_anat.output.clustermap,
        warp = rules.fnirt.output.fout
    output: 'output/palm/gm/{subject}/{subject}_clustermap_mni.nii.gz' 
    params:
        mni = config['MNI']      
    group: 'post-palm'  
    singularity: config['fmriprep']
    threads: 8
    resources:
        mem_mb = 32000     
    shell:
        "applywarp -i {input.clustermap} -r {params.mni} -o {output} -w {input.warp} --rel --interp=nn -v"

rule create_dscalar:
    input:
        vol = rules.reslice_results_mni.output,
        rois = 'output/atlas/labels/mni/{subject}/rois.nii.gz'
    output: 'output/palm/gm/{subject}/{subject}_clustermap_mni.dscalar.nii'
    group: 'post-palm'    
    container: config['connectome_workbench'] 
    threads: 8
    resources:
        mem_mb = 32000
    shell:
        "wb_command -cifti-create-dense-scalar {output} -volume {input.vol} {input.rois}"           