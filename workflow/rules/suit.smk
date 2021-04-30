rule import_t1w:
    input: join(config['fs_dir'],'{subject}/mri/orig/001.mgz')
    output: 'output/suit/{subject}/t1w_brain_{subject}.nii'
    params:
        fs_setup = config['fs_setup']
    group: 'suit'              
    container: config['fmriprep']
    shell:
        "{params.fs_setup} mri_convert {input} {output}"

rule suit_isolate:
    input: rules.import_t1w.output
    output: 'output/suit/{subject}/c_t1w_brain_{subject}.nii'
    params:
        out_dir = directory('output/suit/{subject}'),
        script = 'scripts/run_isolate.m'
    group: 'suit'         
    threads: 8
    resources:
        mem_mb = 32000
    log: 
    shell:
        "bash scripts/run_isolate.sh {params.script} {input} {params.out_dir}" 

rule import_cerebellum:
    input: 
        lh_wm = join(config['fs_dir'],'{subject}/mri/lh.wm_cerebellum_mask.nii.gz'),
        rh_wm = join(config['fs_dir'],'{subject}/mri/rh.wm_cerebellum_mask.nii.gz'),
        gm = 'output/atlas/rois/anat/{subject}/cerebellum.nii.gz',
        cropped = 'output/suit/{subject}/c_t1w_brain_{subject}.nii'
    output:
        gm = 'output/suit/{subject}/ceres_seg1_{subject}.nii',
        wm = 'output/suit/{subject}/ceres_seg2_{subject}.nii',
        gm_cropped = 'output/suit/{subject}/c_ceres_seg1_{subject}.nii',
        wm_cropped = 'output/suit/{subject}/c_ceres_seg2_{subject}.nii',
        mask = 'output/suit/{subject}/ceres_pcereb_{subject}.nii',
        mask_cropped = 'output/suit/{subject}/c_ceres_pcereb_{subject}.nii'
    params:
        fs_setup = config['fs_setup']
    group: 'suit'        
    container: config['fmriprep']
    shell:
        "{params.fs_setup} export FSLOUTPUTTYPE=NIFTI && "
        "fslmaths {input.lh_wm} -add {input.rh_wm} -bin {output.wm} && "
        "mri_convert {output.wm} {output.wm_cropped} -rl {input.cropped} -nc && "
        "fslmaths {input.gm} -bin {output.gm} && "
        "mri_convert {output.gm} {output.gm_cropped} -rl {input.cropped} -nc && "
        "fslmaths {output.wm} -add {output.gm} -bin {output.mask} && "
        "mri_convert {output.mask} {output.mask_cropped} -rl {input.cropped} -nc "

rule suit_normalise:
    input:
        gm = rules.import_cerebellum.output.gm_cropped,
        wm = rules.import_cerebellum.output.wm_cropped,
        mask = rules.import_cerebellum.output.mask_cropped
    output:
        flowfield = 'output/suit/{subject}/u_a_c_ceres_seg1_{subject}.nii',
        affine = 'output/suit/{subject}/Affine_c_ceres_seg1_{subject}.mat'
    params:
        out_dir = directory('output/suit/{subject}'),
        script = 'scripts/run_normalise.m'
    group: 'suit'         
    log: 
    shell:
        "bash scripts/run_normalise.sh {params.script} {input.gm} {input.wm} {input.mask} {params.out_dir}"

rule invert_t1:
    input:
        t1 = join(config['fs_dir'],'{subject}/mri/t1_mp2rage.nii.gz')
    output:
        r1 = 'output/suit/{subject}/r1_map_{subject}.nii'
    group: 'suit'
    container: config['fmriprep']    
    shell:
        "export FSLOUTPUTTYPE=NIFTI && fslmaths {input.t1} -div 1000 -recip -thr 0 -uthr 2 -nan {output.r1}"

rule suit_reslice:
    input:
        affine = rules.suit_normalise.output.affine,
        flowfield = rules.suit_normalise.output.flowfield,
        wm = rules.import_cerebellum.output.wm,
        gm = rules.import_cerebellum.output.gm,
        r1 = rules.invert_t1.output.r1,
        mask = rules.import_cerebellum.output.mask_cropped
    output:
        wm = 'output/suit/{subject}/wcceres_seg2_{subject}.nii',
        gm = 'output/suit/{subject}/wcceres_seg1_{subject}.nii',
        r1 = 'output/suit/{subject}/wcr1_map_{subject}.nii',
        atlas = 'output/suit/{subject}/iw_Cerebellum-SUIT_u_a_c_ceres_seg1_{subject}.nii'
    params:
        out_dir = directory('output/suit/{subject}'),
        script = 'scripts/run_reslice.m'
    group: 'suit'   
    threads: 8
    resources:
        mem_mb = 32000            
    shell:
        "bash scripts/run_reslice.sh {params.script} {input.affine} {input.flowfield} "
        "{input.wm} {input.gm} {input.r1} {input.mask} {params.out_dir} {wildcards.subject}"

rule dilate_atlas:
    input:
        gm = rules.import_cerebellum.output.gm,
        atlas = rules.suit_reslice.output.atlas
    output: 'output/suit/{subject}/diw_Cerebellum-SUIT_{subject}.nii'
    group: 'suit'   
    threads: 8
    resources:
        mem_mb = 32000      
    shell:
        "export FSLOUTPUTTYPE=NIFTI && "
        "fslmaths {input.atlas} -dilD -mul {input.gm} {output} -odt int"

rule smooth:
    input: 'output/suit/{subject}/wc{modality}_{subject}.nii'
    output: 'output/suit/{subject}/swc{modality}_{subject}.nii',
    params:
        out_dir = directory('output/suit/{subject}'),
        fwhm = 4,
        script = 'scripts/run_smooth.m'
    group: 'suit'   
    threads: 8
    resources:
        mem_mb = 32000            
    shell:
        "bash scripts/run_smooth.sh {params.script} {input} {params.fwhm} {params.out_dir}"

rule split_groups:
    input:
        controls = lambda wildcards: [str(path) for path in Path('output/suit').rglob(
            '*-C*/swc{}*.nii'.format(wildcards.modality))],
        patients = lambda wildcards: [str(path) for path in Path('output/suit').rglob(
            '*-M*/swc{}*.nii'.format(wildcards.modality))],
    output:
        controls = 'output/suit/controls/swc{modality}_S001-C001.nii',
        patients = 'output/suit/patients/swc{modality}_S004-M101.nii'  
    run:
        dest_dir = os.path.dirname(output.controls)
        for filename in input.controls:
            shutil.copy(filename, dest_dir)

        dest_dir = os.path.dirname(output.patients)
        for filename in input.patients:
            shutil.copy(filename, dest_dir)

rule reslice_vbm_anat:
    input:
        affine = rules.suit_normalise.output.affine,
        flowfield = rules.suit_normalise.output.flowfield,
        ref = rules.invert_t1.output.r1,
        suit = 'output/suit/{subject}/swc{modality}_{subject}.nii'
    output: 'output/suit/{subject}/iswc{modality}_{subject}.nii'
    params:
        out_dir = directory('output/palm/gm/{subject}'),
        script = 'scripts/run_reslice_results.m'
    group: 'suit'   
    threads: 8
    resources:
        mem_mb = 32000            
    shell:
        "bash scripts/run_reslice_results.sh {params.script} {input.affine} {input.flowfield} {input.ref} {input.suit} {output} {params.out_dir} {wildcards.subject}"

