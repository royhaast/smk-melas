#!usr/bin/bash
script=$1
script_dir=`readlink -f $script`
script_dir=$(dirname "${script_dir}")
script=`basename $script .m`

in=$2
in=`realpath $in`

out=$3
out_dir=`realpath $out`

module load matlab

pushd $script_dir
    matlab -nosplash -nodisplay -nodesktop -r "${script}('${in}','${out_dir}'); quit"
popd