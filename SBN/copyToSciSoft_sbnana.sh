#!/bin/bash
cur_dir=$(pwd)

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX --tmpdir=$HOME/tmp)
echo $tmp_dir

cd $tmp_dir
$cur_dir/SciSoftScripts/copyFromJenkins -q c7 sbnana-release-build
$cur_dir/SciSoftScripts/copyFromJenkins -q e19 sbnana-release-build
#$cur_dir/SciSoftScripts/copyFromJenkins -q e20 sbnana-release-build

rm *.txt

$cur_dur/SciSoftScripts/copyToSciSoft *

cd $cur_dir
rm -rf $tmp_dir
