function run_reslice(affine,flowfield,image,mask,out)

rehash toolboxcache
addpath('./spm12','./spm12/toolbox/suit');

load('./batch_reslice.mat')
matlabbatch{1}.spm.tools.suit.reslice_dartel.subj.affineTr = {affine};
matlabbatch{1}.spm.tools.suit.reslice_dartel.subj.flowfield = {flowfield};
matlabbatch{1}.spm.tools.suit.reslice_dartel.subj.resample = {image};
matlabbatch{1}.spm.tools.suit.reslice_dartel.subj.mask = {mask};

if contains(image,'r1')
    matlabbatch{1}.spm.tools.suit.reslice_dartel.jactransf = 0;
end

out_mat = [out '/batch_reslice.mat'];
save(out_mat,'matlabbatch');

nrun = 1; % enter the number of runs here
jobfile = {out_mat};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(0, nrun);
for crun = 1:nrun
end

spm('defaults', 'FMRI');
spm_jobman('run', jobs, inputs{:});

end