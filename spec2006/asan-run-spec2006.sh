#!/bin/bash
# 
# All-in-one SPEC2006 handling script for ASAN.
#

if [ -t 1 ]
then
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BOLD="\033[1m"
    OFF="\033[0m"
else
    RED=
    GREEN=
    YELLOW=
    BOLD=
    OFF=
fi

SPEC2006_PATH=$PWD/cpu2006

if ! grep abm /proc/cpuinfo >/dev/null
then
    if [ "$1" != "--legacy" ]
    then
        echo -e "${RED}ERROR${OFF}: EffectiveSan requires a (virtual) CPU" \
            "with LZCNT support!"
        echo
        echo -e "${YELLOW}NOTE${OFF}:"
        echo "    This error can be disabled by using the \"--legacy\"" \
            "option."
        echo "    However, running in legacy mode may cause some SPEC " \
            "benchmarks to crash"
        echo "    or otherwise mis-behave, so is not officially supported."
        exit 1
    fi
fi
if ! grep sse4_2 /proc/cpuinfo >/dev/null
then
    echo -e "${RED}ERROR${OFF}: EffectiveSan requires a (virtual) CPU" \
        "with SSE4.2 support!"
    exit 1
fi

if [ ! -d "$SPEC2006_PATH" ]
then
    echo -e "${YELLOW}warning${OFF}: SPEC2006 installation is missing!"
    MOUNT_POINT=$PWD/mnt
    mkdir -p "$MOUNT_POINT"
    SPEC2006_ISO=$PWD/cpu2006-1.2.iso
    if [ -e "$SPEC2006_ISO" ]
    then
        echo -e "${GREEN}log${OFF}: attempting to install SPEC2006 from" \
            "$SPEC2006_ISO image file..."
        sudo mount --read-only -o loop "$SPEC2006_ISO" "$MOUNT_POINT"
    else
        echo -e "${GREEN}log${OFF}: attempting to install SPEC2006 from" \
            "/dev/cdrom..."
        sudo mount --read-only /dev/cdrom "$MOUNT_POINT"
    fi
    if [ ! -e "$MOUNT_POINT/Revisions" ]
    then
        echo -e "${RED}ERROR${OFF}: $MOUNT_POINT is not the SPEC2006-1.2" \
            "installation disk"
        sudo umount "$MOUNT_POINT"
        exit 1
    fi
    md5sum "$MOUNT_POINT/Revisions" > cpu2006.md5
    if ! grep "c625c2108d653f74e983484ae4bae760" cpu2006.md5 >/dev/null
    then
        echo -e "${RED}ERROR${OFF}: $MOUNT_POINT is not the SPEC2006-1.2" \
            "installation disk"
        sudo umount "$MOUNT_POINT"
        exit 1      
    fi
    rm -f cpu2006.md5
    cd "$MOUNT_POINT"
    echo -e "${GREEN}log${OFF}: install SPEC2006..."
    ./install.sh -f -d "$SPEC2006_PATH"
    cd ..
    sudo umount "$MOUNT_POINT"
else
    echo -e "${GREEN}log${OFF}: using existing SPEC2006 installation" \
        "($SPEC2006_PATH)..."
fi

if [ ! -e "$SPEC2006_PATH/lowfat.patched" ]
then
    echo -e "${GREEN}log${OFF}: applying SPEC2006 patch..."
    SPEC2006_PATCH=cpu2006.patch
    cd "$SPEC2006_PATH"
    if ! patch -p0 < "../$SPEC2006_PATCH" > "lowfat.patched"
    then
        echo -e "${RED}ERROR${OFF}: failed to patch SPEC2006"
        exit 1
    fi
    cd ..
else
    echo -e "${GREEN}log${OFF}: assuming the SPEC2006 patch is already" \
        "applied..."
fi

LOWFAT_PATH=$PWD/..
LOWFAT_LOGFILE=$PWD/lowfat-cpu2006.log
cd "$SPEC2006_PATH"

if [ -e "$LOWFAT_LOGFILE" ]
then
    echo -e "${GREEN}log${OFF}: backing up old log file..."
    if [ -e "$LOWFAT_LOGFILE.bak" ]
    then
        mv -f "$LOWFAT_LOGFILE.bak" "$LOWFAT_LOGFILE.bak2"
    fi
    mv -f "$LOWFAT_LOGFILE" "$LOWFAT_LOGFILE.bak"
fi

##############################################################################

# Adapted from AddressSanitizer's SPEC2006 script:
#
# Simple script to run CPU2006 with AddressSanitizer.
# Make sure to use spec version 1.2 (SPEC_CPU2006v1.2).
# Run this script like this:
# $./run_spec_clang_asan.sh TAG size benchmarks...
# TAG is any word. If you use different TAGS you can runs several builds in
# parallel.
# size can be test, train or ref. test is a small data set, train is medium,
# ref is large.
# To run all C tests use all_c, for C++ use all_cpp. To run integer tests
# use int, for floating point use fp.
NAME=$1
shift
SIZE=$1
shift

usage()
{
    PROG=`basename $0`
    echo -e "${RED}USAGE${OFF}: $PROG TAG SIZE BENCHMARKS"
    echo
    echo -e "${YELLOW}NOTE${OFF}:"
    echo -e "\t- TAG is an arbitrary word, e.g. \"TEST\""
    echo -e "\t- SIZE is one of \"test\", \"train\" or \"ref\""
    echo -e "\t- BENCHMARKS specifies which benchmarks to run.  Use \"all\"" \
        "for to run all."
    exit 1
}

case "$SIZE" in
  test|train|ref)
    ;;
  *)
    echo -e "${RED}ERROR${OFF}: unknown size \"$SIZE\"."
    usage
    ;;
esac

ulimit -s 8092

SPEC_J=${SPEC_J:-4}
NUM_RUNS=${NUM_RUNS:-1}
CC=$LOWFAT_PATH/build/bin/clang
CXX=$LOWFAT_PATH/build/bin/clang++
BL=$LOWFAT_PATH/blacklist.txt
BIT=${BIT:-64}
OPT_LEVEL=${OPT_LEVEL:-"-O2"}
rm -rf config/$NAME.*
if [ -z "$FC" ]
then
    FC=echo
fi

## perf
COMMON_FLAGS="-ggdb -m$BIT -fsanitize=address -g -mllvm -asan-stack=0 -mllvm -asan-globals=0 -fsanitize-blacklist=$BL"
# COMMON_FLAGS="-m$BIT -fsanitize=address -g -mllvm -asan-stack=0 -mllvm -asan-globals=0 -fsanitize-blacklist=$BL"
# COMMON_FLAGS="-m$BIT -mlzcnt -fsanitize=lowfat -mllvm -lowfat-no-replace-alloca -mllvm -lowfat-no-replace-globals -mllvm -lowfat-no-check-escapes -mllvm -lowfat-no-check-blacklist=$BL"
# COMMON_FLAGS=""
CC="$CC    -std=gnu89 $COMMON_FLAGS"
CXX="$CXX             $COMMON_FLAGS"
FC="$FC     $COMMON_FLAGS"

cat << EOF > config/$NAME.cfg
monitor_wrapper = $SPEC_WRAPPER  \$command
monitor_specrun_wrapper = $SPECRUN_WRAPPER  \$command
ignore_errors = yes
tune          = base
ext           = $NAME
output_format = asc, Screen
reportable    = 1
teeout        = yes
teerunout     = yes
strict_rundir_verify = 0
makeflags = -j$SPEC_J

default=default=default=default:
CC  = $CC
CXX = $CXX
EXTRA_LIBS = $EXTRA_LIBS
FC         = $FC

default=base=default=default:
COPTIMIZE   = $OPT_LEVEL
CXXOPTIMIZE = $OPT_LEVEL

default=base=default=default:
PORTABILITY = -DSPEC_CPU_LP64

400.perlbench=default=default=default:
CPORTABILITY= -DSPEC_CPU_LINUX_X64

462.libquantum=default=default=default:
CPORTABILITY= -DSPEC_CPU_LINUX

483.xalancbmk=default=default=default:
CXXPORTABILITY= -DSPEC_CPU_LINUX -include string.h

447.dealII=default=default=default:
CXXPORTABILITY= -include string.h -include stdlib.h -include cstddef
EOF

pwd
# Use 0mb quarantine for disabling UAF checks
# Don't report alloc-dealloc-mismatch bugs (there is on in 471.omnetpp) and leaks
export ASAN_OPTIONS=quarantine_size_mb=0:alloc_dealloc_mismatch=0:detect_leaks=0${ASAN_OPTIONS:+:$ASAN_OPTIONS}
. shrc
## original
# runspec -c $NAME -a run -I -l --size $SIZE -n $NUM_RUNS $@
## perf
perf record -e cpu-clock:u -o ./perf.data.asan runspec -c $NAME -a run -I -l --size $SIZE -n $NUM_RUNS $@
