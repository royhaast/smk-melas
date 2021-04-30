function run_reslice_atlas(affine,flowfield,ref,image)

rehash toolboxcache
addpath('./spm12','./spm12/toolbox/suit','./spm12/toolbox/DARTEL','./spm12/toolbox/OldSeg');

job.Affine = {affine};
job.flowfield = {flowfield};
job.ref = {ref};
job.resample = {image};

suit_reslice_dartel_inv(job);

end