#!usr/bin/bash
script=$1
script_dir=`readlink -f $script`
script_dir=$(dirname "${script_dir}")
script=`basename $script .m`

gm=$2
gm=`realpath $gm`

wm=$3
wm=`realpath $wm`

mask=$4
mask=`realpath $mask`

out=$5
out_dir=`realpath $out`

module load matlab

pushd $script_dir
    echo matlab -nosplash -nodisplay -nodesktop -r "${script}('${gm}','${wm}','${mask}','${out_dir}'); quit"
    matlab -nosplash -nodisplay -nodesktop -r "${script}('${gm}','${wm}','${mask}','${out_dir}'); quit"
popd