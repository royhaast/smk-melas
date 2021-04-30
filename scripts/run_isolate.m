function run_isolate(in,out)

rehash toolboxcache
addpath('./spm12','./spm12/toolbox/suit');

load('./batch_isolate.mat')
matlabbatch{1}.spm.tools.suit.isolate_seg.source = {{in}};
out_mat = [out '/batch_isolate.mat'];
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