import time
import numpy as np
from brainsmash.mapgen.sampled import Sampled

brain_data = "/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_brainsmash_vol/brain_map.txt"
D_file     = "/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_brainsmash_vol/distmat.npy"
index_file = "/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_brainsmash_vol/index.npy"

out_data   = "/project/6050199/rhaast/03_Ongoing/melas/fmri/notebooks/out_brainsmash_vol/1000_surrogates.npy"

kwargs = {'ns': 500,
          'knn': 1500,
          'pv': 70,
          'verbose': True
          }

print('Started sampling data...')

t = time.time()
gen = Sampled(x=brain_data, D=D_file, index=index_file, **kwargs)
elapsed = time.time()-t

print('Sampling data took: ')
print(elapsed)

t = time.time()
surrogate_maps = gen(n=1000)
elapsed = time.time()-t

print('Computing surrogate maps took: ')
print(elapsed)

np.save(out_data, surrogate_maps)

print('Finished')
