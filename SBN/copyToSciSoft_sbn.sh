#!/bin/bash
cur_dir=$(pwd)

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX --tmpdir=/icarus/data/users/wketchum/tmp)
echo $tmp_dir

cd $tmp_dir
~/jenkinssbn/copyFromJenkins -q c7 sbn-release-build
~/jenkinssbn/copyFromJenkins -q e19 sbn-release-build
~/jenkinssbn/copyFromJenkins -q e20 sbn-release-build

~/jenkinssbn/copyToSciSoft *

cd $cur_dir
rm -rf $tmp_dir
