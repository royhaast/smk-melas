## Do boundary-based registration to anatomy 

rule bbr:
    input:
        epi = rules.apply_topup.output.firstvol,
        t1w = join(config['fs_dir'],'{subject}/mri/orig.mgz')
    output:
        reg = 'output/coregistration/epi2anat/{subject}/epi_rest_bbr.dat',
        mat = 'output/coregistration/epi2anat/{subject}/epi_rest_bbr.mat',
        vol = 'output/coregistration/epi2anat/{subject}/epi_rest_bbr.nii.gz'
    params:
        fs_setup = config['fs_setup'],      
        optional = '--bold --init-fsl'
    group: 'coregistration'
    log: 'logs/bbr/{subject}.log'  
    singularity: config['fmriprep']
    threads: 8
    resources:
        time = 30,
        mem_mb = 32000            
    shell:
        "{params.fs_setup} bbregister --s {wildcards.subject} --mov {input.epi} --reg {output.reg} --o {output.vol} {params.optional} && "
        "tkregister2 --noedit --reg {output.reg} --mov {input.epi} --targ {input.t1w} --fslregout {output.mat} &> {log}"      

rule inverse_bbr:
    input:
        epi = rules.apply_topup.output.gdc,
        t1w = join(config['fs_dir'],'{subject}/mri/orig.nii.gz'),
        mat = rules.bbr.output.mat
    output:
        inverse_mat = 'output/coregistration/epi2anat/{subject}/epi_rest_bbr_inverse.mat',
        t1w_coreg = 'output/coregistration/epi2anat/{subject}/t1w_bbr_inverse.nii.gz'
    group: 'coregistration'
    singularity: config['fmriprep']
    threads: 8
    resources:
        mem_mb = 32000     
    shell:
        "convert_xfm -omat {output.inverse_mat} -inverse {input.mat} && "
        "flirt -interp spline -in {input.t1w} -ref {input.epi} -applyxfm -init {output.inverse_mat} -out {output.t1w_coreg}"

rule apply_bbr:
    input:
        epi = rules.apply_topup.output.gdc,
        bbr = rules.bbr.output.reg,
        targ = join(config['fs_dir'],'{subject}/mri/orig.mgz')
    output: 'output/coregistration/apply_bbr/{subject}/epi_rest_gdc_bbr.nii.gz'
    group: 'coregistration'
    params:
        fs_setup = config['fs_setup']
    container: config['fmriprep']
    threads: 8
    resources:
        mem_mb = 32000      
    shell:
        "{params.fs_setup} mri_vol2vol --mov {input.epi} --targ {input.targ} --o {output} --reg {input.bbr} --no-resample"

## Do volume-based registration to MNI space 

rule flirt:
    input: join(config['fs_dir'],'{subject}/mri/orig.nii.gz')
    output: 'output/coregistration/anat2mni/{subject}/linear/Anat2MNILinear.mat'
    params:
        prefix = 'output/coregistration/anat2mni/{subject}/linear/Anat2MNILinear',
        MNI = config['MNI'],
        optional = '-interp spline -dof 12 -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -v'
    group: 'coregistration'
    log: 'logs/flirt/{subject}.log'
    singularity: config['fmriprep']
    threads: 8
    resources:
        time = 30,    
        mem_mb = 32000           
    shell:
        "flirt {params.optional} -in {input} -ref {params.MNI} -omat {output} -out {params.prefix} &> {log}"

rule fnirt:
    input:
        t1w = join(config['fs_dir'],'{subject}/mri/orig.nii.gz'),
        affine = rules.flirt.output
    output:
        fout = 'output/coregistration/anat2mni/{subject}/nonlinear/NonlinearRegWarp.nii.gz',
        jout = 'output/coregistration/anat2mni/{subject}/nonlinear/NonlinearRegJacobians.nii.gz',
        refout = 'output/coregistration/anat2mni/{subject}/nonlinear/IntensityModulatedT1.nii.gz',
        iout = 'output/coregistration/anat2mni/{subject}/nonlinear/NonlinearWarped.nii.gz',
        logout = 'output/coregistration/anat2mni/{subject}/nonlinear/NonlinearReg.txt',
        intout = 'output/coregistration/anat2mni/{subject}/nonlinear/NonlinearIntensities.nii.gz',
        cout = 'output/coregistration/anat2mni/{subject}/nonlinear/NonlinearReg.nii.gz'
    params:
        MNI = config['MNI']
    group: 'coregistration'
    log: 'logs/fnirt/{subject}.log'
    singularity: config['fmriprep'] 
    threads: 8
    resources:
        time = 60,
        mem_mb = 32000
    shell:
        "fnirt --in={input.t1w} --ref={params.MNI} --aff={input.affine} --fout={output.fout} --jout={output.jout} "
        "--refout={output.refout} --iout={output.iout} --logout={output.logout} --intout={output.intout} --cout={output.cout} -v &> {log}"

rule inverse_fnirt:
    input:
        t1w = join(config['fs_dir'],'{subject}/mri/orig.nii.gz'),
        warp = rules.fnirt.output.fout
    output: 'output/coregistration/anat2mni/{subject}/nonlinear/NonlinearRegInverseWarp.nii.gz'
    group: 'coregistration'
    singularity: config['fmriprep']
    threads: 8     
    resources:
        time = 30,
        mem_mb = 32000           
    shell:
        "invwarp -w {input.warp} -o {output} -r {input.t1w} --noconstraint"

rule onestep_resampling:
    input:
        gdc = rules.gradient_unwarp.output.warp,
        topup = rules.run_topup.output,
        bbr = rules.bbr.output.mat,
        fnirt = rules.fnirt.output.cout
    output:
        warped_mni = 'output/coregistration/epi2mni/{subject}/epi_rest_mni.nii.gz',
        warped_topup = 'output/coregistration/epi2mni/{subject}/epi_rest_topup.nii.gz'
    params:
        epi = 'output/preprocessing/slicetimer/{subject}/rest/st_rest',
        mat = 'output/preprocessing/motioncor/{subject}/epi_rest_mc.nii.gz.mat',
        mni = config['MNI']  
    group: 'coregistration'
    log: 'logs/combine_warp/{subject}.log'
    singularity: config['fmriprep']
    threads: 8               
    resources:
        time = 240,
        mem_mb = 32000               
    shell:
        "bash scripts/onestepresampling.sh {params.epi} {params.mni} {input.gdc} {params.mat} "
        "{input.topup} {input.bbr} {input.fnirt} {output.warped_mni} &> {log}"

rule ica_aroma:
    input:
        vol = join(config['input_dir'],'analysis',rules.onestep_resampling.output.warped_topup),
        mc = join(config['input_dir'],'analysis',rules.mc_tseries.output.par),
        bbr = join(config['input_dir'],'analysis',rules.bbr.output.mat),
        fnirt = join(config['input_dir'],'analysis',rules.fnirt.output.cout),
        mask = join(config['input_dir'],'analysis',rules.mask_epi.output.mask)
    output:
        den = join(config['input_dir'],'analysis/output/denoising/ica_melodic/epi/{subject}/denoised_func_data_nonaggr.nii.gz')
    singularity: config['fmriprep']
    threads: 8     
    resources:
        time = 180,
        mem_mb = 32000  
    shell:
        "python /opt/ICA-AROMA/ICA_AROMA.py -o `dirname {output.den}` -i {input.vol} -mc {input.mc} "
        "-a {input.bbr} -w {input.fnirt} -m {input.mask} -tr 2 -den nonaggr -overwrite"

rule transform_ica_aroma:
    input:
        vol = rules.ica_aroma.output.den,
        warp = rules.fnirt.output.fout,
        mni = config['MNI']
    output: 'output/denoising/ica_melodic/mni/{subject}/denoised_func_data_nonaggr_mni.nii.gz'
    singularity: config['fmriprep']    
    threads: 8     
    resources:
        mem_mb = 32000  
    shell:
        "applywarp -i {input.vol} -r {input.mni} -o {output} -w {input.warp} --rel --interp=spline -v"