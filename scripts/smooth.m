function run_reslice(affine,flowfield,image,mask,out)

addpath('./spm12','./spm12/toolbox/suit');

load('./batch_smooth.mat')


out_mat = [out '/batch_smooth.mat'];
save(out_mat,'matlabbatch');

% List of open inputs
nrun = X; % enter the number of runs here
jobfile = {'/home/ROBARTS/rhaast/graham/scratch/MELAS/fmri/scripts/smooth_job.m'};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(0, nrun);
for crun = 1:nrun
end
spm('defaults', 'FMRI');
spm_jobman('run', jobs, inputs{:});
