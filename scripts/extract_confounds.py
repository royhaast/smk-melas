import numpy as np
import pandas as pd
import nibabel as nib
from nibabel.nifti1 import Nifti1Image
from nilearn.input_data import NiftiLabelsMasker

epi = nib.load(snakemake.input.vol)
csf = nib.load(snakemake.input.csf)
wm = nib.load(snakemake.input.wm)

img = Nifti1Image(csf.get_fdata(),epi.affine,csf.header)
masker = NiftiLabelsMasker(labels_img=img, standardize=False)
time_series1 = masker.fit_transform(epi)

img = Nifti1Image(wm.get_fdata(),epi.affine,wm.header)
masker = NiftiLabelsMasker(labels_img=img, standardize=False)
time_series2 = masker.fit_transform(epi)

# Concatenate timeseries
df1 = pd.DataFrame({'CSF': time_series1[:,0],'WhiteMatter': time_series2[:,0]})

# Load movement parameters (and their derivatives)
names = ['X','Y','Z','RotX','RotY','RotZ']
df2 = pd.read_csv(snakemake.input.movreg, names=names, header=None, delim_whitespace=True)

# Put everything together (excluding derivatives) and write to .tsv file for 'ciftify_clean_img' 
df_concat = pd.concat([df2, df1], axis=1)
df_concat.to_csv(snakemake.output[0],sep='\t')