#!/bin/bash
source /cvmfs/fermilab.opensciencegrid.org/products/artdaq/setup
source /cvmfs/larsoft.opensciencegrid.org/setup_larsoft.sh
source /cvmfs/sbn.opensciencegrid.org/products/sbn/setup

export MRB_PROJECT=sbndqm
setup mrb
setup gitflow

version=$1
quals=$2

datestring=`date +%d.%m.%Y_%H%M%S`

mydir="BuildAreas/sbndqm_${version}_${datestring}"
mkdir -p $mydir
cd $mydir
mrb newDev -v $version -q $quals
source localProducts*/setup
