import numpy as np
import pandas as pd
import nibabel as nib
from nibabel.nifti1 import Nifti1Image

t1 = nib.load(snakemake.input.t1)
t1_vals = t1.get_fdata()

lh_cerebellum = nib.load(snakemake.input.lh_cerebellum).get_fdata()
rh_cerebellum = nib.load(snakemake.input.rh_cerebellum).get_fdata()

combined = np.zeros((t1.shape))
combined[(lh_cerebellum>0) & (t1_vals<2000)] = 8
combined[(rh_cerebellum>0) & (t1_vals<2000)] = 47

img = Nifti1Image(combined,t1.affine,t1.header)
nib.save(img,snakemake.output[0])