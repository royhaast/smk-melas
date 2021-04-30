#!usr/bin/bash
script=$1
script_dir=`readlink -f $script`
script_dir=$(dirname "${script_dir}")
script=`basename $script .m`

affine=`realpath $2`
flowfield=`realpath $3`
wm=`realpath $4`
gm=`realpath $5`
r1=`realpath $6`
mask=`realpath $7`
out_dir=`realpath $8`

r1map=$out_dir/r1_map_$9.nii

if (file $r1 | grep -q compressed ) ; then
    gunzip -k -c $t1 > $t1map
fi

module load matlab

pushd $script_dir
    matlab -nosplash -nodisplay -nodesktop -r "${script}('${affine}','${flowfield}','${wm}','${mask}','${out_dir}'); quit"
    matlab -nosplash -nodisplay -nodesktop -r "${script}('${affine}','${flowfield}','${gm}','${mask}','${out_dir}'); quit"
    matlab -nosplash -nodisplay -nodesktop -r "${script}('${affine}','${flowfield}','${r1}','${mask}','${out_dir}'); quit"
    matlab -nosplash -nodisplay -nodesktop -r "${script}_atlas('${affine}','${flowfield}','${gm}'); quit"
popd