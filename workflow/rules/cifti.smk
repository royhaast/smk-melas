## Combine volume and surface data into CIFTI .dtseries.nii file

rule transform_rois:
    input:
        parc = join(config['fs_dir'],'{subject}/mri/aparc+aseg.mgz'),
        warp = rules.fnirt.output.fout,
        inverse_mat = rules.inverse_bbr.output.inverse_mat,
        epi = rules.apply_topup.output.firstvol_gdc,      
    output:
        parc_anat = 'output/atlas/parc/anat/{subject}/aparc+aseg.anat.nii.gz',
        parc_mni = 'output/atlas/parc/mni/{subject}/aparc+aseg.mni.nii.gz',
        parc_epi = 'output/atlas/parc/epi/{subject}/aparc+aseg.epi.nii.gz'
    params:
        mni = config['MNI'],
        fs_setup = config['fs_setup']
    group: 'cifti'    
    container: config['fmriprep']   
    threads: 8
    resources:
        mem_mb = 32000         
    shell:
        "{params.fs_setup} mri_convert {input.parc} {output.parc_anat} && "
        "applywarp -i {output.parc_anat} -r {params.mni} -w {input.warp} -o {output.parc_mni} -d int --interp=nn  && "
        "flirt -in {output.parc_anat} -ref {input.epi} -applyxfm -init {input.inverse_mat} -datatype int -interp nearestneighbour -out {output.parc_epi}"

rule prepare_cerebellum:
    input: 
        lh_cerebellum = join(config['fs_dir'],'{subject}/mri/lh.gm_cerebellum_mask.nii.gz'),
        rh_cerebellum = join(config['fs_dir'],'{subject}/mri/rh.gm_cerebellum_mask.nii.gz'),
        t1 = join(config['fs_dir'],'{subject}/mri/t1_mp2rage.nii.gz')
    output: 'output/atlas/rois/anat/{subject}/cerebellum.nii.gz'
    group: 'cifti'          
    script:
        "../../scripts/prepare_cerebellum.py"

rule transform_cerebellum:
    input:
        cerebellum = rules.prepare_cerebellum.output,
        warp = rules.fnirt.output.fout,
        inverse_mat = rules.inverse_bbr.output.inverse_mat,
        epi = rules.apply_topup.output.firstvol_gdc,      
    output:
        cerebellum_mni = 'output/atlas/rois/mni/{subject}/cerebellum.nii.gz',
        cerebellum_epi = 'output/atlas/rois/epi/{subject}/cerebellum.nii.gz'
    params:
        mni = config['MNI'],
        fs_setup = config['fs_setup']
    group: 'cifti'    
    container: config['fmriprep']   
    threads: 8
    resources:
        mem_mb = 32000         
    shell:
        "applywarp -i {input.cerebellum} -r {params.mni} -w {input.warp} -o {output.cerebellum_mni} -d int --interp=nn  && "
        "flirt -in {input.cerebellum} -ref {input.epi} -applyxfm -init {input.inverse_mat} -datatype int -interp nearestneighbour -out {output.cerebellum_epi}"

rule extract_rois:
    input:
        parc = 'output/atlas/parc/{space}/{subject}/aparc+aseg.{space}.nii.gz',
        cerebellum = 'output/atlas/rois/{space}/{subject}/cerebellum.nii.gz'
    output:
        gm = 'output/atlas/rois/{space}/{subject}/gm.nii.gz',
        wm = 'output/atlas/rois/{space}/{subject}/wm.nii.gz',
        csf = 'output/atlas/rois/{space}/{subject}/csf.nii.gz',
        rois = 'output/atlas/rois/{space}/{subject}/rois.nii.gz',
        brain = 'output/atlas/rois/{space}/{subject}/brain.nii.gz'
    params:
        fs_setup = config['fs_setup']
    group: 'cifti'                 
    container: config['fmriprep']
    threads: 8
    resources:
        mem_mb = 32000    
    shell:
        "{params.fs_setup} mri_binarize --i {input.parc} --match 2 41 --erode 2 --o {output.wm} && "
        #"mri_binarize --i {input.parc} --match 2 41 --o {output.wm_nonerode} && "
        "mri_binarize --i {input.parc} --gm --o {output.gm} && "
        "mri_binarize --i {input.parc} --match 4 43 --erode 1 --o {output.csf} && "
        #"mri_binarize --i {input.parc} --match 4 43  --o {output.csf_nonerode} && "
        "mri_binarize --i {input.parc} --match 10 11 12 13 16 17 18 26 28 49 50 51 52 53 54 58 60 --o {output.rois} && "
        "mri_binarize --i {input.parc} --match 0 --inv --o {output.brain} && "
        "fslmaths {output.rois} -mul {input.parc} -add {input.cerebellum} {output.rois}"

rule generate_subcortical_labels:
    input:
        rois = 'output/atlas/rois/{space}/{subject}/rois.nii.gz',
        labels = 'resources/Atlas_ROIs.1p6mm.txt'
    output: 'output/atlas/labels/{space}/{subject}/rois.nii.gz'
    group: 'cifti'    
    container: config['connectome_workbench']
    shell:
        "wb_command -volume-label-import {input.rois} {input.labels} {output} -discard-others"

rule generate_dense_labels:
    input:
        rois = 'output/atlas/labels/{space}/{subject}/rois.nii.gz',
        lh_mmp = config['lh_mmp'],
        rh_mmp = config['rh_mmp']
    output: 'output/cifti/dlabels/{space}/{subject}/rois.dlabel.nii'
    group: 'cifti'    
    container: config['connectome_workbench']
    shell:
        "wb_command -cifti-create-label {output} -volume {input.rois} {input.rois} -left-label {input.lh_mmp} -right-label {input.rh_mmp}"

rule create_dtseries:
    input:
        lh = 'output/surfmaps/epi/{subject}/lh.rsfMRI.32k_fs_LR.func.gii',
        rh = 'output/surfmaps/epi/{subject}/rh.rsfMRI.32k_fs_LR.func.gii',
        vol = rules.onestep_resampling.output.warped_mni,
        rois = 'output/atlas/labels/mni/{subject}/rois.nii.gz'
    output: 'output/cifti/dtseries/{subject}/rsfMRI.32k_fs_LR.dtseries.nii'
    group: 'cifti'    
    container: config['connectome_workbench'] 
    threads: 8
    resources:
        mem_mb = 32000
    shell:
        "wb_command -cifti-create-dense-timeseries {output} -volume {input.vol} {input.rois} -left-metric {input.lh} -right-metric {input.rh} -timestep 2.0"

rule create_dtseries_aroma:
    input:
        lh = 'output/surfmaps/epi/{subject}/lh.rsfMRI_den-aroma.32k_fs_LR.func.gii',
        rh = 'output/surfmaps/epi/{subject}/rh.rsfMRI_den-aroma.32k_fs_LR.func.gii',
        vol = rules.transform_ica_aroma.output,
        rois = 'output/atlas/labels/mni/{subject}/rois.nii.gz'
    output: 'output/denoising/dtseries/{subject}/rsfMRI_den-aroma.32k_fs_LR.dtseries.nii'
    group: 'cifti'    
    container: config['connectome_workbench'] 
    threads: 8
    resources:
        mem_mb = 32000
    shell:
        "wb_command -cifti-create-dense-timeseries {output} -volume {input.vol} {input.rois} -left-metric {input.lh} -right-metric {input.rh} -timestep 2.0"

rule extract_confounds:
    input:
        vol = rules.onestep_resampling.output.warped_mni,
        wm = 'output/atlas/rois/mni/{subject}/wm.nii.gz',
        csf = 'output/atlas/rois/mni/{subject}/csf.nii.gz',
        movreg = rules.mc_tseries.output.par
    output: 'output/denoising/confounds/{subject}/confounds.tsv'
    log: 'logs/extract_confounds/{subject}.log'
    group: 'cifti' 
    threads: 8
    resources:
        mem_mb = 32000       
    script:
        "../../scripts/extract_confounds.py"

rule clean_tseries:
    input:
        dtseries = rules.create_dtseries.output,
        confounds = rules.extract_confounds.output,
        lh_surf = 'output/midthickness/anat/{subject}/lh.midthickness.anat.32k_fs_LR.surf.gii',
        rh_surf = 'output/midthickness/anat/{subject}/rh.midthickness.anat.32k_fs_LR.surf.gii'
    output: 'output/denoising/dtseries/{subject}/rsfMRI_den-ciftify.32k_fs_LR.dtseries.nii'
    params: 
        "--detrend --standardize --low-pass=0.08 --high-pass=0.009 --tr=2 --drop-dummy-TRs=5 "
        "--cf-cols='CSF,WhiteMatter,X,Y,Z,RotX,RotY,RotZ' --cf-td-cols='CSF,WhiteMatter,X,Y,Z,RotX,RotY,RotZ'"
    log: 'logs/clean_dtseries/{subject}.log'
    singularity: config['ciftify']
    group: 'cifti'
    threads: 8
    resources:
        mem_mb = 32000    
    shell:
        "ciftify_clean_img --verbose --output-file={output} --confounds-tsv={input.confounds} "
        "--smooth-fwhm=3 --left-surface {input.lh_surf} --right-surface {input.rh_surf} {params} {input.dtseries} &> {log}"

rule clean_tseries_aroma:
    input:
        dtseries = rules.create_dtseries_aroma.output,
        confounds = rules.extract_confounds.output
    output: 'output/denoising/dtseries/{subject}/rsfMRI_den-aroma-ciftify.32k_fs_LR.dtseries.nii'
    params: "--detrend --high-pass=0.009 --tr=2 --drop-dummy-TRs=5 --cf-cols='CSF,WhiteMatter'"
    log: 'logs/clean_dtseries/{subject}.log'
    singularity: config['ciftify']
    group: 'cifti'
    threads: 8
    resources:
        mem_mb = 32000    
    shell:
        'ciftify_clean_img --verbose --output-file={output} --confounds-tsv={input.confounds} {params} {input.dtseries} &> {log}'

rule parcellate_dtseries:
    input:
        dtseries = rules.clean_tseries.output,
        dlabels = 'output/cifti/dlabels/mni/{subject}/rois.dlabel.nii'
    output: 'output/denoising/dtseries/{subject}/rsfMRI_den-ciftify.32k_fs_LR.ptseries.nii'
    singularity: config['connectome_workbench']
    group: 'cifti'
    threads: 8
    resources:
        mem_mb = 32000
    shell:
        "wb_command -cifti-parcellate {input.dtseries} {input.dlabels} COLUMN {output}"

rule correlate_ptseries:
    input: 'output/denoising/dtseries/{subject}/rsfMRI_den-ciftify.32k_fs_LR.ptseries.nii'
    output: 'output/denoising/correlation/{subject}/rsfMRI_den-ciftify.32k_fs_LR.pconn.nii'
    singularity: config['connectome_workbench']
    group: 'cifti'
    threads: 8
    resources:
        mem_mb = 32000    
    shell:
        "wb_command -cifti-correlation {input} {output}"