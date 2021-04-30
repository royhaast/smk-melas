#!/bin/bash

# Input volumes
epi=$1
mni=$2

# Relevant transformations
gdc_warp=$3
mc_dir=$4
topup_dir=$5
bbr_mat=$6
fnirt_warp=$7

# Output paths
warped_mni=$8
out_dir=`dirname $warped_mni`

# Generate second warp: gradient distortion corrected to MNI
fslmaths $topup_dir/epi_fout.nii.gz -mul 0.0343097 $topup_dir/epi_fout_scaled.nii.gz
secondwarp=$out_dir/gdc_to_mni.nii.gz
convertwarp -s $topup_dir/epi_fout_scaled.nii.gz -d y- --premat=$bbr_mat --warp1=$fnirt_warp --ref=$mni --out=$secondwarp --relout --rel -v

# Generate seperate warp up to topup correction
intermediatewarp=$out_dir/gdc_to_topup.nii.gz
convertwarp -s $topup_dir/epi_fout_scaled.nii.gz -d y- --ref=${epi}_0000.nii.gz --out=$intermediatewarp --relout --rel -v

for file in $mc_dir/* ; do
    vol=`echo $file | rev | cut -d'_' -f1  | rev`
    epi_vol=${epi}_${vol}

    # Generate first warp: slicetiming corrected to gradient distortion corrected
    firstwarp=$out_dir/firstwarps/st_${vol}_to_gdc.nii.gz

    if [ ! -d $out_dir/firstwarps ] ; then mkdir -p $out_dir/firstwarps ; fi
    convertwarp --warp1=$gdc_warp --midmat=$file --ref=$epi_vol --out=$firstwarp --abs --relout -v

    # Combine with second warp: slicetiming corrected to MNI
    combinedwarp=$out_dir/combinedwarps/st_${vol}_to_MNI.nii.gz

    if [ ! -d $out_dir/combinedwarps ] ; then mkdir -p $out_dir/combinedwarps ; fi
    convertwarp --warp1=$firstwarp --warp2=$secondwarp --out=$combinedwarp --ref=$mni --rel --relout -v

    # Combine with intermediate warp: slicetiming corrected to topup correction
    topupwarp=$out_dir/topupwarps/st_${vol}_to_topup.nii.gz

    if [ ! -d $out_dir/topupwarps ] ; then mkdir -p $out_dir/topupwarps ; fi
    convertwarp --warp1=$firstwarp --warp2=$intermediatewarp --out=$topupwarp --ref=$epi_vol --rel --relout -v

    # Apply warps to MNI
    if [ ! -d $out_dir/warped_mni ] ; then mkdir -p $out_dir/warped_mni ; fi
    applywarp -i $epi_vol -r $mni -o $out_dir/warped_mni/epi_rest_${vol}_mni.nii.gz -w $combinedwarp --rel --interp=spline -v

    # Apply warps to topup correction
    if [ ! -d $out_dir/warped_topup ] ; then mkdir -p $out_dir/warped_topup ; fi    
    applywarp -i $epi_vol -r $epi_vol -o $out_dir/warped_topup/epi_rest_${vol}_topup.nii.gz -w $topupwarp --rel --interp=spline -v
done

# Merge warped output into 4D volume
fslmerge -tr $warped_mni `ls $out_dir/warped_mni/epi_rest_*_mni.nii.gz` 2.0
fslmerge -tr $out_dir/epi_rest_topup.nii.gz `ls $out_dir/warped_topup/epi_rest_*topup.nii.gz` 2.0

# Clean up temporary files
