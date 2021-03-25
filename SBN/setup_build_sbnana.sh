#!/bin/bash
source /cvmfs/larsoft.opensciencegrid.org/products/setup
source /cvmfs/sbn.opensciencegrid.org/products/sbn/setup

export MRB_PROJECT=sbnana
setup mrb

version=$1
quals=$2

#setup larsoft $1 -q $2

mydir="BuildAreas/${version}_sbnana"
mkdir -p $mydir
cd $mydir
mrb newDev -v $version -q $quals
source localProducts*/setup
