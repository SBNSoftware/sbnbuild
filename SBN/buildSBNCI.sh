#!/bin/bash

# build sbnci
# use mrb
# designed to work on Jenkins
# this is a proof of concept script

echo "experiment: $EXP"
echo "sbnci version: $SBNCI_VERSION"
echo "sbnci tag: $SBN"
echo "base qualifiers: $QUAL"
echo "build type: $BUILDTYPE"
echo "workspace: $WORKSPACE"

# Get number of cores to use.

ncores=`cat /proc/cpuinfo 2>/dev/null | grep -c -e '^processor'`

if [ $ncores -lt 1 ]; then
  ncores=1
fi
echo "Building using $ncores cores."

# Environment setup, uses cvmfs.
if [[ $EXP == "sbnd" ]]; then
  echo "ls /cvmfs/sbnd.opensciencegrid.org"
  ls /cvmfs/sbnd.opensciencegrid.org
  echo
  
  if [ -f /grid/fermiapp/products/sbnd/setup_sbnd.sh ]; then
    source /grid/fermiapp/products/sbnd/setup_sbnd.sh || exit 1
  elif [ -f /cvmfs/sbnd.opensciencegrid.org/products/sbnd/setup_sbnd.sh ]; then 
    if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then
      /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/sbnd.opensciencegrid.org/products/sbnd
    fi
    echo "Setting up sbnd cvmfs"
    source /cvmfs/sbnd.opensciencegrid.org/products/sbnd/setup_sbnd.sh || exit 1
  else
    echo "No sbnd setup file found."
    exit 1
  fi

  opt="-DSBND=ON"

fi

if [[ $EXP == "icarus" ]]; then
  echo "ls /cvmfs/icarus.opensciencegrid.org"
  ls /cvmfs/icarus.opensciencegrid.org
  echo

  if [ -f /cvmfs/icarus.opensciencegrid.org/products/icarus/setup ]; then
    if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then
      /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/icarus.opensciencegrid.org/products/icarus
    fi
    echo "Setting up icarus cvmfs"
    source /cvmfs/icarus.opensciencegrid.org/products/icarus/setup || exit 1
  else
    echo "No icarus setup file found."
    exit 1
  fi

  opt="-DICARUS=ON"

fi

#setup mrb
setup mrb || exit 1

# Use system git on macos.
if ! uname | grep -q Darwin; then
  setup git || exit 1
fi
setup gitflow || exit 1
export MRB_PROJECT=sbnci
echo "Mrb path:"
which mrb

set -x
rm -rf $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1
rm -f $WORKSPACE/copyBack/* || exit 1
cd $WORKSPACE/temp || exit 1
mrb newDev  -v $SBNCI_VERSION -q $QUAL:$BUILDTYPE || exit 1

set +x
source localProducts*/setup || exit 1

set -x
cd $MRB_SOURCE  || exit 1
# make sure we get a read-only copy
mrb g -r https://github.com/SBNSoftware/sbnci@$SBNCI || exit 1

exp_version=`grep ${EXP}code $MRB_SOURCE/sbnci/ups/product_deps | grep -v qualifier | awk '{print $2}'`
exp_dot_version=`echo ${exp_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`
mrb g -r -t ${exp_version} ${EXP}code

cd $MRB_BUILDDIR || exit 1
mrbsetenv || exit 1
mrb b -j$ncores $opt || exit 1
if uname | grep -q Linux; then
  cp /usr/lib64/libXmu.so.6 sbnci/lib
fi
mrb mp -n sbnci -- -j$ncores || exit 1

# Fetch sbndcode or icaruscode manifest from scisoft and append to sbnci manifest.
manifest=sbnci-*_MANIFEST.txt

# Extract flavor.
flvr=`ups flavor -4`

exp_hyphen_qual=`echo $QUAL | tr : - | sed 's/-noifdh//'`
exp_manifest=${EXP}-${expcode_dot_version}-${flvr}-${expcode_hyphen_qual}-${BUILDTYPE}_MANIFEST.txt

curl --fail --silent --location --insecure http://scisoft.fnal.gov/scisoft/bundles/${EXP}/${exp_version}/manifest/${exp_manifest} >> $manifest || exit 1

if echo $QUAL | grep -q noifdh; then
   # Delete the manifest entirely.
  rm -f $manifest
fi

# Save artifacts.

mv *.bz2  $WORKSPACE/copyBack/ || exit 1
manifest=sbn-*_MANIFEST.txt
if [ -f $manifest ]; then
  mv $manifest  $WORKSPACE/copyBack/ || exit 1
fi
cp $MRB_BUILDDIR/sbnci/releaseDB/*.html $WORKSPACE/copyBack/
ls -l $WORKSPACE/copyBack/
cd $WORKSPACE || exit 1
rm -rf $WORKSPACE/temp || exit 1
set +x

exit 0
