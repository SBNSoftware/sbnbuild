#! /bin/bash
#=======================================================================
#
# Name: update_sbncode_version.sh
#
# Purpose: This script updates sbn suite product versions in product_deps
#          files located in $MRB_SOURCE/*/ups/product_deps.  It accepts a
#          new sbncode version as its sole argument.  Then it does the
#          following actions for each checked out sbn suite package, 
#          starting with low level packages, and ending with the top level
#          package sbncode.
#
#          1.  Tests whether a git tag exista that matches the version
#              specified this package's product_deps.  If no git tag exists,
#              don't modify this package.
#
#          2.  If there is a matching git tag, check whether the working
#              version of this package matches the git tag.  If the git
#              tag matches, don't modify this package.
#
#          3.  If there is a matching git tag that doesn't match the working
#              version, update this package's version using "mrb uv."  The
#              user is prompted to enter a new version.
#
#          4.  Updates version, base qualifier, and set qualifier
#              information contained in files
#              $MRB_SOURCE/*/releaseDB/CMakeLists.txt
#
# Usage: update_sbncode_version.sh [-h|--help] <version>
#
# Usage notes:
#
# 1.  This script should normally be invoked to update a release in which
#     all sbn suite packages have been checked out in $MRB_SOURCE.
#
# 2.  Update larsoft-related dependencies (e.g. by invoking 
#     update_larsoft_version.sh) before invoking this script.
#
# Options:
#
# -h|--help - Print help.
#
# Agruments:
#
# <version> - New sbncode version.
#
# Created: 18-Mar-2019  H. Greenlee
#
#=======================================================================
# Help function.

function dohelp {
  echo "Usage: update_sbncode_version.sh [-h|--help] <version>"
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
  echo "No sbncode version specified."
  exit 1
fi

# Loop over sbn suite packages, low level to high level.

for pkg in sbnobj sbnanaobj sbnalg sbncode
do

  # Check whether this package is checked out.
  # If so, cd to this packages source directory.

  echo "Checking $pkg"
  pkgdir=$MRB_SOURCE/$pkg
  if [ -d $pkgdir ]; then
    cd $pkgdir

    # Extract the package version.

    v=''
    if [ -f ups/product_deps ]; then
      dotv=`sed -n '/project.*(.*'"$pkg"'.*VERSION/s/^.*VERSION *\([0-9.]*\).*$/\1/p' CMakeLists.txt`
      if [ x$dotv != x ]; then
        v=v`echo $dotv | tr . _`
      else
        v=`grep 'parent[ ]*'"$pkg" ups/product_deps | awk '{print $3}'`
      fi
    fi

    if [ x$v = x ]; then
      echo "Could not determine $pkg version."
      exit 1
    fi

    # Check whether git knows about this version.

    n=`git tag -l | grep ^$v | wc -l`
    if [ $n -gt 0 ]; then
      echo "Tag $v exists."
      ndiff=`git diff $v | wc -l`
      if [ $ndiff -gt 0 ]; then
        echo "Working version does not match $v"

        # Prompt for new version.

        echo "Enter new version (default $version):"
        read newv rest < /dev/tty
        if [ x$newv = x ]; then
          newv=$version
        fi
        echo "Updating $pkg version to be $newv"
        mrb uv $pkg $newv

        # Update versions in releaseDB/CMakeLists.txt

        #for rdb in $MRB_SOURCE/*/releaseDB/CMakeLists.txt
        #do
        #  sed "s;\([ 	]*create_product_variables[ 	]*([ 	]*$pkg[ 	][ 	]*\)[A-Za-z0-9][^ 	]*\([ 	]*)[ 	]*\)$;\1$newv\2;" $rdb > ${rdb}.new
        #  mv -f ${rdb}.new $rdb
        #done
      else
        echo "Working version matches $v"
      fi
    else

      # There is no corresponding git tag.

      echo "No tag $v"

      # Assume this version is correct, but issue an "mrb uv" command anyway
      # to ensure that all packages are using this version.

      mrb uv $pkg $v

      # Also update versions in releaseDB/CMakeLists.txt

      #for rdb in $MRB_SOURCE/*/releaseDB/CMakeLists.txt
      #do
      #  sed "s;\([ 	]*create_product_variables[ 	]*([ 	]*$pkg[ 	][ 	]*\)[A-Za-z0-9][^ 	]*\([ 	]*)[ 	]*\)$;\1$v\2;" $rdb > ${rdb}.new
      #  mv -f ${rdb}.new $rdb
      #done
    fi

  fi
done
