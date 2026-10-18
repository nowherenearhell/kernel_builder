#!/usr/bin/env bash
#
# wrapper providing almost the same amount of verbosity as the main github actions workflow

sln=$(readlink -f "$0")
spath=$(dirname "$sln")
echo $spath

export OLDDIR=$(pwd)
cd $spath

source ./$1priv_env || { echo "$RUN_ID: incorrect envset: nonexistent priv_env, bailing" && exit 127 ; }

RUN_ID=$(shuf -ern4 {0..9} | sha1sum - | head -c 8)
RUN_START=$(date +"%s")

[ -z "$KDIR" ] && { echo "$RUN_ID: incorrect priv_env: KDIR was not set, bailing" && exit 127 ; } || :

if [ ! -d "$KDIR" ]; then
  git clone ${kernel_repo} -b ${kernel_branch} --single-branch "$KDIR" || exit 1
  cd "$KDIR"
  git submodule update --init --recursive
else
  cd "$KDIR" || exit 1
  git reset --hard
  git checkout ${kernel_branch}
  git fetch origin ${kernel_branch}
  git reset --hard origin/${kernel_branch}
  rm -rf KernelSU
  git submodule update --init --recursive
fi

if [[ ! -z "$2" ]]; then rm -rf out ../zipper; fi

source ../$1env || { bash tg_utils.sh msg "$RUN_ID: incorrect envset: nonexistent env, bailing" && exit 127 ; }

case $PATCH_KSU in
  "both" )
    bash ../build.sh "$COMPILERS" $1
    bash ../ksu/applyPatches.sh $1 || exit 1
    bash ../build.sh "$COMPILERS" $1
  ;;
  "sus" )
    bash ../ksu/asus.sh
    bash ../build.sh "$COMPILERS"
  ;;
  "" )
    bash ../build.sh "$COMPILERS" $1
  ;;
  * )
    bash ../ksu/applyPatches.sh $1 || exit 1
    bash ../build.sh "$COMPILERS" $1
  ;;
esac

if [[ $(ls *.log) ]]; then
  for file in *.log ; do
    if [ -e "${file}.info" ]; then
      export RES=0
    fi
  done
fi
if [[ $(ls *.zip) ]]; then
  for file in *.zip ; do
    export RES=1
  done
fi

rm *.zip* *.log
if [[ ! -z "$2" ]]; then
  rm -rf out ../zipper
fi

RUN_END=$(date +"%s")
WDIFF=$((RUN_END - RUN_START))

cd "$OLDDIR"
