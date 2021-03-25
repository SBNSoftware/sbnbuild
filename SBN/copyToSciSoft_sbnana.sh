#!/bin/bash
cur_dir=$(pwd)

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX --tmpdir=$HOME/tmp)
echo $tmp_dir

cd $tmp_dir
$cur_dir/ScisoftScripts/copyFromJenkins -q c7 sbnana-release-build
$cur_dir/ScisoftScripts/copyFromJenkins -q e19 sbnana-release-build
$cur_dir/ScisoftScripts/copyFromJenkins -q e20 sbnana-release-build

rm *.txt

$cur_dir/ScisoftScripts/copyToSciSoft *

cd $cur_dir
rm -rf $tmp_dir
