#!/bin/bash

usage()
{
  cat 1>&2 <<EOF
Usage: $(basename ${0}) [-h]
       $(basename ${0}) <options> <product_topdir> <OS> <prod-spec> [<qual_set> [<build-spec>]]

Options:

  -f    Force pull of tarball if it already exists
  -h    This help.
  -p    Only check for existing products in product_topdir
  -r    Remove tarballs after downloading and unwinding.
  -V    Print version and exit

Arguments:

  product_topdir   Top directory for relocatable-UPS products area.
  
  OS               Supported os distributions: slf5, slf6, slf7, d13, d14, u14, noarch
 
  package-spec      Package name and version, e.g., art-v1_12_04
 
  qual_set         Some possible qualifier sets: 
		   e10
		   e12-p2711

  build-spec       debug or prof.

EOF
}

print_version()
{
  echo
  echo "$(basename ${0}) 1.08.02"
}

function pull_detail() {
  local dist="${1}"
  local tar="${2}"
  local need_pull=1
  if [[ -f "${working_dir}/${tar}" ]]; then
    if (( ${force:-0} )); then
      echo "INFO: Tarball ${working_dir}/${tar} exists and will be pulled again."
    else
      echo "INFO: Tarball ${working_dir}/${tar} exists: use -f to pull again."
      unset need_pull
    fi
  fi
  (( ${need_pull:-0} == 0 )) || \
    curl --fail --silent --location --insecure -O "${dist}" || \
    return 1
  if [ ! -f "${tar}" ]; then
    echo "ERROR: could not find ${working_dir}/${tar}"
    exit 1
  fi
  tar -C "${product_topdir}" -xf "${working_dir}/${tar}" || exit 1
  if [ ${remove_tarballs} = "true" ]; then
    # remove tarball 
    rm -f ${working_dir}/${mytar}
  fi
}

function pull_product()
{
   local myprod=${1}
   local myver=${2}
   local mytar=${3}
   if [ -z ${mytar} ]; then
      echo "tarball unspecified for ${myprod}"
      exit 1
   fi
   local alttar=${mytar/slf7/sl7}
   [[ "${alttar}" = "${mytar}" ]] && alttar=${mytar/sl7/slf7}
   if [[ -f "${working_dir}/${alttar}" ]]; then
     local ttar="${alttar}"
     alttar="${mytar}"
     mytar="${ttar}"
   fi
   # ups special case
   if [[ ${myprod} == ups  ]]; then
     local mflvr=${myflvr/-f /}
     local ttar=`echo ${mytar} | sed -e s%${myarch}-${myplat}%${mflvr}%`
     alttar="${mytar}"
     mytar="${ttar}"
     ##echo "ups tarball is ${mytar}"
   fi
   echo "pull ${mytar}"
   cd ${working_dir}
   pull_detail "http://scisoft.fnal.gov/scisoft/packages/${myprod}/${myver}/${mytar}" "${mytar}" || \
   pull_detail "http://scisoft.fnal.gov/scisoft/packages/${myprod}/${myver}/${alttar}" "${alttar}" || \
    { cat 1>&2 <<EOF
ERROR: pull of ${mytar} failed
EOF
       exit 1
      }
   return 0
}

function setup_ups()
{
   if [[ -n "${SETUP_UPS}" ]]; then
     source ${SETUP_UPS##*-z }/setup
     return $?
   elif [ -e ${product_topdir}/setup ]; then
     source ${product_topdir}/setup
     return $?
   else
     echo "did not find ups in the environment or ${product_topdir}."
   fi
   return 1
}

function check_install()
{
   myprod=${1}
   myver=${2}
   mytar=${3}
   if [ -z ${mytar} ]; then
      echo "tarball unspecified for ${myprod}"
      exit 1
   fi
   # parse the tarball 
   ##shortname=`echo ${mytar} | sed -e 's%ups-upd%ups%' | sed -e 's%.tar.bz2%%'`
   tar1=`echo ${mytar} | sed -e 's%ups-upd%ups%'`
   shortname=`echo ${tar1%%.tar*}`
   tarparts=($(echo $shortname | tr "-" "\n"))
   ##echo "${mytar} has ${#tarparts[@]} parts"
   myarch=$(echo ${tarparts[2]} | tr "\"" " ")
   if [ "${myarch}" = "sl7" ]; then myarch=slf7; fi
   ##echo ${myarch}
   if [ "${myarch}" = "noarch" ]
   then
     myqual1=""
     for (( i=3; i<${#tarparts[@]}; i++ ));
     do
       myqual1=+$(echo ${tarparts[$i]} | tr "\"" " "):${myqual1}
     done
     myqual=`echo ${myqual1} | sed -e s'/:$//'`
     qualdir=`echo ${myqual} | sed -e s'/:/_/g' | sed -e s'/+//g'`
     #echo "${myprod} ${myver} noarch qualifier ${myqual} ${qualdir}"
     if [ -z ${myqual} ]
     then
      if ups exist ${myprod} ${myver} >/dev/null 2>&1; then
         echo "INFO: ups product ${myprod} ${myver} already exists"
         return 0
      elif [ -e ${product_topdir}/${myprod}/${myver}.version/NULL_ ]; then
         # if we are installing source, ups is not availble
         echo "INFO: ups product ${myprod} ${myver} already exists"
         return 0
      else
         #echo "did not find ${myprod} ${myver}"
         return 1
      fi
     else
      if ups exist ${myprod} ${myver}  -q ${myqual} >/dev/null 2>&1; then
         echo "INFO: ups product ${myprod} ${myver} -q ${myqual} already exists"
         return 0
      elif [ -e ${product_topdir}/${myprod}/${myver}.version/NULL_${qualdir} ]; then
         # if we are installing source, ups is not availble
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
   myplat=$(echo ${tarparts[3]} | tr "\"" " ")
   if [ "${myarch}" = "slf5" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Linux64bit+2.6-2.5"
   elif [ "${myarch}" = "slf6" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Linux64bit+2.6-2.12"
   elif [ "${myarch}" = "slf7" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Linux64bit+3.10-2.17"
   elif  [ "${myarch}" = "u14" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Linux64bit+3.19-2.19"
   elif  [ "${myarch}" = "u16" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Linux64bit+4.4-2.23"
   elif  [ "${myarch}" = "u18" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Linux64bit+4.15-2.27"
   elif  [ "${myarch}" = "d12" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Darwin+12"
   elif  [ "${myarch}" = "d13" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Darwin64bit+13"
   elif  [ "${myarch}" = "d14" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Darwin64bit+14"
   elif  [ "${myarch}" = "d15" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Darwin64bit+15"
   elif  [ "${myarch}" = "d16" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Darwin64bit+16"
   elif  [ "${myarch}" = "d17" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Darwin64bit+17"
   elif  [ "${myarch}" = "d18" ] && [ "${myplat}" = "x86_64" ]
   then
     myflvr="-f Darwin64bit+18"
   fi
   if [ ${#tarparts[@]} -lt 5 ]
   then
      if ups exist ${ups_db_opts} ${myprod} ${myver} ${myflvr} >/dev/null 2>&1; then
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
   if ups exist ${ups_db_opts} ${myprod} ${myver} -q ${myqual} ${myflvr} >/dev/null 2>&1; then
      echo "INFO: ups product ${myprod} ${myver} -q ${myqual} ${myflvr} already exists"
      return 0
   else
      #echo "did not find ${myprod} ${myver} -q ${myqual} ${myflvr}"
      return 1
   fi
   # if you get here, something is wrong
   return 1
}

########################################################################
# Main body.

# Global variables.
current_os=$(uname)
[[ "${current_os}" == Darwin ]] && (( darwin = 1 ))


logdir=$(/bin/pwd)
local_manifest=false
remove_tarballs=false

print_version

while getopts :fhlMprV OPT; do
  case ${OPT} in
    f)
      (( force = 1 ))
      ;;
    h)
      usage
      exit 1
      ;;
    p)
      (( private_product_check = 1 ))
      ;;
    r)
      remove_tarballs=true
      echo "INFO: product tarballs will be deleted after being successfully unwound"
      ;;
    V)
      print_version
      exit 1
      ;;
    *)
      echo "ERROR: unrecognized option -${OPT}"
      usage
      exit 1
  esac
done
shift `expr $OPTIND - 1`
OPTIND=1

if (( $# < 3 )); then
  echo "ERROR: Expected at least 3 non-option arguments; received $#." 1>&2
  usage
  exit 1
fi

product_topdir="${1}"

[[ -n "$product_topdir" ]] && \
  [[ -d "${product_topdir}" ]] && \
  [[ -w "${product_topdir}" ]] || \
  { echo "ERROR: Could not write to specified product directory \"${product_topdir}\"." 1>&2; exit 1; }

install_os="${2}"
product_spec="${3}"
qual_set="${4}"
build_type="${5}"

working_dir=$(/bin/pwd)

if (( $(echo ${product_spec} | grep '\-' | wc -l) > 0 )); then
  product=`echo ${product_spec} | cut -f1 -d"-"`
  product_ver=`echo ${product_spec} | cut -f2 -d"-"`
else
  echo "ERROR: product spec ${product_spec} is not fully specified"
  usage
  exit 1
fi

if (( $(echo ${product_ver} | grep _ | wc -l) > 0 )); then
  product_version=${product_ver}
  product_dot_version=`echo ${product_ver} | sed -e 's/_/./g' | sed -e 's/^v//'`
else
  product_version=v`echo ${product_ver} | sed -e 's/\./_/g'`
  product_dot_version=${product_ver}
fi

echo "looking for ${product} ${product_version} ${install_os} ${qual_set} ${build_type}"

# reset $PRODUCTS if desired
if (( ${private_product_check:-0} )); then
  export PRODUCTS=${product_topdir}
  ups_db_opts="-z ${product_topdir}"
fi
echo
echo "INFO: ups will check these product directories:"
echo "     ${product_topdir}"
echo "     ${PRODUCTS}"

case ${build_type} in
  debug) ;;
  opt) ;;    
  prof) ;;
  "") ;;
  *)
    echo "ERROR: unrecognized build type ${build_type}"
    usage
    exit 1
esac

# next download the manifest

# Attempt to find UPS.
setup_ups 

echo "INFO: ${product} will be installed in ${product_topdir}"
echo

# Construct the tar file.
pkgtar="${product}-${product_dot_version}-${install_os}"
[[ "${install_os}" =~ (noarch|source)$ ]] || pkgtar="${pkgtar}-x86_64"
pkgtar="${pkgtar}${qual_set:+-${qual_set}}${build_type:+-${build_type}}.tar.bz2"

if check_install ${product} ${product_version} ${pkgtar}; then
  if (( ${force:-0} )); then
	  echo "INFO: found ${product} ${product_version} but will pull again"
    (( pull = 1 ))
  fi
else
  (( pull = 1 ))
fi

(( ${pull:-0} )) && \
  pull_product ${product} ${product_version} ${pkgtar}

exit $?
