## Generate midthickness and inflated surfaces

rule convert_surfaces:
    input: join(config['fs_dir'],'{subject}/surf/{hemi}.{surf}')
    output: 'output/midthickness/convert/{subject}/{hemi}.{surf}.surf.gii'
    params:
        fs_setup = config['fs_setup']
    group: 'surface'         
    container: config['fmriprep']
    shell:
        "{params.fs_setup} mris_convert {input} {output}"

rule generate_midthickness:
    input:
        white = 'output/midthickness/convert/{subject}/{hemi}.white.surf.gii',
        pial = 'output/midthickness/convert/{subject}/{hemi}.pial.surf.gii'
    output: 'output/midthickness/convert/{subject}/{hemi}.midthickness.surf.gii'
    group: 'surface'             
    container: config['connectome_workbench']      
    shell:
        "wb_command -surface-cortex-layer {input.white} {input.pial} 0.5 {output}"      

## Bring midthickness surface in scanner, EPI and MNI space

rule get_tkr2scanner:
    input: join(config['fs_dir'],'{subject}/mri/orig.mgz')
    output: 'output/coregistration/tkr2scanner/{subject}/tkr2scanner.xfm'
    params:
        fs_setup = config['fs_setup']
    group: 'surface'                 
    container: config['fmriprep']
    shell: 
        "{params.fs_setup} mri_info {input} --tkr2scanner > {output}"

rule get_scanner2epi:
    input: 
        bbr = rules.inverse_bbr.output.inverse_mat,
        t1w = join(config['fs_dir'],'{subject}/mri/orig.nii.gz'),
        epi = rules.apply_topup.output.firstvol_gdc
    output: 'output/coregistration/surf2epi/{subject}/surf2epi.xfm'
    group: 'surface'             
    threads: 8
    container: config['connectome_workbench']    
    shell:
        "wb_command -convert-affine -from-flirt {input.bbr} {input.t1w} {input.epi} -to-world {output}"

rule apply_surf_tkr2scanner:
    input: 
        surf = rules.generate_midthickness.output,
        tkr2scanner = rules.get_tkr2scanner.output
    output: 'output/midthickness/anat/{subject}/{hemi}.midthickness.anat.surf.gii'
    group: 'surface'             
    threads: 8
    container: config['connectome_workbench']
    shell: 
        "wb_command -surface-apply-affine {input.surf} {input.tkr2scanner} {output}"    

rule apply_surf_scanner2epi:
    input:
        surf = rules.apply_surf_tkr2scanner.output,
        scanner2epi = rules.get_scanner2epi.output
    output: 'output/midthickness/epi/{subject}/{hemi}.midthickness.epi.surf.gii'
    group: 'surface'             
    threads: 8
    container: config['connectome_workbench']
    shell:     
        "wb_command -surface-apply-affine {input.surf} {input.scanner2epi} {output}"

rule apply_surf_scanner2mni:
    input:
        surf = 'output/midthickness/anat/{subject}/{hemi}.midthickness.anat.surf.gii',
        inverse_warp = rules.inverse_fnirt.output,
        warp = rules.fnirt.output.fout
    output: 'output/midthickness/mni/{subject}/{hemi}.midthickness.mni.surf.gii'
    group: 'surface'             
    threads: 8
    container: config['connectome_workbench']   
    shell:
        "wb_command -surface-apply-warpfield {input.surf} {input.inverse_warp} {output} -fnirt {input.warp}"

## Resample surface data to 32k_fs_LR space and inflate

rule resample_surface:
    input: 
        surf = 'output/midthickness/{space}/{subject}/{hemi}.midthickness.{space}.surf.gii',
        sphere_old = 'output/midthickness/convert/{subject}/{hemi}.sphere.reg.surf.gii',
        sphere_new = 'resources/fs_LR-deformed_to-fsaverage.{hemi}.sphere.32k_fs_LR.surf.gii'
    output: 'output/midthickness/{space}/{subject}/{hemi}.midthickness.{space}.32k_fs_LR.surf.gii'
    group: 'surface'             
    container: config['connectome_workbench']      
    shell:    
        "wb_command -surface-resample {input.surf} {input.sphere_old} {input.sphere_new} BARYCENTRIC {output}"

rule inflate_surface:
    input: 'output/midthickness/{space}/{subject}/{hemi}.midthickness.{space}.32k_fs_LR.surf.gii'
    output:
        inflated = 'output/midthickness/{space}/{subject}/{hemi}.inflated.{space}.32k_fs_LR.surf.gii',
        very_inflated = 'output/midthickness/{space}/{subject}/{hemi}.very_inflated.{space}.32k_fs_LR.surf.gii',
    params: "-iterations-scale 1.0"
    group: 'surface'             
    threads: 8
    container: config['connectome_workbench']
    shell:     
        "wb_command -surface-generate-inflated {input} {output.inflated} {output.very_inflated} {params}"   

## Map EPI data to surface

rule volume_to_surface:
    input: 
        epi = rules.onestep_resampling.output.warped_topup,
        surf = rules.apply_surf_scanner2epi.output
    output: 'output/surfmaps/epi/{subject}/{hemi}.rsfMRI.epi.func.gii'
    group: 'surface'             
    threads: 8
    resources:
        time = 30,
        mem_mb = 32000     
    container: config['connectome_workbench']    
    shell: 
        "wb_command -volume-to-surface-mapping {input.epi} {input.surf} {output} -trilinear"

rule volume_to_surface_aroma:
    input: 
        epi = rules.ica_aroma.output.den,
        surf = rules.apply_surf_scanner2epi.output
    output: 'output/surfmaps/epi/{subject}/{hemi}.rsfMRI_den-aroma.epi.func.gii'
    group: 'surface'             
    threads: 8
    resources:
        time = 30,
        mem_mb = 32000     
    container: config['connectome_workbench']    
    shell: 
        "wb_command -volume-to-surface-mapping {input.epi} {input.surf} {output} -trilinear"

## Downsample surface data to 32k_fs_LR

rule resample_surface_data:
    input:
        metric = rules.volume_to_surface.output,
        sphere_old = 'output/midthickness/convert/{subject}/{hemi}.sphere.reg.surf.gii',
        sphere_new = 'resources/fs_LR-deformed_to-fsaverage.{hemi}.sphere.32k_fs_LR.surf.gii',
        area_old = 'output/midthickness/convert/{subject}/{hemi}.midthickness.surf.gii',
        area_new = 'output/midthickness/anat/{subject}/{hemi}.midthickness.anat.32k_fs_LR.surf.gii'
    output: 'output/surfmaps/epi/{subject}/{hemi}.rsfMRI.32k_fs_LR.func.gii'
    group: 'surface'             
    threads: 8
    container: config['connectome_workbench']    
    shell:     
        "wb_command -metric-resample {input.metric} {input.sphere_old} {input.sphere_new} ADAP_BARY_AREA {output} -area-surfs {input.area_old} {input.area_new}"
        
rule resample_surface_data_aroma:
    input:
        metric = rules.volume_to_surface_aroma.output,
        sphere_old = 'output/midthickness/convert/{subject}/{hemi}.sphere.reg.surf.gii',
        sphere_new = 'resources/fs_LR-deformed_to-fsaverage.{hemi}.sphere.32k_fs_LR.surf.gii',
        area_old = rules.generate_midthickness.output,
        area_new = rules.resample_surface.output
    output: 'output/surfmaps/epi/{subject}/{hemi}.rsfMRI_den-aroma.32k_fs_LR.func.gii'
    group: 'surface'             
    threads: 8
    container: config['connectome_workbench']    
    shell:     
        "wb_command -metric-resample {input.metric} {input.sphere_old} {input.sphere_new} ADAP_BARY_AREA {output} -area-surfs {input.area_old} {input.area_new}"