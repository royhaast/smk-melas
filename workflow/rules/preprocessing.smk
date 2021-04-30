rule slicetimer:
    input: join(config['input_dir'],'data/{subject}/rsfmri/{scan}.nii.gz')
    output: 
        corrected ='output/preprocessing/slicetimer/{subject}/st_{scan}.nii.gz',
        splitted = 'output/preprocessing/slicetimer/{subject}/{scan}/st_{scan}_0000.nii.gz'        
    params:
        slicetiming = config['slicetiming']
    group: 'preprocessing'     
    singularity: config['fmriprep']
    log: 'logs/slicetimer/{subject}_{scan}.log'
    threads: 8
    resources:
        time = 60,
        mem_mb = 32000    
    shell:
        "TR=`fslval {input[0]} pixdim4` && "
        "3dTshift -prefix {output.corrected} -tpattern @{params.slicetiming} -TR $TR -tzero 0.0 {input} && "
        "fslsplit {output.corrected} `echo {output.splitted} | rev | cut -d'_' -f2-  | rev`_ -t &> {log}"

rule gradient_unwarp:
    input: 'output/slicetimer/{subject}/st_rest.nii.gz'
    output:
        firstvol = 'output/preprocessing/gradcorrect/{subject}/epi_rest_firstvol.nii.gz',
        warp = 'output/preprocessing/gradcorrect/{subject}/epi_gdc_warp.nii.gz',
    params:
        coeff = config['coeff'],
        scratch = directory('output/gradcorrect/{subject}/scratch')
    group: 'preprocessing'
    log: 'logs/gradient_unwarp/{subject}.log'             
    singularity: config['gradcorrect']
    threads: 8
    resources:
        time = 30,
        mem_mb = 32000    
    shell:
        "fslroi {input} {output.firstvol} 0 1 && "
        "procGradCorrect -i {output.firstvol} -g {params.coeff} -w {output.warp} -s {params.scratch} &> {log}"

rule apply_gradient_unwarp:
    input:
        epi = rules.slicetimer.output.corrected,
        warp = rules.gradient_unwarp.output.warp
    output:
        unwarped = 'output/preprocessing/gradcorrect/{subject}/epi_{scan}_unwarped.nii.gz',
        jacobian = 'output/preprocessing/gradcorrect/{subject}/epi_{scan}_jacobian.nii.gz',
        corrected = 'output/preprocessing/gradcorrect/{subject}/epi_{scan}_intcor.nii.gz'
    group: 'preprocessing'          
    singularity: config['gradcorrect']
    threads: 8
    resources:
        time = 30,
        mem_mb = 32000             
    shell:
        "applywarp -i {input.epi} -o {output.unwarped} -r {input.epi} -w {input.warp} --abs --interp=spline && "
        "fslroi {output.unwarped} {output.jacobian} 0 1 && "
        "reg_jacobian -ref {output.jacobian} -def {input.warp} -jac {output.jacobian} && "
        "fslmaths {output.jacobian} -mul -1 -abs {output.jacobian} && "
        "fslmaths {output.unwarped} -mul {output.jacobian} {output.corrected} && "
        "fslcpgeom {input.epi} {output.corrected}"

rule prep_topup:
    input: expand('output/gradcorrect/{{subject}}/epi_{scan}_intcor.nii.gz', scan=config['scans'])
    output:
        first_vols = 'output/preprocessing/topup/{subject}/prep_topup/epi_rest_firstvols.nii.gz',
        concat_out = 'output/preprocessing/topup/{subject}/prep_topup/epi_rest-topup_concat.nii.gz'
    group: 'preprocessing'
    singularity: config['fmriprep']
    threads: 8
    resources:
        time = 30,
        mem_mb = 32000          
    shell:
        "fslroi {input[0]} {output.first_vols} 0 5 && "
        "fslmerge -tr {output.concat_out} {output.first_vols} {input[1]} 2"

rule run_topup:
    input: rules.prep_topup.output.concat_out
    output: directory('output/preprocessing/topup/{subject}/run_topup')
    params: 
        topup = config['topup_config'],
        acquisition = config['acqparams']
    group: 'preprocessing'        
    log: 'logs/run_topup/{subject}.log'
    singularity: config['fmriprep'] 
    threads: 8
    resources:
        time = 360,
        mem_mb = 32000
    shell:
        "mkdir -p {output} && "
        "topup --imain={input} --datain={params.acquisition} --config={params.topup} "
        "--out={output}/epi --fout={output}/epi_fout --iout={output}/epi_iout -v &> {log}"

rule mc_tseries:
    input: 'output/preprocessing/gradcorrect/{subject}/epi_rest_intcor.nii.gz'
    output:
        vol = 'output/preprocessing/motioncor/{subject}/epi_rest_mc.nii.gz',
        par = 'output/preprocessing/motioncor/{subject}/epi_rest_mc.nii.gz.par'
    params:
        optional = '-refvol 0 -sinc_final -plots -mats -verbose 2'
    group: 'preprocessing'
    log: 'logs/motioncor/{subject}.log'
    singularity: config['fmriprep']
    threads: 8
    resources:
        time = 60,
        mem_mb = 32000     
    shell:
        "mcflirt -in {input} -out {output.vol} {params.optional} &> {log}"

rule apply_topup:
    input:
        epi = rules.mc_tseries.output.vol,
        topup = rules.run_topup.output
    output:
        gdc = 'output/preprocessing/topup/{subject}/apply_topup/epi_rest_gdc.nii.gz',
        firstvol = 'output/preprocessing/topup/{subject}/apply_topup/epi_rest_firstvol.nii.gz',
        firstvol_gdc = 'output/preprocessing/topup/{subject}/apply_topup/epi_rest_firstvol_gdc.nii.gz'
    params:
        acquisition = config['acqparams']
    group: 'preprocessing'
    log: 'logs/apply_topup/{subject}.log'
    singularity: config['fmriprep']
    threads: 8
    resources:
        time = 60,
        mem_mb = 32000             
    shell:
        "fslroi {input.epi} {output.firstvol} 0 1 && "
        "applytopup --imain={output.firstvol} --inindex=1 --datain={params.acquisition} --topup={input.topup}/epi --out={output.firstvol_gdc} --method=jac -v &> {log} && "
        "applytopup --imain={input.epi} --inindex=1 --datain={params.acquisition} --topup={input.topup}/epi --out={output.gdc} --method=jac -v &> {log}"

rule mask_epi:
    input: rules.apply_topup.output.firstvol_gdc
    output: mask = 'output/preprocessing/mask/epi/{subject}/epi_mask.nii.gz'
    singularity: config['fmriprep']
    shell:
        "bet {input.mask} {output} -f 0.3 -n -m -R"