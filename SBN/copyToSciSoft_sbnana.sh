#!/bin/bash
cur_dir=$(pwd)

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX --tmpdir=/icarus/data/users/wketchum/tmp)
echo $tmp_dir

cd $tmp_dir
~/jenkinssbn/copyFromJenkins -q c7 sbnana-release-build
~/jenkinssbn/copyFromJenkins -q e19 sbnana-release-build

rm *.txt

~/jenkinssbn/copyToSciSoft *

cd $cur_dir
rm -rf $tmp_dir
