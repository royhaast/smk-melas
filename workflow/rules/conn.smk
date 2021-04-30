## Process MNI space data (i.e., denoising timeseries using CONN workflow)

# Pre-CONN step
rule uncompress_mni:
    input:
        #epi = 'output/coregistration/epi2mni/{subject}/epi_rest_mni.nii.gz',
        #gm = 'output/atlas/rois/mni/{subject}/gm.nii.gz',
        #wm = 'output/atlas/rois/mni/{subject}/wm.nii.gz',
        #csf = 'output/atlas/rois/mni/{subject}/csf.nii.gz',
        #rois = 'output/atlas/rois/mni/{subject}/rois.nii.gz',
        #brain = 'output/atlas/rois/mni/{subject}/brain.nii.gz',
        clustermap = 'output/palm/gm/{subject}/{subject}_clustermap_mni.nii.gz'
    output:
        #epi = 'output/uncompressed/mni/{subject}/epi_rest_mni.nii',
        #gm = 'output/uncompressed/mni/{subject}/gm.nii',
        #wm = 'output/uncompressed/mni/{subject}/wm.nii',
        #csf = 'output/uncompressed/mni/{subject}/csf.nii',
        #rois = 'output/uncompressed/mni/{subject}/rois.nii',
        #brain = 'output/uncompressed/mni/{subject}/brain.nii'
        clustermap = 'output/uncompressed/mni/{subject}/clustermap_mni.nii'
    group: 'pre-conn'         
    threads: 8
    resources:
        mem_mb = 32000        
    run:
        for in_file, out_file in zip(input, output):
            shell("mri_convert {in_file} {out_file} -nc")

# # Post-CONN z-zscore
# rule conn_zscore_mni:
#     input:
#         epi = 'output/uncompressed/mni/{subject}/depi_rest_mni.nii',
#     output:
#         zscore = 'output/conn/mni/{subject}/depi_rest_zscore_mni.nii',
#         mean = 'output/conn/mni/{subject}/depi_rest_mean_mni.nii',
#         std = 'output/conn/mni/{subject}/depi_rest_std_mni.nii'
#     group: 'post-conn'          
#     threads: 8
#     resources:
#         mem_mb = 32000        
#     shell:
#         "export FSLOUTPUTTYPE=NIFTI && "
#         "fslmaths {input.epi} -Tmean {output.mean} &&"
#         "fslmaths {input.epi} -Tstd {output.std} &&"
#         "fslmaths {input.epi} -sub {output.mean} -div {output.std} {output.zscore}"

# Map demeaned CONN denoised data to surfaces
rule conn_volume_to_surface:
    input: 
        epi = 'output/uncompressed/mni/{subject}/depi_rest_mni.nii', #rules.conn_zscore_mni.output.zscore,
        surf = 'output/midthickness/mni/{subject}/{hemi}.midthickness.mni.32k_fs_LR.surf.gii'
    output: 'output/conn/dtseries/{subject}/{hemi}.rsfMRI_den-conn.32k_fs_LR.func.gii'
    group: 'post-conn'             
    threads: 8
    resources:
        mem_mb = 32000     
    container: config['connectome_workbench']    
    shell: 
        "wb_command -volume-to-surface-mapping {input.epi} {input.surf} {output} -trilinear"

# Creat dense timeseries using CONN denoised data
rule conn_create_dtseries:
    input:
        lh = 'output/conn/dtseries/{subject}/lh.rsfMRI_den-conn.32k_fs_LR.func.gii',
        rh = 'output/conn/dtseries/{subject}/rh.rsfMRI_den-conn.32k_fs_LR.func.gii',
        vol = 'output/uncompressed/mni/{subject}/depi_rest_mni.nii', #rules.conn_zscore_mni.output.zscore,
        rois = 'output/atlas/labels/mni/{subject}/rois.nii.gz'
    output: 'output/conn/dtseries/{subject}/rsfMRI_den-conn.32k_fs_LR.dtseries.nii'
    group: 'post-conn'    
    container: config['connectome_workbench'] 
    threads: 8
    resources:
        mem_mb = 32000
    shell:
        "wb_command -cifti-create-dense-timeseries {output} -volume {input.vol} {input.rois} -left-metric {input.lh} -right-metric {input.rh} -timestep 2.0"

rule conn_smooth_dtseries:
    input: 
        dtseries = rules.conn_create_dtseries.output,
        lh = 'output/midthickness/mni/{subject}/lh.midthickness.mni.32k_fs_LR.surf.gii',
        rh = 'output/midthickness/mni/{subject}/rh.midthickness.mni.32k_fs_LR.surf.gii',
    output: 'output/conn/dtseries/{subject}/rsfMRI_den-conn-smooth.32k_fs_LR.dtseries.nii'
    params:
        surface_kernel = 1.27, # FWHM/vertexspacing/2.355
        volume_kernel = 1.6 # FWHM/voxelsize/2.355
    group: 'post-conn'
    container: config['connectome_workbench']     
    threads: 8
    resources:
        mem_mb = 32000
    shell:
        "wb_command -cifti-smoothing {input.dtseries} {params.surface_kernel} {params.volume_kernel} COLUMN {output} -left-surface {input.lh} -right-surface {input.rh} -fix-zeros-volume -fix-zeros-surface"

# As used in https://rdcu.be/b7N8K, requires matlab. Does detrending and demeaning too
rule wishart_filter:
    input: rules.conn_smooth_dtseries.output
    output: 'output/conn/dtseries/{subject}/rsfMRI_den-conn-smooth-wishart.32k_fs_LR.dtseries.nii'
    params:
        script = 'scripts/wishart_filter.m'
    group: 'post-conn'
    threads: 8
    resources:
        mem_mb = 32000
    shell:
        "bash scripts/wishart_filter.sh {params.script} {input} {output}" 

