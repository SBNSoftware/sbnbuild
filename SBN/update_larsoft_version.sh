#! /bin/bash
#=======================================================================
#
# Name: update_larsoft_version.sh
#
# Purpose: This script updates dependent product versions in product_deps
#          files located in $MRB_SOURCE/*/ups/product_deps.  It accepts a
#          new larsoft version as its sole argument.  Then it does the
#          following actions.
#
#          1.  Downloads a manifest for this larsoft version from larsoft.
#
#          2.  Parses product_deps files in $MRB_SOURCE/*/ups/product_deps
#              to obtain a list of dependent products.
#
#          3.  Extracts versions of dependent products from the downloaded
#              manifest.
#
#          4.  Issues "mrb uv" commands for each dependent product,
#              including larsoft.
#
#          5.  Updates version, base qualifier, and set qualifier
#              information contained in files
#              $MRB_SOURCE/*/releaseDB/CMakeLists.txt
#
# Usage: update_larsoft_version.sh [-h|--help] [-q <qualifiers>] <version>
#
# Usage notes:
#
# 1.  This script will never update product versions that don't appear in 
#     the larsoft manifest.  This implies that uboone suite package
#     versions will never be updated.
#
# 2.  The environment in which this script should be set up is one in which
#     ups and the local mrb release ($MRB_SOURCE) have been initialized,
#     but uboonecode and larsoft have not been set up.
#
#
# Options:
#
# -h|--help - Print help.
# -q        - Qualifiers.
#
# Agruments:
#
# <version> - New larsoft version.
#
# Created: 8-Mar-2019  H. Greenlee
#
#=======================================================================
# Help function.

function dohelp {
  echo "Usage: update_larsoft_version.sh [-h|--help] [-q <qualifiers>] <version>"
}

# Parse arguments.

if [ $# -eq 0 ]; then
  dohelp
  exit
fi

version=''
qual=''

while [ $# -gt 0 ]; do
  case "$1" in

    # Help.
    -h|--help )
      dohelp
      exit
      ;;

    # Qualifiers.
    -q )
      if [ $# -gt 1 ]; then
        qual=$2
        shift
      fi
      ;;

    * )
      if [ x$version = x ]; then
        version=$1
      else
        echo "Too many arguments."
        dohelp
        exit 1
      fi

  esac
  shift

done

if [ x$version = x ]; then
  echo "No larsoft version specified."
  exit 1
fi

# Make sure MRB_SOURCE is defined.

if [ x$MRB_SOURCE = x ]; then
  echo "Environment variable MRB_SOURCE is not defined."
  exit 1
fi

# Make sure larsoft ups product is not set up, or ups depend command will fail.

if [ x$LARSOFT_DIR != x ]; then
  echo "UPS product larsoft must not be set up."
  exit 1
fi

# Get manifest.

dot_version=`echo ${version} | sed -e 's/_/./g' | sed -e 's/^v//'`
flavor=`ups flavor -4`
ecqual=`echo $qual | tr : '\n' | grep '^[ecp]' | grep -v prof`
ecqual=`echo $ecqual | tr ' ' :`
ecqualdash=`echo $ecqual | tr : -`
btype=`echo $qual | tr : '\n' | egrep 'prof|debug'`
squal=`echo $qual | tr : '\n' | grep '^s'`

# Do some qualifier error checks.

if [ x$ecqual = x ]; then
  echo "No compiler qualifier specified."
  exit 1
fi
if [ x$btype = x ]; then
  echo "No build type (debug or prof) specified."
  exit 1
fi

# If no s-qualifier was specified, get the correct s-qualifier using "ups depend" based
# on dependent version of ifdh_art.

if [ x$squal = x ]; then
  squal=`ups depend larsoft -q $qual $version | grep ifdh_art | rev | awk '{print $1}' | rev | tr : '\n' | grep '^s'`
fi

# Make sure we got an s-qualifier.

if [ x$squal = x ]; then
  echo "Unable to determine s-qualifier."
  exit 1
fi

# Update base qualifier in releaseDB/CMakeLists.txt

for rdb in $MRB_SOURCE/*/releaseDB/CMakeLists.txt
do
  if [ -f "$rdb" ]; then
    sed "s;\([ 	]*set[ 	]*([ 	]*BASEQUAL[ 	][ 	]*\)[^ 	]*\([ 	]*)[ 	]*\)$;\1$ecqual\2;" $rdb > ${rdb}.new
    mv -f ${rdb}.new $rdb
  fi
done

# Update set qualifier in releaseDB/CMakeLists.txt

for rdb in $MRB_SOURCE/*/releaseDB/CMakeLists.txt
do
  if [ -f "$rdb" ]; then
    sed "s;\([ 	]*set[ 	]*([ 	]*SQUAL[ 	][ 	]*\)[^ 	]*\([ 	]*)[ 	]*\)$;\1$squal\2;" $rdb > ${rdb}.new
    mv -f ${rdb}.new $rdb
  fi
done

# Construct manifest url and fetch it.

manifest=larsoft-${dot_version}-${flavor}-${squal}-${ecqualdash}-${btype}_MANIFEST.txt
url=https://scisoft.fnal.gov/scisoft/bundles/larsoft/${version}/manifest/$manifest
mfile=`mktemp`
curl --fail --silent -o $mfile $url
stat=$?
if [ $stat -ne 0 ]; then
  echo "Failed to get manifest using url $url"
  rm -f $mfile
  exit 1
fi

# Loop over dependent products.

awk '/^product/,/^end_product_list/ {print $0}' $MRB_SOURCE/*/ups/product_deps | \
  egrep -v '^product|^end_product_list|only_for_build'  | \
  awk '{print $1}' | \
  sort -u | \
  while read product
do
  if [ x$product != x ]; then

    # Extract version of this product from manifest.

    dver=`grep "^${product} " $mfile | awk '{print $2}' | sort -u | tail -1`
    if [ x$dver != x ]; then

      # Issue "mrb uv" command.

      echo "mrb uv $product $dver"
      mrb uv $product $dver

      # Update versions in releaseDB/CMakeLists.txt

      for rdb in $MRB_SOURCE/*/releaseDB/CMakeLists.txt
      do
        if [ -f "$rdb" ]; then
          sed "s;\([ 	]*create_product_variables[ 	]*([ 	]*$product[ 	][ 	]*\)[A-Za-z0-9][^ 	]*\([ 	]*)[ 	]*\)$;\1$dver\2;" $rdb > ${rdb}.new
          mv -f ${rdb}.new $rdb
        fi
      done
    fi
  fi
done

rm -f $mfile
