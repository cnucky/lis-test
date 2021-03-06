#!/bin/bash

################################################################
#
# KVP_BasicTest.sh
# Description:
# 1. verify that the KVP Daemon is running
# 2. run the KVP client tool and verify that the data pools are created and accessible
# 3. check kvp_pool file permission is 644
# 4. check kernel version supports hv_kvp
# 5. Use lsof to check the opened file number belonging to hypervkvp process does not increase
#    continually. If this number increases, maybe file descriptors are not closed properly.
#    Here check duration is after 2 minutes.
#
################################################################

InstallLsof()
{
    case $DISTRO in

        redhat* | centos* | fedora*)
            yum install lsof -y
            ;;
        ubuntu* | debian*)
            apt update; apt install -y lsof
            ;;
        suse* )
            zypper install -y lsof
                ;;
        *)
            msg="ERROR: Distro '$DISTRO' not supported"
            LogMsg "${msg}"
            UpdateSummary "${msg}"
            SetTestStateAborted
            exit 1
            ;;
    esac

    if [ $? -ne 0 ]; then
        LogMsg "ERROR: Failed to install lsof"
        UpdateSummary "ERROR: Failed to install lsof"
        SetTestStateAborted
        exit 1
    fi
}

dos2unix utils.sh
# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}
#
# Source constants file and initialize most common variables
#
UtilsInit
#
# 1. verify that the KVP Daemon is running
#
pid=`pgrep "hypervkvpd|hv_kvp_daemon"`
if [ $? -ne 0 ]; then
    LogMsg "KVP Daemon is not running by default"
    UpdateSummary "KVP daemon not running by default, basic test: Failed"
    SetTestStateFailed
    exit 10
fi
LogMsg "KVP Daemon is started on boot and it is running"

#
# 2. run the KVP client tool and verify that the data pools are created and accessible
#
uname -a | grep x86_64
if [ $? -eq 0 ]; then
    LogMsg "64 bit architecture was detected"
    kvp_client="kvp_client64"
else
    uname -a | grep i686
    if [ $? -eq 0 ]; then
        LogMsg "32 bit architecture was detected"
        kvp_client="kvp_client32"
    else
        LogMsg "Error: Unable to detect OS architecture"
        SetTestStateAborted
        exit 60
    fi
fi

chmod +x /root/kvp_client*
poolCount=`/root/$kvp_client | grep -i pool | wc -l`
if [ $poolCount -ne 5 ]; then
    msg="Error: Could not find a total of 5 KVP data pools"
    LogMsg $msg
    UpdateSummary $msg
    SetTestStateFailed
    exit 10
fi
LogMsg "Verified that all 5 KVP data pools are listed properly"

#
# 3. check kvp_pool file permission is 644
#
permCount=`stat -c %a /var/lib/hyperv/.kvp_pool* | grep 644 | wc -l`
if [ $permCount -ne 5 ]; then
    LogMsg ".kvp_pool file permission is incorrect "
    UpdateSummary ".kvp_pool file permission is incorrect"
    SetTestStateFailed
    exit 10
fi
LogMsg "Verified that .kvp_pool files permission is 644"

#
# 4. check kernel version supports hv_kvp
#
CheckVMFeatureSupportStatus "3.10.0-514"
if [ $? -eq 0 ]; then
    ls -la /proc/$pid/fd | grep /dev/vmbus/hv_kvp
    if [ $? -ne 0 ]; then
        LogMsg "ERROR: there is no hv_kvp in the /proc/$pid/fd "
        UpdateSummary "ERROR: there is no hv_kvp in the /proc/$pid/fd"
        SetTestStateFailed
        exit 1
    fi
else
    LogMsg "This kernel version does not support /dev/vmbus/hv_kvp, skip this step"
fi

#
# 5. check lsof number for kvp whether increase or not after sleep 2 minutes
#
GetDistro
command -v lsof
if [ $? -ne 0 ]; then
    InstallLsof
fi

lsofCountBegin=`lsof | grep -c kvp`
sleep 120
lsofCountEnd=`lsof | grep -c kvp`
if [ $lsofCountBegin -ne $lsofCountEnd ]; then
    msg="ERROR: hypervkvp opened file number has changed from $lsofCountBegin to $lsofCountEnd"
    LogMsg "${msg}"
    UpdateSummary "${msg}"
    SetTestStateFailed
    exit 10
fi
LogMsg "Verified that lsof for kvp is $lsofCountBegin, after 2 minutes is $lsofCountEnd"

UpdateSummary "KVP Daemon running, correct data pools permissions and reasonable lsof number for kvp"
SetTestStateCompleted
exit 0
