#!/bin/bash
source /cvmfs/larsoft.opensciencegrid.org/setup_larsoft.sh
source /cvmfs/sbn.opensciencegrid.org/products/sbn/setup

export MRB_PROJECT=larsoft
setup mrb

version=$1
quals=$2

datestring=`date +%d.%m.%Y_%H%M%S`

setup larsoft $1 -q $2

mydir="BuildAreas/${version}_sbn_${datestring}"
mkdir -p $mydir
cd $mydir
mrb newDev -v $version -q $quals
source localProducts*/setup
