function run_normalise(gm,wm,mask,out)

rehash toolboxcache
addpath('./spm12','./spm12/toolbox/suit');

load('./batch_normalise.mat')
matlabbatch{1}.spm.tools.suit.normalise_dartel.subjND.gray = {gm};
matlabbatch{1}.spm.tools.suit.normalise_dartel.subjND.white = {wm};
matlabbatch{1}.spm.tools.suit.normalise_dartel.subjND.isolation = {mask};
out_mat = [out '/batch_normalise.mat'];
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