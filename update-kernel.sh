#!/bin/bash
# This script is changed from https://github.com/teddysun/across/blob/master/bbr.sh
# 本脚本改编自：https://github.com/teddysun/across/blob/master/bbr.sh
#
# Auto install latest kernel
#
# System Required:  CentOS 7+, Debian8+, Ubuntu16+
#

tyblue()                           #天依蓝
{
    echo -e "\033[36;1m${@}\033[0m"
}
green()                            #水鸭青
{
    echo -e "\033[32;1m${@}\033[0m"
}
yellow()                           #鸭屎黄
{
    echo -e "\033[33;1m${@}\033[0m"
}
red()                              #姨妈红
{
    echo -e "\033[31;1m${@}\033[0m"
}

[[ $EUID -ne 0 ]] && red "Error: This script must be run as root!" && exit 1

release=""
ARCH=""
systemVersion=""
redhat_version=""
redhat_package_manager=""
install_header=0

#确保系统支持
[[ -d "/proc/vz" ]] && red "Error: Your VPS is based on OpenVZ, which is not supported." && exit 1
check_important_dependence_installed()
{
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        if ! dpkg -s $1 2>&1 >/dev/null; then
            if ! apt -y --no-install-recommends install $1; then
                apt update
                if ! apt -y --no-install-recommends install $1; then
                    yellow "重要组件安装失败！！"
                    red "不支持的系统！！"
                    exit 1
                fi
            fi
        fi
    else
        if ! rpm -q $2 2>&1 >/dev/null; then
            if ! $redhat_package_manager -y install $2; then
                yellow "重要组件安装失败！！"
                red "不支持的系统！！"
                exit 1
            fi
        fi
    fi
}
version_ge()
{
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}
if [[ "$(type -P apt)" ]]; then
    if [[ "$(type -P dnf)" ]] || [[ "$(type -P yum)" ]]; then
        red "同时存在apt和yum/dnf"
        red "不支持的系统！"
        exit 1
    fi
    release="other-debian"
    redhat_package_manager="true"
elif [[ "$(type -P dnf)" ]]; then
    release="other-redhat"
    redhat_package_manager="dnf"
elif [[ "$(type -P yum)" ]]; then
    release="other-redhat"
    redhat_package_manager="yum"
else
    red "不支持的系统或apt/yum/dnf缺失"
    exit 1
fi
case "$(uname -m)" in
    'i386' | 'i686')
        ARCH='i386'
        ;;
    'amd64' | 'x86_64')
        ARCH='amd64'
        ;;
    'armv5tel' | 'armv6l' | 'armv7' | 'armv7l')
        ARCH='armhf'
        ;;
    'armv8' | 'aarch64')
        ARCH='arm64'
        ;;
    'riscv64')
        ARCH='riscv64'
        ;;
    'ppc64le')
        ARCH='ppc64el'
        ;;
    's390x')
        ARCH='s390x'
        ;;
    *)
        if [[ "$release" == 'other-debian' ]]; then
            echo "error: The architecture is not supported."
            exit 1
        fi
        ARCH=''
        ;;
esac
check_important_dependence_installed lsb-release redhat-lsb-core
if lsb_release -a 2>/dev/null | grep -qi "ubuntu"; then
    release="ubuntu"
elif lsb_release -a 2>/dev/null | grep -qi "debian"; then
    release="debian"
elif lsb_release -a 2>/dev/null | grep -qi "deepin"; then
    release="deepin"
elif lsb_release -a 2>/dev/null | grep -qi "centos"; then
    release="centos"
elif lsb_release -a 2>/dev/null | grep -qi "fedora"; then
    release="fedora"
fi
systemVersion=`lsb_release -r -s`
if [ $release == "fedora" ]; then
    if version_ge $systemVersion 28; then
        redhat_version=8
    elif version_ge $systemVersion 19; then
        redhat_version=7
    elif version_ge $systemVersion 12; then
        redhat_version=6
    else
        redhat_version=5
    fi
else
    redhat_version=$systemVersion
fi
check_important_dependence_installed ca-certificates ca-certificates

check_mem()
{
    if [ "$(cat /proc/meminfo |grep 'MemTotal' |awk '{print $3}' | tr [A-Z] [a-z])" == "kb" ]; then
        if [ "$(cat /proc/meminfo |grep 'MemTotal' |awk '{print $2}')" -le 400000 ]; then
            red    "检测到内存过小，更换最新版内核可能无法开机，请谨慎选择"
            yellow "按回车键以继续或ctrl+c中止"
            read -s
            echo
        fi
    else
        red    "请确保服务器的内存>=512MB，否则更换最新版内核可能无法开机"
        yellow "按回车键继续或ctrl+c中止"
        read -s
        echo
    fi
}

failed_version()
{
    local deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${1}/ | grep "href=\".*linux-image.*generic_.*$ARCH\.deb")
    if [ -z "${deb_name}" ]; then
        yellow "Kernel version v${1} for this arch build failed,finding next one"
        return 0
    else
        return 1
    fi
}
#获取可下载内核列表，包存在 kernel_list 中
get_kernel_list()
{
    tyblue "Info: Getting latest kernel version..."
    unset kernel_list
    local kernel_list_temp=($(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/ | awk -F'\"v' '/v[0-9]/{print $2}' | cut -d '"' -f1 | cut -d '/' -f1 | sort -rV))
    if [ ${#kernel_list_temp[@]} -le 1 ]; then
        red "failed to get the latest kernel version"
        exit 1
    fi
    local i=0
    local i2=0
    local i3=0
    local kernel_rc=""
    local kernel_list_temp2
    while ((i2<${#kernel_list_temp[@]}))
    do
        if [[ "${kernel_list_temp[i2]}" =~ "rc" ]] && [ "$kernel_rc" == "" ]; then
            kernel_list_temp2[i3]="${kernel_list_temp[i2]}"
            kernel_rc="${kernel_list_temp[i2]%%-*}"
            ((i3++))
            ((i2++))
        elif [[ "${kernel_list_temp[i2]}" =~ "rc" ]] && [ "${kernel_list_temp[i2]%%-*}" == "$kernel_rc" ]; then
            kernel_list_temp2[i3]=${kernel_list_temp[i2]}
            ((i3++))
            ((i2++))
        elif [[ "${kernel_list_temp[i2]}" =~ "rc" ]] && [ "${kernel_list_temp[i2]%%-*}" != "$kernel_rc" ]; then
            for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
            do
                kernel_list[i]=${kernel_list_temp2[i3]}
                ((i++))
            done
            kernel_rc=""
            i3=0
            unset kernel_list_temp2
        elif version_ge "$kernel_rc" "${kernel_list_temp[i2]}"; then
            if [ "$kernel_rc" == "${kernel_list_temp[i2]}" ]; then
                kernel_list[i]=${kernel_list_temp[i2]}
                ((i++))
                ((i2++))
            fi
            for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
            do
                kernel_list[i]=${kernel_list_temp2[i3]}
                ((i++))
            done
            kernel_rc=""
            i3=0
            unset kernel_list_temp2
        else
            kernel_list[i]=${kernel_list_temp[i2]}
            ((i++))
            ((i2++))
        fi
    done
    if [ "$kernel_rc" != "" ]; then
        for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
        do
            kernel_list[i]=${kernel_list_temp2[i3]}
            ((i++))
        done
    fi
}
get_latest_version() {
    get_kernel_list
    local i=0
    while failed_version ${kernel_list[i]}
    do
        ((i++))
    done
    kernel=${kernel_list[i]}

    headers_all_deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/ | grep "href=\".*linux-headers.*all\.deb" | head -1 | awk -F 'href="' '{print $2}' | cut -d '"' -f1)
    headers_all_deb_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${headers_all_deb_name}"
    headers_generic_deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/ | grep "href=\".*linux-headers.*generic_.*$ARCH\.deb" | awk -F 'href="' '{print $2}' | cut -d '"' -f1)
    headers_generic_deb_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${headers_generic_deb_name}"
    image_deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/ | grep "href=\".*linux-image.*generic_.*$ARCH\.deb" | awk -F 'href="' '{print $2}' | cut -d '"' -f1)
    image_deb_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${image_deb_name}"
    modules_deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/ | grep "href=\".*linux-modules.*generic_.*$ARCH\.deb" | awk -F 'href="' '{print $2}' | cut -d '"' -f1)
    modules_deb_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${modules_deb_name}"
}

remove_kernel()
{
    choice=""
    while [ "$choice" != "y" -a "$choice" != "n" ]
    do
        read -p "是否卸载多余内核？(y/n)" choice
    done
    if [ "$choice" == "n" ]; then
        return 0
    fi
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "other-debian" ] || [ $release == "deepin" ]; then
        kernel_list_headers=($(dpkg --list | grep 'linux-headers' | awk '{print $2}'))
        kernel_list_image=($(dpkg --list | grep 'linux-image' | awk '{print $2}'))
        kernel_list_modules=($(dpkg --list | grep 'linux-modules' | awk '{print $2}'))
        kernel_headers_all=${headers_all_deb_name%%_*}
        kernel_headers_all=${kernel_headers_all##*/}
        kernel_headers=${headers_generic_deb_name%%_*}
        kernel_headers=${kernel_headers##*/}
        kernel_image=${image_deb_name%%_*}
        kernel_image=${kernel_image##*/}
        kernel_modules=${modules_deb_name%%_*}
        kernel_modules=${kernel_modules##*/}
        if [ "$install_header" == "1" ]; then
            ok_install=0
            for ((i=${#kernel_list_headers[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_headers[$i]}" == "$kernel_headers" ]] ; then     
                    unset kernel_list_headers[$i]
                    ((ok_install++))
                fi
            done
            if [ "$ok_install" != "1" ] ; then
                red "内核可能安装失败！不卸载"
                return 1
            fi
            ok_install=0
            for ((i=${#kernel_list_headers[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_headers[$i]}" == "$kernel_headers_all" ]] ; then     
                    unset kernel_list_headers[$i]
                    ((ok_install++))
                fi
            done
            if [ "$ok_install" != "1" ] ; then
                red "内核可能安装失败！不卸载"
                return 1
            fi
        fi
        ok_install=0
        for ((i=${#kernel_list_image[@]}-1;i>=0;i--))
        do
            if [[ "${kernel_list_image[$i]}" == "$kernel_image" ]] ; then     
                unset kernel_list_image[$i]
                ((ok_install++))
            fi
        done
        if [ "$ok_install" != "1" ] ; then
            red "内核可能安装失败！不卸载"
            return 1
        fi
        ok_install=0
        for ((i=${#kernel_list_modules[@]}-1;i>=0;i--))
        do
            if [[ "${kernel_list_modules[$i]}" == "$kernel_modules" ]] ; then     
                unset kernel_list_modules[$i]
                ((ok_install++))
            fi
        done
        if [ "$ok_install" != "1" ] ; then
            red "内核可能安装失败！不卸载"
            return 1
        fi
        if [ ${#kernel_list_image[@]} -eq 0 ] && [ ${#kernel_list_modules[@]} -eq 0 ] && ([ $install_header -eq 0 ] || [ ${#kernel_list_headers[@]} -eq 0 ]); then
            red "未发现可卸载内核！不卸载"
            return 1
        fi
        yellow "卸载过程中弹出对话框，请选择NO！"
        yellow "卸载过程中弹出对话框，请选择NO！"
        yellow "卸载过程中弹出对话框，请选择NO！"
        tyblue "按回车键继续。。"
        read -s
        if [ "$install_header" == "1" ]; then
            apt -y purge ${kernel_list_headers[@]} ${kernel_list_image[@]} ${kernel_list_modules[@]}
        else
            apt -y purge ${kernel_list_image[@]} ${kernel_list_modules[@]}
        fi
        apt -y -f install
    else
        local kernel_list=($(rpm -qa |grep '^kernel-[0-9]\|^kernel-ml-[0-9]'))
        local kernel_list_devel=($(rpm -qa | grep '^kernel-devel\|^kernel-ml-devel'))
        if version_ge $redhat_version 8; then
            local kernel_list_modules=($(rpm -qa |grep '^kernel-modules\|^kernel-ml-modules'))
            local kernel_list_core=($(rpm -qa | grep '^kernel-core\|^kernel-ml-core'))
        fi
        if [ $((${#kernel_list[@]}-${#kernel_list_first[@]})) -le 0 ] || [ $((${#kernel_list_devel[@]}-${#kernel_list_devel_first[@]})) -le 0 ] || (version_ge $redhat_version 8 && ([ $((${#kernel_list_modules[@]}-${#kernel_list_modules_first[@]})) -le 0 ] || [ $((${#kernel_list_core[@]}-${#kernel_list_core_first[@]})) -le 0 ])); then
            red "内核可能未安装！不卸载"
            return 1
        fi
        if version_ge $redhat_version 8; then
            rpm -e --nodeps ${kernel_list_first[@]} ${kernel_list_devel_first[@]} ${kernel_list_modules_first[@]} ${kernel_list_core_first[@]}
        else
            rpm -e --nodeps ${kernel_list_first[@]} ${kernel_list_devel_first[@]}
        fi
    fi
    green '卸载完成'
}

reboot_os() {
    yellow "Info: The system needs to reboot. 系统需要重启"
    local choice=""
    while [[ "$choice" != "y" && "$choice" != "n" ]]
    do
        read -p "Do you want to restart system? 现在重启系统? [y/n]" choice
    done
    if [ $choice == "y" ]; then
        reboot
    else
        tyblue "Info: Reboot has been canceled..."
        exit 0
    fi
}

update_kernel() {
    check_mem
    if [ ${release} == "centos" ] || [ ${release} == "fedora" ] || [ ${release} == "other-redhat" ]; then
        kernel_list_first=($(rpm -qa |grep '^kernel-[0-9]\|^kernel-ml-[0-9]'))
        kernel_list_devel_first=($(rpm -qa | grep '^kernel-devel\|^kernel-ml-devel'))
        if version_ge $redhat_version 8; then
            kernel_list_modules_first=($(rpm -qa |grep '^kernel-modules\|^kernel-ml-modules'))
            kernel_list_core_first=($(rpm -qa | grep '^kernel-core\|^kernel-ml-core'))
        fi
        if ! version_ge $redhat_version 7; then
            red "仅支持Redhat 7+ (CentOS 7+)"
            exit 1
        fi
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        if version_ge $redhat_version 8; then
            $redhat_package_manager -y install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
        else
            $redhat_package_manager -y install https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
        fi
        [ ! -f "/etc/yum.repos.d/elrepo.repo" ] && red "Install elrepo failed, please check it and retry." && exit 1
        if $redhat_package_manager --help | grep -q "\-\-enablerepo="; then
            local redhat_install_command="$redhat_package_manager -y --enablerepo=elrepo-kernel install"
        else
            local redhat_install_command="$redhat_package_manager -y --enablerepo elrepo-kernel install"
        fi
        if version_ge $redhat_version 8; then
            $redhat_install_command kernel-ml kernel-ml-core kernel-ml-devel kernel-ml-modules
        else
            $redhat_install_command kernel-ml kernel-ml-devel
        fi
        if [ $? -ne 0 ]; then
            red "Error: Install latest kernel failed, please check it."
            exit 1
        fi
        #[ ! -f "/boot/grub2/grub.cfg" ] && red "/boot/grub2/grub.cfg not found, please check it."
        #grub2-set-default 0
    else
        ! command -v wget > /dev/null 2>&1 && ! apt -y install wget && apt update && apt -y install wget
        get_latest_version
        local latest_kernel_version=${image_deb_name##*/}
        latest_kernel_version=${latest_kernel_version%%_*}"("${latest_kernel_version#*_}
        latest_kernel_version=${latest_kernel_version%%_*}")"
        tyblue "latest_kernel_version=${latest_kernel_version}"
        local temp_your_kernel_version=$(uname -r)"("$(dpkg --list | grep $(uname -r) | head -n 1 | awk '{print $3}')")"
        tyblue "your_kernel_version=${temp_your_kernel_version}"
        if [[ "${latest_kernel_version}" =~ "${temp_your_kernel_version}" ]]; then
            echo
            green "Info: Your kernel version is lastest"
            exit 0
        fi
        rm -rf kernel_
        mkdir kernel_
        cd kernel_
        if ! ([ ${release} == "ubuntu" ] && version_ge $systemVersion 18.04) && ! ([ ${release} == "debian" ] && version_ge $systemVersion 10) && ! ([ ${release} == "deepin" ] && version_ge $systemVersion 20); then
            install_header=0
        fi
        [ $install_header -eq 1 ] && local wget_temp="${headers_all_deb_url} ${headers_generic_deb_url} ${image_deb_url} ${modules_deb_url}" || local wget_temp="${image_deb_url} ${modules_deb_url}"
        if ! wget ${wget_temp}; then
            red "下载内核失败！"
            exit 1
        fi
        dpkg -i *
        cd ..
        rm -rf kernel_
        apt -y -f install
    fi
    remove_kernel
    reboot_os
}

get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}
echo -e "\n\n\n"
echo "---------- System Information ----------"
echo " Release : $(lsb_release -i -s)"
echo " OS      : $(lsb_release -d -s)"
echo " Arch    : $(uname -m)"
echo " Kernel  : $(uname -r)"
echo "----------------------------------------"
echo " Auto install latest kernel"
echo
echo " URL: https://github.com/kirin10000/update-kernel"
echo "----------------------------------------"
echo "Press any key to start...or Press Ctrl+C to cancel"
get_char
update_kernel
