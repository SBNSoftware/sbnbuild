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
  echo "Usage: install_from_scisoft.sh [-h|--help] sbndqm-xx.yy.zz"
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

echo $dir
echo $dist


for buildtype in prof
do
  for qual in e20
  do
    pullPackage.sh -r $dir slf7 $dist $qual $buildtype
  done
done

