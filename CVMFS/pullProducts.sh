#!/bin/bash

usage()
{
  cat 1>&2 <<EOF
Usage: $(basename ${0}) [-h]
       $(basename ${0}) <options> <product_topdir> <OS> <bundle-spec> <qual_set> <build-spec>

Options:

  -d    Debug network operations for tarball downloads.
  -f    Force pull of tarball if it already exists.
  -h    This help.
  -l    Use a local manifest.  This is for development, not for production.
  -M    Download manifest only.
  -p    Only check for existing products in product_topdir.
  -r    Remove tarballs after downloading and unwinding.
  -s    Stream tarballs instead of downloading (mutually incompatible with -r).
  -V    Print version and exit.

  -S <spack_topdir>  Top directory for spack buildcache installation
                     Must NOT be the same as product_topdir.

Arguments:

  product_topdir   Top directory for relocatable-UPS products area.
  
  OS               Supported os distributions: 
                   slf5, slf6, slf7, d14, d15, d16, d17, d18, u14, u16, u18, u20
 
  bundle-spec      Bundle name and version, e.g., art-v1_12_04
 
  qual_set         Some possible qualifier sets: 
		   e10
		   s17-e9

  build-spec       debug or prof.

EOF
}

print_version()
{
  echo
  echo "$(basename ${0}) 2.04.00"
}

calc_compression_opt()
{
  local mytar=${1}
  local result
  local ext=${mytar##*.}
  case ${ext} in
    gz|tgz)
      result=-z
      ;;
    bz2)
      result=-j
      ;;
    xz)
      result=-J
      ;;
    lzma)
      result=--lzma
      ;;
    *)
      echo "WARNING: could not deduce compression from extension ${ext}" 1>&2
  esac
  echo $result
}

function pull_product()
{
  local myprod=${1}
  local myver=${2}
  local mytar=${3}
  local status
  if [ -z ${mytar} ]; then
    echo "ERROR tarball unspecified for ${myprod}" 1>&2
    exit 1
  fi
  if [ -e ${working_dir}/${mytar} ]; then
    if (( ${force:-0} )); then
      echo "INFO: Tarball ${working_dir}/${mytar} exists and will be pulled again."
    else
      echo "INFO: Tarball ${working_dir}/${mytar} exists: use -f to pull again."
      return 0
    fi
  fi
  local mydist=https://scisoft.fnal.gov/scisoft/packages/${myprod}/${myver}/${mytar}
  echo "INFO: pull / untar ${mytar}"
  cd ${working_dir}
  if (( ${stream_tarballs:-0} )); then # Streaming direct to tar.
    local compopt=$(calc_compression_opt "${mytar}")
    curl ${curl_silent:+--silent} ${curl_verbose:+--verbose} \
      --fail --location --insecure ${mydist} | \
      tar -C "${product_topdir}" "${compopt}" -x || \
      { status=$?
      cat 1>&2 <<EOF
ERROR: stream untar of ${mydist} failed
EOF
      exit $status
    }
  else # Normal operation
    curl --fail ${curl_silent:+--silent} ${curl_verbose:+--verbose} \
      --location --insecure --retry 3 --retry-max-time 600 -O ${mydist}  || \
      { status=$?
      cat 1>&2 <<EOF
ERROR: pull of ${mydist} failed
EOF
      exit $status
    }
    if [ ! -e ${working_dir}/${mytar} ]; then
      echo "ERROR: could not find ${working_dir}/${mytar}" 1>&2
      exit 1
    fi
    tar -C "${product_topdir}" -x -f "${mytar}" || \
      { status=$?
      cat 1>&2 <<EOF
ERROR: untar of ${working_dir/${mytar} failed
EOF
      exit $status
    }
    if (( ${remove_tarballs:-0} )); then
      # remove tarball
      rm -f "${mytar}"
    fi
  fi
  return $status
}

########################################################################
# version_greater
#
# Compare two UPS version strings and return success if the first is
# greater.
function version_greater()
{
  perl -e 'use strict;
$ARGV[0] =~ s&^\s*"([^"]+)"\s*$&${1}&;
$ARGV[1] =~ s&^\s*"([^"]+)"\s*$&${1}&;
my @v1 = ( $ARGV[0] =~ m&^v(\d+)(?:_(\d+)(?:_(\d+))?)?(.*)& );
my @v2 = ( $ARGV[1] =~ m&^v(\d+)(?:_(\d+)(?:_(\d+))?)?(.*)& );
my $result;
if (defined $v1[0] and defined $v2[0] and $v1[0] == $v2[0]) {
  if (defined $v1[1] and defined $v2[1] and $v1[1] == $v2[1]) {
    if (defined $v1[2] and defined $v2[2] and $v1[2] == $v2[2]) {
      $result = ($v1[3] and (!$v2[3] or $v1[3] gt $v2[3]))?1:0;
    } else {
      $result = (defined $v1[2] and (!defined $v2[2] or $v1[2] > $v2[2]))?1:0;
    }
  } else {
    $result = (defined $v1[1] and (!defined $v2[1] or $v1[1] > $v2[1]))?1:0;
  }
} else {
  $result = (defined $v1[0] and (!defined $v2[0] or $v1[0] > $v2[0]))?1:0
}
exit(($result == 1)? 0 : 1);
' "$@"
}

## handle ups 
function install_ups()
{
  local line=`grep ups ${manifest}`
  if [ ! "${line}" ]; then
    echo "INFO: failed to find ups in manifest"
    return 0
  fi
  local words=($(echo $line | tr " " "\n"))
  local product=$(echo ${words[0]} | tr "\"" " ")
  if [ ${product} != "ups" ]; then
    echo "INFO: ups misidentified as ${product} in manifest"
    return 0
  fi
  local ups_version=$(echo ${words[1]} | tr "\"" " ")
  local tarball=$(echo ${words[2]} | tr "\"" " ")
  local mydist=https://scisoft.fnal.gov/scisoft/packages/${product}/${ups_version}/${tarball}
  local want_ups_install=0
  if [ -d ${product_topdir}/ups ]; then
    local current_ups=`ls ${product_topdir}/ups | grep -v version | grep -v current | sort -r | head -n 1`
    if version_greater ${ups_version} ${current_ups}; then
      want_ups_install=1
	  fi
  else
    want_ups_install=1
  fi
  if (( ${want_ups_install:-0} )); then
    echo "INFO: pull ups ${tarball}"
    cd ${working_dir}
    curl ${curl_silent:+--silent} ${curl_verbose:+--verbose} \
      --fail --location --insecure -O ${mydist}  || \
	    { cat 1>&2 <<EOF
ERROR: pull of ${mydist} failed
EOF
      exit 1
    }
    if [ ! -e ${working_dir}/${tarball} ]; then
	    echo "ERROR: could not find ${working_dir}/${tarball}" 1>&2
	    exit 1
    fi
    cd ${product_topdir}
    tar xf ${working_dir}/${tarball} || exit 1
    cd ${working_dir}
  fi
  return 0
}

function setup_ups()
{
  if [ -e ${product_topdir}/setup ]
  then
    source ${product_topdir}/setup
    return 0
  else
    echo "INFO: did not find ups in ${product_topdir}"
  fi
  return 1
}

function check_install()
{
  local myprod=${1}
  local myver=${2}
  local mytar=${3}
  if [ -z ${mytar} ]; then
    echo "ERROR: tarball unspecified for ${myprod}" 1>&2
    exit 1
  fi
  # parse the tarball 
  ##shortname=`echo ${mytar} | sed -e 's%ups-upd%ups%' | sed -e 's%.tar.bz2%%'`
  local tar1=`echo ${mytar} | sed -e 's%ups-upd%ups%'`
  local shortname=`echo ${tar1%%.tar*}`
  local tarparts=($(echo $shortname | tr "-" "\n"))
  ##echo "${mytar} has ${#tarparts[@]} parts"
  local myarch=$(echo ${tarparts[2]} | tr "\"" " ")
  if [ "${myarch}" = "sl7" ]; then myarch=slf7; fi
  ##echo ${myarch}
  local myqual
  if [ "${myarch}" = "noarch" ]
  then
    local myqual1=""
    for (( i=3; i<${#tarparts[@]}; i++ ));
    do
      myqual1=+$(echo ${tarparts[$i]} | tr "\"" " "):${myqual1}
    done
    myqual=`echo ${myqual1} | sed -e s'/:$//'`
    local qualdir=`echo ${myqual} | sed -e s'/:/_/g' | sed -e s'/+//g'`
    #echo "${myprod} ${myver} noarch qualifier ${myqual} ${qualdir}"
    if [ -z ${myqual} ]
    then
      if ups exist ${myprod} ${myver} >/dev/null 2>&1; then
        echo "INFO: ups product ${myprod} ${myver} already exists"
        return 0
      elif [ -e ${product_topdir}/${myprod}/${myver}.version/NULL_ ]; then
        # if we are installing source, ups is not available
        echo "INFO: ups product ${myprod} ${myver} already exists"
        return 0
      else
        #echo "did not find ${myprod} ${myver}"
        return 1
      fi
    else
      if ups exist ${myprod} ${myver} -q ${myqual} >/dev/null 2>&1; then
        echo "INFO: ups product ${myprod} ${myver} -q ${myqual} already exists"
        return 0
      elif [ -e ${product_topdir}/${myprod}/${myver}.version/NULL_${qualdir} ]; then
        # if we are installing source, ups is not available
        echo "INFO: ups product ${myprod} ${myver} -q ${myqual} already exists"
        return 0
      else
        #echo "did not find ${myprod} ${myver} -q ${myqual}"
        return 1
      fi
    fi
  fi
  if [ "${myarch}" = "source" ]
  then
    if [ "${myprod}" = "ups" ] && [ -e ${product_topdir}/${myprod}/${myver}/build_ups.sh ]; then
      echo "INFO: ${myprod} ${myver} source already exists"
      return 0
    elif [ -e ${product_topdir}/${myprod}/${myver}/autobuild.sh ]; then
      echo "INFO: ${myprod} ${myver} source already exists"
      return 0
    else
      #echo "did not find ${myprod} ${myver} source"
      return 1
    fi
  fi
  local myplat=$(echo ${tarparts[3]} | tr "\"" " ")
  local myflvr
  if [ "${myarch}" = "slf5" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Linux64bit+2.6-2.5"
  elif [ "${myarch}" = "slf6" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Linux64bit+2.6-2.12"
  elif [ "${myarch}" = "slf7" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Linux64bit+3.10-2.17"
  elif [ "${myarch}" = "u18" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Linux64bit+4.15-2.27"
  elif [ "${myarch}" = "u20" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Linux64bit+5.4-2.31"
  elif  [ "${myarch}" = "d12" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Darwin+12"
  elif  [ "${myarch}" = "d13" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Darwin64bit+13"
  elif  [ "${myarch}" = "d14" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Darwin64bit+14"
  elif  [ "${myarch}" = "d15" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Darwin64bit+15"
  elif  [ "${myarch}" = "d16" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Darwin64bit+16"
  elif  [ "${myarch}" = "d17" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Darwin64bit+17"
  elif  [ "${myarch}" = "d18" ] && [ "${myplat}" = "x86_64" ]
  then
    myflvr="-H Darwin64bit+18"
  fi
  # deal with UPS_OVERRIDE
  if [ -z "${UPS_OVERRIDE}" ]; then
    new_override="-B"
  else 
    tempover=`echo ${UPS_OVERRIDE} | sed -e 's/\-B//'`
    new_override="-B ${tempover}"
  fi
  export UPS_OVERRIDE="${new_override}"
  if [ ${#tarparts[@]} -lt 5 ]
  then
    if ups exist ${myprod} ${myver} ${myflvr} >/dev/null 2>&1; then
      echo "INFO: ups product ${myprod} ${myver} ${myflvr} already exists"
      return 0
    else
      #echo "did not find ${myprod} ${myver} ${myflvr}"
      return 1
    fi
  fi
  myqual=""
  for (( i=4; i<${#tarparts[@]}; i++ ));
  do
    myqual=+$(echo ${tarparts[$i]} | tr "\"" " "):${myqual}
  done
  ##echo ${myqual}
  if ups exist ${myprod} ${myver} -q ${myqual} ${myflvr} >/dev/null 2>&1; then
    echo "INFO: ups product ${myprod} ${myver} -q ${myqual} ${myflvr} already exists"
    return 0
  else
    #echo "did not find ${myprod} ${myver} -q ${myqual} ${myflvr}"
    return 1
  fi
  # if you get here, something is wrong
  return 1
}

get_manifest()
{
  local mname=${1}
  if (( ${local_manifest:-0} )); then
    if [ ! -e ${mname} ]; then
      echo "ERROR: local manifest requested, but could not find ${mname}"
      exit 1
    fi
  else
    local newlocation=https://scisoft.fnal.gov/scisoft/bundles/${bundle}/${bundle_version}/manifest
    local oldlocation=https://scisoft.fnal.gov/scisoft/manifest/${bundle}/${bundle_version}
    local alternate_manifest=${oldlocation}/${mname}
    if [ "${install_os}" = "u14" ]
    then
      alternate_manifest=${newlocation}/${alternate_manifest_name}
      echo "INFO: Ubuntu alternate: ${alternate_manifest}"
    fi
    curl --fail --silent --location --insecure -O ${newlocation}/${mname} || \
      curl --fail --silent --location --insecure -O ${alternate_manifest} || \
      { cat 1>&2 <<EOF
ERROR: pull of ${mname} failed
       Please check the spelling and try again
EOF
      list_available_manifests
      exit 1
    }
  fi
}

parse_manifest()
{
  cat ${working_dir}/${manifest} | while read line
  do
    ##echo "parsing $line"
    local words=($(echo $line | tr " " "\n"))
    local product=$(echo ${words[0]} | tr "\"" " ")
    local version=$(echo ${words[1]} | tr "\"" " ")
    local tarball=$(echo ${words[2]} | tr "\"" " ")
    #echo "found: ${product} ${version} ${tarball}"
    if [ "${product}" = "spack_command" ]; then
      run_spack_command $line
    else
    local product_is_installed="true"
    check_install ${product} ${version} ${tarball} || { product_is_installed="false"; }
    if [ "${product_is_installed}" = "true" ]; then
      if (( ${force:-0} )); then
	      echo "INFO: found ${product} ${version} but will pull again"
        pull_product ${product} ${version} ${tarball} || exit $?
      fi
    else
      pull_product ${product} ${version} ${tarball} || exit $?
    fi
    fi
  done || exit $?
}

pull_buildcfg()
{
  cd ${working_dir}
  local newbldlocation=https://scisoft.fnal.gov/scisoft/bundles/${bundle}/${bundle_version}/buildcfg
  local oldbldlocation=https://scisoft.fnal.gov/scisoft/projects/${bundle}/${bundle_version}
  local mybuildcfg=${bundle}-buildcfg-${bundle_dot_version}
  local mycfg=${bundle}-cfg-${bundle_dot_version}
  local mybuildscript=""
  case ${bundle} in
    "art" ) mybuildscript=buildFW-${bundle_version} ;;
    "larsoft" ) mybuildscript=buildLAr-${bundle_version} ;;
    *) mybuildscript=buildFW-${bundle_version}
  esac
  if (( ${local_manifest:-0} )) && [ -e ${mycfg} ]
  then
    echo "INFO: found local buildcfg script ${mycfg}"
  else
    curl --fail --silent --location --insecure -O ${newbldlocation}/${mycfg}  || \
      curl --fail --silent --location --insecure -O ${newbldlocation}/${mybuildcfg}  || \
      curl --fail --silent --location --insecure -O ${oldbldlocation}/${mybuildscript}  || \
      { cat 1>&2 <<EOF
ERROR: pull of ${mycfg}, ${mybuildcfg}, or ${mybuildscript} failed
EOF
      exit 1
    }
  fi
  if [ -e ${mycfg} ]; then chmod +x ${mycfg}; fi
  if [ -e ${mybuildcfg} ]; then chmod +x ${mybuildcfg}; fi
  if [ -e ${mybuildscript} ]; then chmod +x ${mybuildscript}; fi
}

install_source()
{
  cd ${working_dir}
  pull_buildcfg
  manifest=${bundle}-${bundle_dot_version}-source_MANIFEST.txt  
  get_manifest ${manifest}
  if [ ! -e ${working_dir}/${manifest} ]; then
    echo "ERROR: could not find ${working_dir}/${manifest}" 1>&2
    exit 1
  fi
  parse_manifest
  cd ${working_dir}
  curl --fail --silent --location --insecure \
    -O https://scisoft.fnal.gov/scisoft/bundles/tools/buildFW  || \
    { cat 1>&2 <<EOF
ERROR: pull of buildFW failed
EOF
    exit 1
  }
  chmod +x buildFW
}

function list_available_releases()
{
  local url="https://scisoft.fnal.gov/scisoft/bundles/${bundle}/"
  local release_list=(`curl --silent -F "web=/dev/null;type=text/html" ${url} \
          | grep bundles \
          | grep id \
          | grep -v hidden \
          | cut -f3 -d" " \
          | sed -e 's/id="//' \
          | sed -e 's/">//' \
          `)
  if [[ ${#release_list[@]} == 0 ]]; then
    echo 
    echo "cannot find bundle ${bundle}"
  else
    echo
    echo "Available releases"
    for (( k=0; k<${#release_list[@]}; k++ ));
    do
      echo " ${bundle} ${release_list[$k]}"
    done
  fi
}

function list_available_manifests()
{
  local url="https://scisoft.fnal.gov/scisoft/bundles/${bundle}/${bundle_version}/manifest/"
  local manifest_list=(`curl --silent -F "web=/dev/null;type=text/html" ${url} \
          | grep MANIFEST \
          | cut -f4 -d" " \
          | sed -e 's/<\/a>//' \
          `)
  if [[ ${#manifest_list[@]} == 0 ]]; then
    list_available_releases
  else
    echo
    echo "Available manifests"
    for (( k=0; k<${#manifest_list[@]}; k++ ));
    do
      local short_name=`echo ${manifest_list[$k]} | sed -e 's/_MANIFEST.txt//' \
                     | sed "s/${bundle}-${bundle_dot_version}-//" \
                     | sed -e 's/Darwin64bit+12/d12/' \
                     | sed -e 's/Darwin64bit+13/d13/' \
                     | sed -e 's/Darwin64bit+14/d14/' \
                     | sed -e 's/Darwin64bit+15/d15/' \
                     | sed -e 's/Darwin64bit+16/d16/' \
                     | sed -e 's/Darwin64bit+17/d17/' \
                     | sed -e 's/Darwin64bit+18/d18/' \
                     | sed -e 's/Linux64bit+2\.6-2\.5/slf5/' \
                     | sed -e 's/Linux64bit+2\.6-2\.12/slf6/' \
                     | sed -e 's/Linux64bit+3\.10-2\.17/slf7/' \
		                 | sed -e 's/Linux64bit+3\.13-2\.19/u14/' \
		                 | sed -e 's/Linux64bit+3\.16-2\.19/u14/' \
		                 | sed -e 's/Linux64bit+3\.19-2\.19/u14/' \
		                 | sed -e 's/Linux64bit+4\.4-2\.23/u16/' \
                     | sed -e 's/Linux64bit+4\.15-2\.27/u18/' \
                     | sed -e 's/Linux64bit+5\.4-2\.31/u20/'`
      local platform=`echo ${short_name} | cut -f1 -d "-"`
      local quals=`echo ${short_name} | sed -e s"/${platform}-//" \
                        	| sed -e 's/source//' \
                        	| sed -e 's/-debug/ debug/' | sed -e 's/-prof/ prof/' | sed -e 's/-opt/ opt/'`
      echo "${platform} ${bundle}-${bundle_version} ${quals}"
    done
  fi
}

# initialize spack package directory
init_package_dir() {
  if [ -e ${spack_topdir}/setup-env.sh ]; then
    echo "INFO: spack is already initialized"
    return
  fi
  # Set up spack configured to install into a ups like directory structure
  cd ${spack_topdir}
  git clone https://github.com/marcmengel/spack-infrastructure ${spack_topdir}/spack-infrastructure
  cd "${spack_topdir}"/spack-infrastructure
  git checkout v2_17_01
  cd ${spack_topdir}
  export PATH=$PATH:${spack_topdir}/spack-infrastructure/bin
  make_spack --minimal -u ${spack_topdir}
  cp -p ${spack_topdir}/patchelf/*/*/bin/patchelf ${spack_topdir}/spack-infrastructure/bin/
  # use system zlib
  source ${spack_topdir}/setup-env.sh
echo
type patchelf
echo
  echo "packages:" >> ${spack_topdir}/spack/current/NULL/etc/spack/packages.yaml
  echo "  zlib:" >> ${spack_topdir}/spack/current/NULL/etc/spack/packages.yaml
  echo "    externals: [{spec: zlib@1.2.7, prefix: /usr}]"  >> ${spack_topdir}/spack/current/NULL/etc/spack/packages.yaml
  # return to working directory
  cd ${working_dir}
}

run_spack_command() {
if [ -z "$spack_topdir" ]; then
  echo "INFO:  spack_command will be ignored since a spack packages directory has not been specified."
  echo "INFO: If you are making a local install, please use -S to specify the spack package directory."
else
  [[ -n "$spack_topdir" ]] && \
    [[ -d "${spack_topdir}" ]] && \
    [[ -w "${spack_topdir}" ]] || \
    { echo "ERROR: Could not write to specified spack package directory ${spack_topdir}." 1>&2; exit 1; }
  if [ ! -e ${spack_topdir}/setup-env.sh ]; then
    init_package_dir
  fi
  #cd ${spack_topdir}
  source ${spack_topdir}/setup-env.sh
  local myline=${@}
  local mycmd=`echo ${myline} | sed -e 's/spack_command //'`
  echo "INFO: running spack command: $mycmd"
  ${mycmd}
fi
}

########################################################################
# Main body.

# Global variables.
current_os=$(uname)
[[ "${current_os}" == Darwin ]] && (( darwin = 1 ))
(( curl_silent = 1 ))
curl_verbose=""

logdir=$(/bin/pwd)

print_version

# use to get the full path
( cd / ; /bin/pwd -P ) >/dev/null 2>&1
if (( $? == 0 )); then
  pwd_P_arg="-P"
fi

while getopts :S:dfhlMprsV OPT; do
  case ${OPT} in
    d)
      curl_silent=""
      (( curl_verbose = 1 ))
      ;;
    f)
      (( force = 1 ))
      ;;
    h)
      usage
      exit 1
      ;;
    l)
      (( local_manifest = 1 ))
      ;;
    M)
      (( manifest_only = 1 ))
      ;;
    p)
      (( private_product_check = 1 ))
      ;;
    r)
      (( remove_tarballs = 1 ))
      ;;
    s)
      (( stream_tarballs = 1 ))
      ;;
    S)
      #spack_topdir=$OPTARG
      spack_topdir=`cd ${OPTARG} && /bin/pwd ${pwd_P_arg}`
      ;;
    V)
      print_version
      exit 1
      ;;
    *)
      echo "ERROR: unrecognized option -${OPT}" 1>&2
      usage
      exit 1
  esac
done
shift `expr $OPTIND - 1`
##shift $(( OPTIND - 1 ))
##OPTIND=1

if (( $# != 5 )) && (( $# != 3 )); then
  echo "ERROR: Expected 3 or 5 non-option arguments; received $#." 1>&2
  usage
  exit 1
fi

if (( ${remove_tarballs:-0} )) && (( ${stream_tarballs:-0} )); then
  echo "ERROR: -r and -s options are mutually incompatible." 1>&2
  exit 1
elif (( ${remove_tarballs:-0} )); then
  echo "INFO: product tarballs will be deleted after being successfully unwound"
elif (( ${stream_tarballs:-0} )); then
  echo "INFO: product tarballs will be streamed directly to tar"
fi

#product_topdir="${1}"
product_topdir=`cd ${1} && /bin/pwd ${pwd_P_arg}`

[[ -n "$product_topdir" ]] && \
  [[ -d "${product_topdir}" ]] && \
  [[ -w "${product_topdir}" ]] || \
  { echo "ERROR: Could not write to specified product directory \"${product_topdir}\"." 1>&2; exit 1; }

echo "ups: $product_topdir"
echo "spack: $spack_topdir"

if [ -z "$spack_topdir" ]; then
  echo "INFO: ups products will be installed in $product_topdir"
else
  if [[ "$spack_topdir" == "$product_topdir" ]]; then
    echo "ERROR: spack_topdir cannot be the same as product_topdir"
    exit 1
  fi
  [[ -n "$spack_topdir" ]] && \
    [[ -d "${spack_topdir}" ]] && \
    [[ -w "${spack_topdir}" ]] || \
    { echo "ERROR: Could not write to specified spack package directory ${spack_topdir}." 1>&2; exit 1; }
  echo "INFO: ups products will be installed in $product_topdir"
  echo "INFO: spack packages will be installed in $spack_topdir"
fi

install_os="${2}"
bundle_spec="${3}"
qual_set="${4}"
build_type="${5}"

working_dir=$(/bin/pwd)

if (( $(echo ${bundle_spec} | grep '\-' | wc -l) > 0 )); then
  bundle=`echo ${bundle_spec} | cut -f1 -d"-"`
  bundle_ver=`echo ${bundle_spec} | cut -f2 -d"-"`
else
  echo "ERROR: bundle spec ${bundle_spec} is not fully specified" 1>&2
  usage
  exit 1
fi

if [[ "${bundle_ver}" =~ ^v[0-9]+_? ]]; then
  # Normal version.
  bundle_version=${bundle_ver}
  bundle_dot_version=`echo ${bundle_ver} | sed -e 's/_/./g' | sed -e 's/^v//'`
elif [[ "${bundle_ver}" =~ ^[0-9]+(\.[0-9]+)? ]]; then
  # Basic dotted version.
  bundle_version=v`echo ${bundle_ver} | sed -e 's/\./_/g'`
  bundle_dot_version=${bundle_ver}
elif [[ "${bundle_ver}" =~ ^v([^AaEeIiOoUu]|[A-Za-z0-9_]+$) ]]; then
  # v<text-version> (e.g. vdevelop or vart_v2_develop)
  bundle_version=${bundle_ver}
  bundle_dot_version=`echo ${bundle_ver} | sed -e 's/_/./g' | sed -e 's/^v//'`
elif [[ "${bundle_ver}" =~ ^[A-Za-z][A-Za-z0-9.]+$ ]]; then
  # <dot-text-version> (e.g. art.v2.develop)
  bundle_version=v${bundle_ver//./_}
  bundle_dot_version=${bundle_ver}
else # Assume freeform (e.g. develop, very_new, etc.).
  bundle_version=v${bundle_ver}
  bundle_dot_version=${bundle_ver//_/.}
fi

echo "INFO: looking for ${bundle} ${bundle_dot_version} (${bundle_version}) ${install_os} ${qual_set} ${build_type}"

# reset $PRODUCTS if desired
if (( ${private_product_check:-0})); then
  export PRODUCTS=${product_topdir}
fi
echo
echo "INFO: ups will check these product directories:"
echo "     ${product_topdir}"
echo "     ${PRODUCTS}"

case ${install_os} in
  slf5) manifest_os="Linux64bit+2.6-2.5" ;;
  slf6) manifest_os="Linux64bit+2.6-2.12" ;;    
  slf7) manifest_os="Linux64bit+3.10-2.17" ;;    
  d12)  manifest_os="Darwin64bit+12";;
  d13)  manifest_os="Darwin64bit+13";;    
  d14)  manifest_os="Darwin64bit+14";;    
  d15)  manifest_os="Darwin64bit+15";;    
  d16)  manifest_os="Darwin64bit+16";;    
  d17)  manifest_os="Darwin64bit+17";;    
  d18)  manifest_os="Darwin64bit+18";;    
  u14)  manifest_os="Linux64bit+3.13-2.19";;    
  u16)  manifest_os="Linux64bit+4.4-2.23";;
  u18)  manifest_os="Linux64bit+4.15-2.27";;
  u20)  manifest_os="Linux64bit+5.4-2.31";;
  source)
     manifest_os=${install_os}
     install_source
     exit 0 
  ;;
  *)
    echo "ERROR: unrecognized OS ${install_os}" 1>&2
    usage
    exit 1
esac

case ${build_type} in
  debug) ;;
  opt) ;;    
  prof) ;;
  *)
    echo "ERROR: unrecognized build type ${build_type}" 1>&2
    usage
    exit 1
esac

# next download the manifest

manifest=${bundle}-${bundle_dot_version}-${manifest_os}-${qual_set}-${build_type}_MANIFEST.txt  
if [ "${install_os}" = "u14" ]
then
   alternate_manifest_name=${bundle}-${bundle_dot_version}-Linux64bit+3.19-2.19-${qual_set}-${build_type}_MANIFEST.txt  
fi
get_manifest ${manifest}

if (( ${manifest_only:-0} )); then
  echo "INFO: Manifest at ${manifest}"
  exit 0
fi

if [ ! -e ${working_dir}/${manifest} ]; then
  if [ -e ${working_dir}/${alternate_manifest_name} ]; then
    manifest=${alternate_manifest_name}
  else
    echo "ERROR: could not find ${working_dir}/${manifest}" 1>&2
    exit 1
  fi
fi

# Even if ups is installed elsewhere, we want to install it in this product directory
install_ups
# want to use ups exist at this point
setup_ups 

echo "INFO: products will be installed in ${product_topdir}"
echo

# now process the manifest
parse_manifest


exit $?
