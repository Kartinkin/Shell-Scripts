#!/bin/sh

######################################################################
# Program:
# --------
# qHAPinfo.sh           Release 1.9.4 for Solaris
#
# Copyright (c) 1996-98 FullTime Software, Inc.
# All Rights Reserved Worldwide.
#
# $Id: qHAPinfo.sh.sol,v 1.2 1999/02/04 07:45:31 vlp Exp $
#
# Usage:
# ------
# One simply executes the program, for example,
#
#       nodename1# qHAPinfo.sh
#
# Borne or Korn shell:
#
#       nodename1# echo y | qHAPinfo.sh > qHAPinfo.log 2>&1
#
# C-shell:
#
#       nodename1# echo y | qHAPinfo.sh >& qHAPinfo.log
#
# Description:
# ------------
# This program will attempt to collect system and HA+ information
# which can be used for resolving issues with the HA+ environment of a
# customer.  Please save the file created by this program and send a
# copy to FullTime Software, Inc.:
#
#             ftp: ftp.fullsw.com
#           login: anonymous.  password: user_name@company.com.
#         example: ftp> cd /incoming
#                  ftp> put nodename1.tar.Z.uu
#                  ftp> put nodename2.tar.Z.uu
#                  ftp> bye
#
#           email: support@fullsw.com
#             www: http://www.fullsw.com
#
#       telephone: 1-650-572-0200.  fax: 1-650-572-1300
#
#         address: 177 Bovet, 2nd Floor, San Mateo, CA 94402
#
# What is archived to date:
# -------------------------
#       . Search for where the variable "files" is defined to examine
#         the list of files that will be archived if they exist.
#       . The HA+ etc, sg (service_groups), and nic2nic
#         directories will be archived.  For example, under Solaris and
#         for the default setting, this would be "/etc/opt/QUALha/etc"
#         and "/etc/opt/QUALha/sg".  Any other directories or files
#         under the HA+ base directory will be archived except the
#         following directories and any files and subdirectories under
#         these directories which will be excluded:
#           bin             examples        man
#           dev             jre             lib
#       . A listing of all "rc" files ("/etc/rc?.d/*" under Solaris)
#         will be archived.
#       . Data about the system is archived.  Search for the variable
#         "data_commands" to examine the list of commands which
#         will be executed to generate information about the system.
#       . Data about SDS is collected, including information suitable
#         for md.tab.
#       . Data about VxVM is collected, including some files and 
#         directories under /etc/vx, vxprint information in various
#         formats, and configuration database slices via the
#         command vxvm_saveconfig.sh.
#       . The last 10,000 lines of relevant log files are obtained.
#
# Remarks:
# --------
#       . One may wish to change the variable "work_dir".  One may
#         need to change this variable because of a lack of file
#         system free space.
#
work_dir="/tmp"
#         work_dir="/var/tmp"
#
#         Do not use the HA+ installation directory, which by
#         default is "/etc/opt/QUALha" under Solaris.  This is because
#         parts of this directory will be archived.
#       . If there are files or directories that should be included
#         but are not included by default, then simply create a
#         directory under the HA+ installation directory
#         and place these files and directories under this directory.
#         For example, create "/etc/opt/QUALha/FYI", that is, create
#         "FYI" under the default Solaris installation
#         directory "/etc/opt/QUALha".
#       . One could use "qHAPinfo.sh" to maintain a record of
#         configuration changes to ones HA+/system environment.
#
# Bug reports:
# ------------
# Send bug reports to support@fullsw.com.
#
# Things to do:
# -------------
#       . vxvm_gendg.sh <diskgroup>
#         Generates an executable script which will reconstruct
#         diskgroup, vmdisk, volume, plex, and subdisk objects.
#           Usage: vxvm_gendg.sh <diskgroup>
#         Returns: vxgen_<diskgroup>.sh
#         To be used by qHAPinfo.sh.
######################################################################

#
# Use Bourne shell's built-in "echo"
#
echo="echo"

#
# Define "check_executable" and "verify_executable".
#
check_executable() {
        if [ ! -x "${1}" ]; then
                ${echo} "Warning: unable to find an executable \"${1}\"." >&2
        fi
}

verify_executable() {
        if [ ! -x "${1}" ]; then
                ${echo} "Error: unable to find an executable \"${1}\"." >&2
                exit 1
        fi
}

#
# Verify executables.
#
# These are required:
awk="/bin/awk"
cat="/bin/cat"
id="/bin/id"
uname="/bin/uname"

for command in ${awk} ${cat} ${id} ${uname}; do
        verify_executable ${command}
done

#
# Determine the Operating System (OS).
#
OS=`${uname} -s -r`
case "${OS}" in
        "SunOS 5."*)
                :
        ;;
        *)      ${cat} >&2 <<EOF
"${OS}" is not currently supported.  Currently, the following
operating systems are supported:  Solaris 2.4+
EOF
                exit 1
        ;;
esac

#
# Who am I?  One must be root.
#
# Note: "uid=0(root)" appears only once in this script.
#
whoami=`${id} | ${awk} '/uid=0\(root\)/'`
if [ -z "${whoami}" ]; then
        ${echo} "Error: `${id}`.  One must be root." >&2
        exit 1
fi

#
# Determine the HA+ installation directory.
#
# Note: "machine.install_dir:" appears only once in this script.
#
# This is required:
qhap_conf="/etc/qhap.conf"
if [ -f "${qhap_conf}" ]; then
        install_dir=`\
           ${awk} '/^[ \t]*machine\.install_dir:[ \t]/{print $2}' \
              ${qhap_conf}`

        if [ ! -d "${install_dir}" ]; then
${echo} "Error: \"${install_dir}\" is not a directory." >&2
${echo} "Error: Cannot determine the HA+ installation directory." >&2
${echo} "Error: \"${qhap_conf}\" contains an error." >&2
                exit 1
        else
${echo} "The HA+ installation directory is \"${install_dir}\"."
${echo} ""
        fi
else
        ${echo} "Error: \"${qhap_conf}\" does not exist." >&2
        ${echo} "Error: There is no HA+ configuration file." >&2
        exit 1
fi

#
# Check the suitability of "${work_dir}".
#
if   [ ! -d "${work_dir}" ]; then
        ${echo} "Error: \"${work_dir}\" is not a directory." >&2
        ${echo} "Error: The variable \"work_dir\" is not set correctly." >&2
        exit 1
else
        ${echo} "The working directory is \"${work_dir}\"."
        ${echo} ""
fi

#
# Display an informational message.
#
######################################################################
${cat}  <<EOF
This program will attempt to collect system and HA+ information
which can be used for resolving issues with the HA+ environment of a
customer.  Please save the file created by this program and send a
copy to FullTime Software, Inc.:

              ftp: ftp.fullsw.com
            login: anonymous.  password: user_name@company.com.
          example: ftp> cd /incoming
                   ftp> put nodename1.tar.Z.uu
                   ftp> put nodename2.tar.Z.uu
                   ftp> bye

            email: support@fullsw.com
              www: http://www.fullsw.com

        telephone: 1-650-572-0200.  fax: 1-650-572-1300

          address: 177 Bovet, 2nd Floor, San Mateo, CA 94402

EOF
######################################################################
#
# Does one continue or stop?
#
${echo} "Continue? [y]: \c"; read anwser
if [ ! -z "${anwser}" -a "${anwser}" != "y" ]; then
        ${echo} "bye."
        exit 0
else
        ${echo} "ok ..."
fi

#
# Set up command variables to be absolute pathnames.
#
# Required commands.
#
basename="/bin/basename"
chmod="/bin/chmod"
compress="/bin/compress"
cp="/bin/cp"
dirname="/bin/dirname"
ls="/bin/ls"
mkdir="/bin/mkdir"
rm="/bin/rm"
tar="/usr/sbin/tar"
touch="/bin/touch"
uuencode="/bin/uuencode"
#
req_commands="
        ${basename}
        ${chmod}
        ${compress}
        ${cp}
        ${dirname}
        ${ls}
        ${mkdir}
        ${rm}
        ${tar}
        ${touch}
        ${uuencode}"
#
# Optional commands for system data generation.
#
arpinfo="/bin/netstat -pn"
checkkey="${install_dir}/bin/checkkey"
crash="/usr/sbin/crash"
df="/usr/sbin/df"
dmesg="/usr/sbin/dmesg"
eeprom="/usr/sbin/eeprom"
ifconfig="/usr/sbin/ifconfig"
ipcs="/bin/ipcs"
metadb="/usr/opt/SUNWmd/sbin/metadb"
metaset="/usr/opt/SUNWmd/sbin/metaset"
metastat="/usr/opt/SUNWmd/sbin/metastat"
mount="/sbin/mount"
netstat="/bin/netstat"
nawk="/bin/nawk"
ndd="/usr/sbin/ndd"
pkgchk="/usr/sbin/pkgchk"
[ `${uname} -r` != "5.4" ] && \
   prtdiag="/usr/platform/`uname -i`/sbin/prtdiag" || \
      prtdiag="prtdiag"
ps="/bin/ps"
prtvtoc="/usr/sbin/prtvtoc"
showrev="/bin/showrev"
swap="/usr/sbin/swap"
sysdef="/usr/sbin/sysdef"
tail="/bin/tail"
true="/bin/true"
version="${install_dir}/bin/cl -v"
vxdg="/usr/sbin/vxdg"
vxprint="/usr/sbin/vxprint"
vxsaveconfig="${install_dir}/bin/vxvm_saveconfig.sh"
#
# Optional functions for system data generation.
#
#
# Obtain VxVM data, if possible and if any.
#
# The variable data_file and dest_dir are defined below.
#
vxvm_data () {
if [ -x "${vxdg}" -a -x "${vxprint}" ]; then
 dgs=`${vxdg} list | ${awk} '$0 !~ /NAME/ {print $1}'`

 for dg in ${dgs}; do
  ${echo} "++++++++++++++++++++[ ${vxprint} -g ${dg} -vpshm ]:" >> ${data_file}
  ${vxprint} -g ${dg} -vpshm >> ${data_file}; ${echo} "" >> ${data_file}
 done

 if [ -x "${vxsaveconfig}" ]; then
  for dg in ${dgs}; do
   ${echo} "++++++++++++++++++++[ ${vxsaveconfig} ${dg} ]:" >> ${data_file}
   (cd ${dest_dir}; ${vxsaveconfig} ${dg} >> ${data_file} 2>&1)
  done
 fi
fi
}
#
# Obtain SDS data, if possible and if any.
#
# The variable data_file is defined below.
#
sds_data() {
if [ -x "${nawk}" -a -x "${metadb}" -a -x "${metaset}" -a "${metastat}" ]
then
   ${echo} "++++++++++++++++++++[ ${metaset} ]:" >> ${data_file}
   ${metaset} >> ${data_file}; ${echo} "" >> ${data_file}

   ${echo} "++++++++++++++++++++[ ${metadb} ]:" >> ${data_file}
   ${metadb} >> ${data_file}; ${echo} "" >> ${data_file}

   ${echo} "++++++++++++++++++++[ ${metastat} -p ]:" >> ${data_file}
   ${metastat} -p >> ${data_file}; ${echo} "" >> ${data_file}

   ${echo} "++++++++++++++++++++[ ${metastat} ]:" >> ${data_file}
   ${metastat} >> ${data_file}; ${echo} "" >> ${data_file}

   for ds in `${metaset} | ${nawk} '/^Set name =/{sub(",","",$0); print $4}'`
   do
      ${echo} "++++++++++++++++++++[ ${metadb} -s ${ds} ]:" >> ${data_file}
      ${metadb} -s ${ds} >> ${data_file}; ${echo} "" >> ${data_file}

      ${echo} "++++++++++++++++++++[ ${metastat} -s ${ds} -p ]:" >> ${data_file}
      ${metastat} -p -s ${ds} >> ${data_file}; ${echo} "" >> ${data_file}

      ${echo} "++++++++++++++++++++[ ${metastat} -s ${ds} ]:" >> ${data_file}
      ${metastat} -s ${ds} >> ${data_file}; ${echo} "" >> ${data_file}
   done
fi
}
#
# Used to generate system data.
#
# Note: "${data_commands}" is essentially an array of
#       commands, commands "${command00}" through ... .
#
command00="${sysdef} -h"
command01a="${checkkey}"
command01b="${version}"
command02="${cat} /etc/motd"
command03="${showrev}"
command04="${showrev} -p"
command05a="${df} -k"
command05b="${mount}"
command05c="${prtvtoc} /dev/rdsk/c*t*d*s2"
command06="${swap} -s"
command07="${swap} -l"
command08="${ifconfig} -a"
command09="${ndd} /dev/ip ip_forwarding"
command10a="${netstat} -rn"
command10b="${netstat} -gn"
command11="${netstat} -in"
command12="${netstat} -m"
command13="${netstat} -s"
command14="${netstat} -an"
command15="${arpinfo}"
command16="${ps} -efl"
#
# Note: Because of the use of "check_executable" below,
#       use "/bin/echo", an executable, so as to be
#       sure not to use the Bourne shell's built-in echo
#       for "command17".
#
command17="/bin/echo p | ${crash}"
command18="${sysdef}"
command19="${eeprom}"
command20="${dmesg}"
command21="${prtdiag} -v"
command22="${ipcs} -a"
command23="${vxdg} list"
command24="${vxprint} -Aht"
#
# Note: Because of the use of "check_executable" below,
#       the construct "${true} && sds_data" is a
#       trick so as to be able to include functions
#       in the for loop below.
#
command25="${true} && vxvm_data"
command26="${true} && sds_data"
#
# Check the package integrity last.
#
command98="${pkgchk} QUALha"
command99="${pkgchk} QLIXha"
command100a="${pkgchk} QLIXcma"
command100b="${pkgchk} QLIXcmc"
#
# Note: The commands are executed in the order
#       of top to bottom to generate system data.
#
data_commands='
        ${command00}
        ${command01a}
        ${command01b}
        ${command02}
        ${command03}
        ${command04}
        ${command05a}
        ${command05b}
        ${command05c}
        ${command06}
        ${command07}
        ${command08}
        ${command09}
        ${command10a}
        ${command10b}
        ${command11}
        ${command12}
        ${command13}
        ${command14}
        ${command15}
        ${command16}
        ${command17}
        ${command18}
        ${command19}
        ${command20}
        ${command21}
        ${command22}
        ${command23}
        ${command24}
        ${command25}
        ${command26}
        ${command98}
        ${command99}
        ${command100a}
        ${command100b}
        '

#
# Verify the executability of ${req_commands}.
#
# These are required:
for command in ${req_commands}; do
        verify_executable ${command}
done

#
# Set up list of files to archive.
#
files="$HOME/.cshrc
       $HOME/.login
       $HOME/.profile
       $HOME/.rhosts
       /etc/auto_*
       /etc/defaultdomain
       /etc/defaultrouter
       /etc/gateways
       /etc/hostname.*
       /etc/hosts*
       /etc/inetd.conf
       /etc/inittab
       /etc/name_to_major
       /etc/netmasks
       /etc/nodename
       /etc/notrouter
       /etc/nsswitch.conf
       /etc/path_to_inst
       ${qhap_conf}
       /etc/resolv.conf
       /etc/rpc
       /etc/services
       /etc/system
       /etc/vfstab
       /etc/dfs/dfstab
       /etc/init.d/qhapd
       /etc/rcS.d/S30rootusr.sh
       /etc/rc0.d/K51qhapd
       /etc/rc2.d/S69inet
       /etc/rc3.d/S99*
       /var/spool/cron/crontabs/adm
       /var/spool/cron/crontabs/root
       /var/spool/cron/crontabs/sys
      "

#
# Set up destination directory and file names.
#
archive=`${uname} -n`

dest_dir="${work_dir}/${archive}"

data_file="${dest_dir}/data_file"
rc_listing="${dest_dir}/rc_listing"

#
# Set up destination directory.
#
(
cd ${work_dir}
${rm} -rf ${archive} ${archive}.tar ${archive}.tar.Z ${archive}.tar.Z.uu
)

${mkdir} ${dest_dir}; ${chmod} 700 ${dest_dir}

#
# Define cleanup function and install interrupt handler
#
cleanup() {
(
cd ${work_dir}
${rm} -rf ${archive} ${archive}.tar ${archive}.tar.Z ${archive}.tar.Z.uu
)
exit 1
}

trap cleanup 1 2 3 4 10 15

#
# Copy OS specific files.
#
for file in ${files}; do
        ${echo} "Copying ${file} to ${dest_dir} ..."
        ${cp} -p ${file} ${dest_dir}
done

#
# Copy OS specific log files.
#
nlines="10000"
logs="/var/adm/messages /var/adm/log/qhap.log /var/adm/log/cma.log"
for log in ${logs}; do
   ${echo} "Copying ${nlines} lines of ${log} ..."
   ${tail} -${nlines} ${log} > ${dest_dir}/`${basename} ${log}`
done

#
# Copy QLIXds specific files.
#
qlixds="/etc/opt/QLIXds"
if [ -d "${qlixds}" ]; then
        ${echo} "Copying FullTime DataStar configuration files ..."
        parent_dir=`${dirname} ${qlixds}`
        child_dir=`${basename} ${qlixds}`
        (cd ${parent_dir}; ${tar} -cf - ./${child_dir}) | \
                (cd ${dest_dir}; ${tar} -xf -)
fi

#
# Copy SDS (ODS) specific files.
#
sds="/etc/opt/SUNWmd"
if [ -d "${sds}" ]; then
        ${echo} "Copying Solstice DiskSuite files ..."
        parent_dir=`${dirname} ${sds}`
        child_dir=`${basename} ${sds}`
        (cd ${parent_dir}; ${tar} -cf - ./${child_dir}) | \
                (cd ${dest_dir}; ${tar} -xf -)
fi

#
# Copy VxVM (vxfs) specific files.
#
vxvm="/etc/vx"
vx=`${basename} ${vxvm}`
list="./elm ./reconfig.d ./type ./volboot"
if [ -d "${vxvm}" ]; then
        ${echo} "Copying VxVM files ..."
        ${mkdir} -p ${dest_dir}/${vx}
        (cd ${vxvm}; ${tar} -cf - ${list}) | \
                (cd ${dest_dir}/${vx}; ${tar} -xf -)
fi

#
# Generate the "rc" listing.
#
${echo} "Generating an \"rc\" listing ..."
${ls} -al /etc/rc?.d > ${rc_listing}

#
# Copy the key elements of the HA+ installation directory.
#
${echo} "Copying elements of the HA+"\
        "base directory ${install_dir} ..."

parent_dir=`${dirname} ${install_dir}`
child_dir=`${basename} ${install_dir}`

# Set up exclude file:
exclude=${dest_dir}/excluded
${cat} > ${exclude} <<EOF
./${child_dir}/bin
./${child_dir}/examples
./${child_dir}/jre
./${child_dir}/lib
./${child_dir}/man
EOF

(cd ${parent_dir}; ${tar} -cfX - ${exclude} ./${child_dir}) | \
   (cd ${dest_dir}; ${tar} -xf -)

#
# Generate the data file.
#
# Note: The use of "check_executable ${command}" will work when
#       "${command}" has the form "<command> <flags>".  This usage
#       could give somewhat misleading information in some cases,
#       for example, "/bin/echo p | crash".
#
${echo} "Generating HA+/system data .\c"
${touch} ${data_file}
#
for command in ${data_commands}; do
        eval execute="${command}"
        ${echo} "++++++++++++++++++++[ ${execute} ]:" >> ${data_file} 
        result=`check_executable ${execute} 2>&1`
        if [ -z "${result}" ]; then
                eval ${execute} >> ${data_file} 2>&1
        else
                ${echo} "${result}" >> ${data_file}
        fi
        ${echo} "" >> ${data_file}
        ${echo} ".\c" 
done
        ${echo} ""

#
# Make the archive.
#
${echo} "Making the archive ..."
(
cd ${work_dir}

${tar} -cvf - ./${archive} | ${compress} > ${archive}.tar.Z

${uuencode} ${archive}.tar.Z < ${archive}.tar.Z > ${archive}.tar.Z.uu

${rm} -rf ${archive} ${archive}.tar ${archive}.tar.Z

${chmod} 600 ${archive}.tar.Z.uu
)

${cat} <<EOF

Done:
*---*
`${ls} -l ${work_dir}/${archive}.tar.Z.uu`

Please ftp/email the above file to FullTime Software, Inc.:

          ftp: ftp.fullsw.com:/incoming
        email: support@fullsw.com

EOF
exit 0
