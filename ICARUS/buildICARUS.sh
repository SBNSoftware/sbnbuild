#!/bin/bash

echo "build ICARUS"
#chmod u+x larutils/buildScripts/buildICARUS.sh
#./larutils/buildScripts/buildICARUS.sh

# build icaruscode and icarusutil 

# use mrb

# designed to work on Jenkins

# this is a proof of concept script

echo "icaruscode version: $ICARUS"

echo "base qualifiers: $QUAL"

echo "larsoft qualifiers: $LARSOFT_QUAL"

echo "build type: $BUILDTYPE"

echo "workspace: $WORKSPACE"

# Don't do ifdh build on macos.

#if uname | grep -q Darwin; then

#  if ! echo $QUAL | grep -q noifdh; then

#    echo "Ifdh build requested on macos.  Quitting."

#    exit

#  fi

#fi

# Get number of cores to use.

if [ `uname` = Darwin ]; then

  #ncores=`sysctl -n hw.ncpu`

  #ncores=$(( $ncores / 4 ))

  ncores=1

else

  ncores=`cat /proc/cpuinfo 2>/dev/null | grep -c -e '^processor'`

fi

if [ $ncores -lt 1 ]; then

  ncores=1

fi

echo "Building using $ncores cores."

# Environment setup, uses /grid/fermiapp or cvmfs.

echo "ls /cvmfs/icarus.opensciencegrid.org"

ls /cvmfs/icarus.opensciencegrid.org

echo

if [ -f /cvmfs/icarus.opensciencegrid.org/products/icarus/setup_icarus.sh ]; then

  if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then

    /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/icarus.opensciencegrid.org/products/icarus

  fi

  source /cvmfs/icarus.opensciencegrid.org/products/icarus/setup_icarus.sh || exit 1

else

  echo "No setup file found."

  exit 1

fi

# Use system git on macos.

if ! uname | grep -q Darwin; then

  setup git || exit 1

fi

setup gitflow || exit 1

export MRB_PROJECT=icarus

echo "Mrb path:"

which mrb

set -x

rm -rf $WORKSPACE/temp || exit 1

mkdir -p $WORKSPACE/temp || exit 1

mkdir -p $WORKSPACE/copyBack || exit 1

rm -f $WORKSPACE/copyBack/* || exit 1

cd $WORKSPACE/temp || exit 1

mrb newDev  -v $ICARUS -q $QUAL:$BUILDTYPE || exit 1

set +x

source localProducts*/setup || exit 1

# some shenanigans so we can use getopt v1_1_6

if [ `uname` = Darwin ]; then

#  cd $MRB_INSTALL

#  curl --fail --silent --location --insecure -O http://scisoft.fnal.gov/scisoft/packages/getopt/v1_1_6/getopt-1.1.6-d13-x86_64.tar.bz2 || \

#      { cat 1>&2 <<EOF

#ERROR: pull of http://scisoft.fnal.gov/scisoft/packages/getopt/v1_1_6/getopt-1.1.6-d13-x86_64.tar.bz2 failed

#EOF

#        exit 1

#      }

#  tar xf getopt-1.1.6-d13-x86_64.tar.bz2 || exit 1

  setup getopt v1_1_6  || exit 1

#  which getopt

fi

set -x

cd $MRB_SOURCE  || exit 1

# make sure we get a read-only copy

mrb g -r -t $ICARUS icaruscode || exit 1

# Extract icarusutil version from icaruscode product_deps

icarusutil_version=`grep icarusutil $MRB_SOURCE/icaruscode/ups/product_deps | grep -v qualifier | awk '{print $2}'`

echo "icarusutil version: $icarusutil_version"

mrb g -r -t $icarusutil_version icarusutil || exit 1

cd $MRB_BUILDDIR || exit 1

mrbsetenv || exit 1

mrb b -j$ncores || exit 1

if uname | grep -q Linux; then

  cp /usr/lib64/libXmu.so.6 icaruscode/lib

fi

mrb mp -n icarus -- -j$ncores || exit 1

# add icarus_data to the manifest

manifest=icarus-*_MANIFEST.txt

icarus_data_version=`grep icarus_data $MRB_SOURCE/icaruscode/ups/product_deps | grep -v qualifier | awk '{print $2}'`

icarus_data_dot_version=`echo ${icarus_data_version} | sed -e 's/_/./g' | sed -e 's/^v//'`

echo "icarus_data          ${icarus_data_version}       icarus_data-${icarus_data_dot_version}-noarch.tar.bz2" >>  $manifest

# Extract larsoft version from product_deps.

larsoft_version=`grep larsoft $MRB_SOURCE/icaruscode/ups/product_deps | grep -v qualifier | awk '{print $2}'`

larsoft_dot_version=`echo ${larsoft_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`

# Extract flavor.

flvr=''

if uname | grep -q Darwin; then

  flvr=`ups flavor -2`

else

  flvr=`ups flavor -4`

fi

# Construct name of larsoft manifest.

larsoft_hyphen_qual=`echo $LARSOFT_QUAL | tr : - | sed 's/-noifdh//'`

larsoft_manifest=larsoft-${larsoft_dot_version}-${flvr}-${larsoft_hyphen_qual}-${BUILDTYPE}_MANIFEST.txt

echo "Larsoft manifest:"

echo $larsoft_manifest

echo

# Fetch larsoft manifest from scisoft and append to icaruscode manifest.

curl --fail --silent --location --insecure http://scisoft.fnal.gov/scisoft/bundles/larsoft/${larsoft_version}/manifest/${larsoft_manifest} >> $manifest || exit 1

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

cp *.bz2 /pnfs/icarus/scratch/users/usher/scratch/

mv *.bz2  $WORKSPACE/copyBack/ || exit 1

manifest=icarus-*_MANIFEST.txt

if [ -f $manifest ]; then

  mv $manifest  $WORKSPACE/copyBack/ || exit 1

fi

cp $MRB_BUILDDIR/icaruscode/releaseDB/*.html $WORKSPACE/copyBack/

ls -l $WORKSPACE/copyBack/

cd $WORKSPACE || exit 1

rm -rf $WORKSPACE/temp || exit 1

set +x

exit 0


