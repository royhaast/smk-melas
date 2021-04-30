import numpy as np
from brainsmash.workbench.geo import volume

coord_file = "/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_brainsmash_vol/coord.txt"
output_dir = "/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_brainsmash_vol/"

filenames = volume(coord_file, output_dir, chunk_size=2500)

np.savetxt("/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_brainsmash_vol/completed.txt", ['Brainsmash finished'])