import os

import nibabel as nib
import numpy as np
from nilearn.plotting import plot_roi, plot_stat_map

import nimare
from nimare import annotate, decode
from nimare.tests.utils import get_test_data_path
from neurosynth.base.dataset import download

dset = nimare.dataset.Dataset.load("/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_neurosynth/neurosynth_nimare_with_abstracts.pkl.gz")

counts_df = annotate.text.generate_counts(
    dset.texts, text_column="abstract", tfidf=False, max_df=0.99, min_df=0
)

model = annotate.gclda.GCLDAModel(
    counts_df, dset.coordinates, mask=dset.masker.mask_img
)

model.fit(n_iters=5, loglikely_freq=20)

model.save("/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_neurosynth/gclda_model.pkl.gz")

decoded_df, _ = decode.continuous.gclda_decode_map(model, encoded_img)
decoded_df.sort_values(by="Weight", ascending=False).head(10)
