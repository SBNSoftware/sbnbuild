#!/bin/bash
cur_dir=$(pwd)

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX --tmpdir=$HOME/tmp)
echo $tmp_dir

cd $tmp_dir
$cur_dir/SciSoftScripts/copyFromJenkins -q c7 sbn-release-build
$cur_dir/SciSoftScripts/copyFromJenkins -q e19 sbn-release-build
$cur_dir/SciSoftScripts/copyFromJenkins -q e20 sbn-release-build

$cur_dir/SciSoftScripts/copyToSciSoft *

cd $cur_dir
rm -rf $tmp_dir
