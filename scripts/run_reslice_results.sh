#!usr/bin/bash
script=$1
script_dir=`readlink -f $script`
script_dir=$(dirname "${script_dir}")
script=`basename $script .m`

affine=`realpath $2`
flowfield=`realpath $3`
ref=`realpath $4`

in_file=`realpath $5`
in_filename=`basename $in_file .nii`

out_file=`realpath $6`
out_dir=`realpath $7`
mkdir -p $out_dir

#cp $in_file $out_dir/${in_filename}.nii

module load matlab

pushd $script_dir
    matlab -nosplash -nodisplay -nodesktop -r "${script}('${affine}','${flowfield}','${ref}','${in_file}'); quit"
popd

affine_dir=$(dirname "${affine}")
mv $affine_dir/iw*$in_filename*.nii $out_file
#rm $affine_dir/iw*$in_filename*.nii