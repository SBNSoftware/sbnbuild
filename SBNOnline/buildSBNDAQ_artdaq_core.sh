#!/bin/bash

echo "build sbndaq_artdaq_core"

# build sbndaq_artdaq_core
# use mrb?

# designed to work on Jenkins

# this is a proof of concept script

echo "sbndaq_artdaq_core version: $SBNDAQ"

echo "sbndaq_artdaq_core branch: $SBNDAQ_BRANCH"

echo "base qualifiers: $QUAL"

echo "build type: $BUILDTYPE"

echo "workspace: $WORKSPACE"

# Don't support MAC OS X builds for now (forever?)
# Please don't be mad Tracy.

if [ `uname` = Darwin ]; then
    echo "Sorry ... not support MAC OS X builds right now."
    echo " :( "
    echo " ha ha who gets the last laugh! :-)"
    #exit 1
fi



# Get number of cores to use.

ncores=`cat /proc/cpuinfo 2>/dev/null | grep -c -e '^processor'`

if [ $ncores -lt 1 ]; then
  ncores=1
fi

echo "Building using $ncores cores."


# Environment setup, uses /grid/fermiapp or cvmfs ...
#TODO use icarus area, but will want to standardize this I think...

#if [ -f /cvmfs/icarus.opensciencegrid.org/products/icarus/setup_icarus.sh ]; then
#
#  if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then
#    /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/icarus.opensciencegrid.org/products/icarus
#  fi
#  source /cvmfs/icarus.opensciencegrid.org/products/icarus/setup_icarus.sh || exit 1
#
#else
#  echo "No setup file found."
#  exit 1
#fi
source /LArSoft/Products/setups


setup gitflow || exit 1
export MRB_PROJECT=sbndaq_artdaq_core
echo "Mrb path:"
which mrb

set -x
rm -rf $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1
rm -f $WORKSPACE/copyBack/* || exit 1
cd $WORKSPACE/temp || exit 1

mrb newDev -v $SBNDAQ -q $QUAL:$BUILDTYPE || exit 1

set +x

source localProducts*/setup || exit 1

set -x

cd $MRB_SOURCE  || exit 1

# make sure we get a read-only copy
#pull from the SBNSoftware git repository
mrb g -r -b $SBNDAQ_BRANCH -d sbndaq_artdaq_core https://github.com/SBNSoftware/sbndaq-artdaq-core.git || exit 1

#get artdaq_core version
artdaq_core_version=`grep 'artdaq_core ' $MRB_SOURCE/sbndaq_artdaq_core/ups/product_deps | grep -v qualifier | awk '{print $2}'`

setup artdaq_core $artdaq_core_version -q$QUAL:$BUILDTYPE
deploy_artdaq_core=$?
if [ $deploy_artdaq_core -ne 0 ]; then
    echo "Pulling down and building artdaq_core"
    mrb g -r -t $artdaq_core_version -d artdaq_core artdaq-core || exit 1
fi

cd $MRB_BUILDDIR || exit 1

mrbsetenv || exit 1

mrb b -j$ncores || exit 1

#Not needed for sbndaq_artdaq_core? not sure ... gonna leave...
#if uname | grep -q Linux; then
#
#  cp /usr/lib64/libXmu.so.6 sbndaq_artdaq_core/lib
#
#fi

mrb mp -n sbndaq_artdaq_core -- -j$ncores || exit 1

# add icarus_data to the manifest

manifest=sbndaq_artdaq_core-*_MANIFEST.txt

#icarus_data_version=`grep icarus_data $MRB_SOURCE/icaruscode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
#icarus_data_dot_version=`echo ${icarus_data_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
#echo "icarus_data          ${icarus_data_version}       icarus_data-${icarus_data_dot_version}-noarch.tar.bz2" >>  $manifest

# Extract larsoft version from product_deps.

#larsoft_version=`grep larsoft $MRB_SOURCE/icaruscode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
#larsoft_dot_version=`echo ${larsoft_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`

# Extract flavor.

flvr=''

if uname | grep -q Darwin; then

  flvr=`ups flavor -2`

else

  flvr=`ups flavor -4`

fi

# Construct name of larsoft manifest.

#larsoft_hyphen_qual=`echo $LARSOFT_QUAL | tr : - | sed 's/-noifdh//'`
#larsoft_manifest=larsoft-${larsoft_dot_version}-${flvr}-${larsoft_hyphen_qual}-${BUILDTYPE}_MANIFEST.txt
#echo "Larsoft manifest:"
#echo $larsoft_manifest
#echo

# Fetch larsoft manifest from scisoft and append to icaruscode manifest.

#curl --fail --silent --location --insecure http://scisoft.fnal.gov/scisoft/bundles/larsoft/${larsoft_version}/manifest/${larsoft_manifest} >> $manifest || exit 1

# Special handling of noifdh builds goes here.

if echo $QUAL | grep -q noifdh; then
  if uname | grep -q Darwin; then
    # If this is a macos build, then rename the manifest to remove noifdh qualifier in the name
    noifdh_manifest=`echo $manifest | sed 's/-noifdh//'`
    mv $manifest $noifdh_manifest
  else
    # Otherwise (for slf builds), delete the manifest entirely.
    rm -f $manifest
  fi
fi

# Save artifacts.

mkdir -p /pnfs/icarus/scratch/users/$USER/scratch/
cp *.bz2 /pnfs/icarus/scratch/users/$USER/scratch/

mv *.bz2  $WORKSPACE/copyBack/ || exit 1

manifest=sbndaq_artdaq_core-*_MANIFEST.txt

if [ -f $manifest ]; then

  mv $manifest  $WORKSPACE/copyBack/ || exit 1

fi

cp $MRB_BUILDDIR/sbndaq_artdaq_core/releaseDB/*.html $WORKSPACE/copyBack/

ls -l $WORKSPACE/copyBack/

cd $WORKSPACE || exit 1

rm -rf $WORKSPACE/temp || exit 1

set +x

exit 0


