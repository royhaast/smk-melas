#!usr/bin/bash
script=$1
script_dir=`readlink -f $script`
script_dir=$(dirname "${script_dir}")
script=`basename $script .m`

in_file=`realpath $2`
fwhm=$3
out_dir=`realpath $4`

module load matlab

pushd $script_dir
    matlab -nosplash -nodisplay -nodesktop -r "${script}('${in_file}','${fwhm}','${out_dir}'); quit"
popd