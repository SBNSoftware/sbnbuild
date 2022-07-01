#! /bin/bash
#------------------------------------------------------------------
#
# Name: install_from_scisoft.sh
#
# Purpose: Fetch release from scisoft build server and install.
#
# Usage: 
#
# install_from_scisoft.sh sbn-xx.yy.zz
#
# This script assumes that script pullProducts is available on
# the execution path.  If necessary, download pullProducts from
# http://scisoft.fnal.gov/scisoft/bundles/tools, and make it 
# executable on your execution path.
#
# This script does one invocation of pullProducts for each
# supported binary flavor or sbncode.
#
# Shamelessly stolen and modified from sbnd:  07-Oct-2020  A. Scarff
# Originally created:  18-Mar-2015  H. Greenlee
#
#------------------------------------------------------------------

# Help function.

function dohelp {
  echo "Usage: install_from_scisoft.sh [-h|--help] sbnana-xx.yy.zz"
}

# Parse arguments.

if [ $# -eq 0 ]; then
  dohelp
  exit 1
fi

dist=''

while [ $# -gt 0 ]; do
  case "$1" in

    # Help.

    -h|--help )
      dohelp
      exit 1
      ;;

    # Other options.

    -* )
      echo "Unrecognized option $1"
      dohelp
      exit
      ;;

    # Positional.

    * )
      if [ x$dist = x ]; then
        dist=$1
      else
        echo "Too many arguments."
        dohelp
        exit 1
      fi

  esac
  shift
done

# Test for all required arguments.

if [ x$dist = x ]; then
  echo "Missing required argument(s)."
  dohelp
  exit 1
fi

# Set up the required paths
export PATH=$PATH:/home/cvmfssbn/scripts/
source setProducts.sh

# Make sure ups has been initialized, so that we don't install products 
# unnecessarily.

if [ x$PRODUCTS = x ]; then
  echo "Initialize ups first."
  exit
fi

# Do fetch.

dir=/cvmfs/sbn.opensciencegrid.org/products/sbn/
#dir=/home/cvmfssbn/temp/
qual1=e20
qual2=c7

echo $dir
echo $dist


for buildtype in debug prof
do
  for qual in e20 c7
  do
    pullPackage.sh -r $dir slf7 $dist $qual $buildtype
  done
done

# Post-processing for default versions
version=v${dist:5:2}_${dist:8:2}_${dist:11:2}
#version=v08_36_01_3_MCP2_0
versiondir=${dir}/sbndcode/${version}.version
upsdir=${dir}/sbndcode/${version}/ups

# Check both directories exist
if [ ! -d "$versiondir" ]; then
  echo "Version directory doesn't exist!"
  exit
fi
if [ ! -d "$upsdir" ]; then
  echo "UPS directory doesn't exist!"
  exit
fi

# Copy version files for each OS and remove qualifiers
for os in Linux64bit+2.6-2.12  Linux64bit+3.10-2.17 
do
  cp ${versiondir}/${os}_e17_prof ${versiondir}/${os}
  sed -i -e 's/e17:prof//g' ${versiondir}/${os}
done
#for os in Darwin64bit+16 
#do
#  cp ${versiondir}/${os}_c2_prof ${versiondir}/${os}
#  sed -i -e 's/c2:prof//g' ${versiondir}/${os}
#done

if [ $(wc -l < ${upsdir}/sbndcode.table) != 193 ]; then
  echo "sbndcode.table FILE HAS CHANGED SIZE!"
  exit
fi

# Copy e17:prof/c2:prof block from table file and remove qualifiers
# Now need to specify flavour for default setup
sed -i 6r<(sed '97,114!d' ${upsdir}/sbndcode.table) ${upsdir}/sbndcode.table
sed -i -e '0,/e17:prof/s/e17:prof//' ${upsdir}/sbndcode.table
sed -i -e '0,/ANY/s/ANY/Linux64bit+2.6-2.12/' ${upsdir}/sbndcode.table

sed -i 6r<(sed '115,132!d' ${upsdir}/sbndcode.table) ${upsdir}/sbndcode.table
sed -i -e '0,/e17:prof/s/e17:prof//' ${upsdir}/sbndcode.table
sed -i -e '0,/ANY/s/ANY/Linux64bit+3.10-2.17/' ${upsdir}/sbndcode.table

#sed -i 6r<(sed '97,114!d' ${upsdir}/sbndcode.table) ${upsdir}/sbndcode.table
#sed -i -e '0,/c2:prof/s/c2:prof//' ${upsdir}/sbndcode.table
#sed -i -e '0,/ANY/s/ANY/Darwin64bit+16/' ${upsdir}/sbndcode.table
