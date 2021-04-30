function run_smooth(in_file,fwhm,out)

rehash toolboxcache

addpath('./spm12','./spm12/toolbox/suit');

load('./batch_smooth.mat')
matlabbatch{1}.spm.spatial.smooth.data = {in_file};
matlabbatch{1}.spm.spatial.smooth.fwhm = [4 4 4];
matlabbatch{1}.spm.spatial.smooth.dtype = 0;
matlabbatch{1}.spm.spatial.smooth.im = 0;
matlabbatch{1}.spm.spatial.smooth.prefix = 's';

out_mat = [out '/batch_smooth.mat'];
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
