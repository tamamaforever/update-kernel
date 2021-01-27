#!/bin/bash
# This script is changed from https://github.com/teddysun/across/blob/master/bbr.sh
# 本脚本改编自：https://github.com/teddysun/across/blob/master/bbr.sh
#
# Auto install latest kernel
#
# System Required:  CentOS 7+, Debian8+, Ubuntu16+

install_header=0

#系统信息
#指令集
machine=""
#什么系统
release=""
#系统版本号
systemVersion=""
redhat_version=""
debian_package_manager=""
redhat_package_manager=""

#功能性函数：
#定义几个颜色
purple()                           #基佬紫
{
    echo -e "\\033[35;1m${*}\\033[0m"
}
tyblue()                           #天依蓝
{
    echo -e "\\033[36;1m${*}\\033[0m"
}
green()                            #水鸭青
{
    echo -e "\\033[32;1m${*}\\033[0m"
}
yellow()                           #鸭屎黄
{
    echo -e "\\033[33;1m${*}\\033[0m"
}
red()                              #姨妈红
{
    echo -e "\\033[31;1m${*}\\033[0m"
}
check_base_command()
{
    local i
    local temp_command_list=('bash' 'true' 'false' 'exit' 'echo' 'test' 'free' 'sort' 'sed' 'awk' 'grep' 'cut' 'cd' 'rm' 'cp' 'mv' 'head' 'tail' 'uname' 'tr' 'md5sum' 'tar' 'cat' 'find' 'type' 'command' 'kill' 'pkill' 'wc' 'ls' 'mktemp')
    for i in ${!temp_command_list[@]}
    do
        if ! command -V "${temp_command_list[$i]}" > /dev/null; then
            red "命令\"${temp_command_list[$i]}\"未找到"
            red "不是标准的Linux系统"
            exit 1
        fi
    done
}
#版本比较函数
version_ge()
{
    test "$(echo -e "$1\\n$2" | sort -rV | head -n 1)" == "$1"
}
#安装单个重要依赖
check_important_dependence_installed()
{
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        if dpkg -s "$1" > /dev/null 2>&1; then
            apt-mark manual "$1"
        elif ! $debian_package_manager -y --no-install-recommends install "$1"; then
            $debian_package_manager update
            if ! $debian_package_manager -y --no-install-recommends install "$1"; then
                red "重要组件\"$1\"安装失败！！"
                yellow "按回车键继续或者Ctrl+c退出"
                read -s
            fi
        fi
    else
        if rpm -q "$2" > /dev/null 2>&1; then
            if [ "$redhat_package_manager" == "dnf" ]; then
                dnf mark install "$2"
            else
                yumdb set reason user "$2"
            fi
        elif ! $redhat_package_manager -y install "$2"; then
            red "重要组件\"$2\"安装失败！！"
            yellow "按回车键继续或者Ctrl+c退出"
            read -s
        fi
    fi
}
ask_if()
{
    local choice=""
    while [ "$choice" != "y" ] && [ "$choice" != "n" ]
    do
        tyblue "$1"
        read choice
    done
    [ $choice == y ] && return 0
    return 1
}
check_mem()
{
    if (($(free -m | sed -n 2p | awk '{print $2}')<300)); then
        red    "检测到内存小于300M，更换内核可能无法开机，请谨慎选择"
        yellow "按回车键以继续或ctrl+c中止"
        read -s
        echo
    fi
}


if [[ -d "/proc/vz" ]]; then
    red "Error: Your VPS is based on OpenVZ, which is not supported."
    exit 1
fi
check_base_command
if [ "$EUID" != "0" ]; then
    red "请用root用户运行此脚本！！"
    exit 1
fi
if [[ "$(type -P apt)" ]]; then
    if [[ "$(type -P dnf)" ]] || [[ "$(type -P yum)" ]]; then
        red "同时存在apt和yum/dnf"
        red "不支持的系统！"
        exit 1
    fi
    release="other-debian"
    debian_package_manager="apt"
    redhat_package_manager="true"
elif [[ "$(type -P dnf)" ]]; then
    release="other-redhat"
    redhat_package_manager="dnf"
    debian_package_manager="true"
elif [[ "$(type -P yum)" ]]; then
    release="other-redhat"
    redhat_package_manager="yum"
    debian_package_manager="true"
else
    red "apt yum dnf命令均不存在"
    red "不支持的系统"
    exit 1
fi
case "$(uname -m)" in
    'i386' | 'i686')
        machine='i386'
        ;;
    'amd64' | 'x86_64')
        machine='amd64'
        ;;
    'armv5tel' | 'armv6l' | 'armv7' | 'armv7l')
        machine='armhf'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || machine=''
        ;;
    'armv8' | 'aarch64')
        machine='arm64'
        ;;
    'riscv64')
        machine='riscv64'
        ;;
    'ppc64le')
        machine='ppc64el'
        ;;
    's390x')
        machine='s390x'
        ;;
    *)
        machine=''
        ;;
esac
if ([ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]) && [ -z "$machine" ]; then
    red "不支持的系统架构"
    exit 1
fi

#获取系统版本信息
get_system_info()
{
    local temp_release
    temp_release="$(lsb_release -i -s | tr "[:upper:]" "[:lower:]")"
    if [[ "$temp_release" =~ ubuntu ]]; then
        release="ubuntu"
    elif [[ "$temp_release" =~ debian ]]; then
        release="debian"
    elif [[ "$temp_release" =~ deepin ]]; then
        release="deepin"
    elif [[ "$temp_release" =~ centos ]]; then
        release="centos"
    elif [[ "$temp_release" =~ fedora ]]; then
        release="fedora"
    fi
    systemVersion="$(lsb_release -r -s)"
    if [ $release == "fedora" ]; then
        if version_ge "$systemVersion" 30; then
            redhat_version=8
        elif version_ge "$systemVersion" 19; then
            redhat_version=7
        elif version_ge "$systemVersion" 12; then
            redhat_version=6
        else
            redhat_version=5
        fi
    else
        redhat_version=$systemVersion
    fi
}

#获取可下载内核列表，包存在 kernel_list 中
get_kernel_list()
{
    tyblue "Info: Getting latest kernel version..."
    kernel_list=()
    local temp_file
    temp_file="$(mktemp)"
    if ! wget -O "$temp_file" "https://kernel.ubuntu.com/~kernel-ppa/mainline/"; then
        rm "$temp_file"
        red "获取内核版本失败"
        exit 1
    fi
    local kernel_list_temp
    kernel_list_temp=($(awk -F'\"v' '/v[0-9]/{print $2}' "$temp_file" | cut -d '"' -f1 | cut -d '/' -f1 | sort -rV))
    rm "$temp_file"
    if [ ${#kernel_list_temp[@]} -le 1 ]; then
        red "failed to get the latest kernel version"
        exit 1
    fi
    local i2=0
    local i3
    local kernel_rc=""
    local kernel_list_temp2
    while ((i2<${#kernel_list_temp[@]}))
    do
        if [[ "${kernel_list_temp[$i2]}" =~ -rc(0|[1-9][0-9]*)$ ]] && [ "$kernel_rc" == "" ]; then
            kernel_list_temp2=("${kernel_list_temp[$i2]}")
            kernel_rc="${kernel_list_temp[$i2]%-*}"
            ((i2++))
        elif [[ "${kernel_list_temp[$i2]}" =~ -rc(0|[1-9][0-9]*)$ ]] && [ "${kernel_list_temp[$i2]%-*}" == "$kernel_rc" ]; then
            kernel_list_temp2+=("${kernel_list_temp[$i2]}")
            ((i2++))
        elif [[ "${kernel_list_temp[$i2]}" =~ -rc(0|[1-9][0-9]*)$ ]] && [ "${kernel_list_temp[$i2]%-*}" != "$kernel_rc" ]; then
            for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
            do
                kernel_list+=("${kernel_list_temp2[$i3]}")
            done
            kernel_rc=""
        elif [ -z "$kernel_rc" ] || version_ge "${kernel_list_temp[$i2]}" "$kernel_rc"; then
            kernel_list+=("${kernel_list_temp[$i2]}")
            ((i2++))
        else
            for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
            do
                kernel_list+=("${kernel_list_temp2[$i3]}")
            done
            kernel_rc=""
        fi
    done
    if [ -n "$kernel_rc" ]; then
        for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
        do
            kernel_list+=("${kernel_list_temp2[$i3]}")
        done
    fi
}
get_latest_version() {
    local kernel_list
    get_kernel_list
    local temp_file
    temp_file="$(mktemp)"
    local i
    for ((i=0;i<${#kernel_list[@]};i++))
    do
        if ! wget -O "$temp_file" "https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel_list[$i]}/"; then
            red "获取内核版本失败"
            rm "$temp_file"
            return 1
        fi
        if grep -q "href=\".*linux-image.*generic_.*$machine\\.deb" "$temp_file"; then
            break
        else
            yellow "Kernel version v${temp_file} for this arch build failed,finding next one"
        fi
    done
    headers_all_deb_name="$(grep "href=\".*linux-headers.*all\\.deb" "$temp_file" | head -1 | awk -F 'href="' '{print $2}' | cut -d '"' -f1)"
    headers_all_deb_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel_list[$i]}/${headers_all_deb_name}"
    headers_generic_deb_name="$(grep "href=\".*linux-headers.*generic_.*$machine\\.deb" "$temp_file" | head -1 | awk -F 'href="' '{print $2}' | cut -d '"' -f1)"
    headers_generic_deb_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel_list[$i]}/${headers_generic_deb_name}"
    image_deb_name="$(grep "href=\".*linux-image.*generic_.*$machine\\.deb" "$temp_file" | head -1 | awk -F 'href="' '{print $2}' | cut -d '"' -f1)"
    image_deb_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel_list[$i]}/${image_deb_name}"
    modules_deb_name="$(grep "href=\".*linux-modules.*generic_.*$machine\\.deb" "$temp_file" | head -1 | awk -F 'href="' '{print $2}' | cut -d '"' -f1)"
    modules_deb_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel_list[$i]}/${modules_deb_name}"
    rm "$temp_file"
}

remove_kernel()
{
    local exit_code
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "other-debian" ] || [ $release == "deepin" ]; then
        local kernel_list_headers
        kernel_list_headers=($(dpkg --list | grep 'linux-headers' | awk '{print $2}'))
        local kernel_list_image
        kernel_list_image=($(dpkg --list | grep 'linux-image' | awk '{print $2}'))
        local kernel_list_modules
        kernel_list_modules=($(dpkg --list | grep 'linux-modules' | awk '{print $2}'))
        local kernel_headers_all="${headers_all_deb_name%%_*}"
        kernel_headers_all="${kernel_headers_all##*/}"
        local kernel_headers="${headers_generic_deb_name%%_*}"
        kernel_headers="${kernel_headers##*/}"
        local kernel_image="${image_deb_name%%_*}"
        kernel_image="${kernel_image##*/}"
        local kernel_modules="${modules_deb_name%%_*}"
        kernel_modules="${kernel_modules##*/}"
        local ok_install
        local i
        if [ "$install_header" == "1" ]; then
            ok_install=0
            for ((i=${#kernel_list_headers[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_headers[$i]}" == "$kernel_headers" ]] ; then     
                    unset 'kernel_list_headers[$i]'
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
                    unset 'kernel_list_headers[$i]'
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
                unset 'kernel_list_image[$i]'
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
                unset 'kernel_list_modules[$i]'
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
        exit_code=1
        if [ "$install_header" == "1" ]; then
            apt -y purge "${kernel_list_headers[@]}" "${kernel_list_image[@]}" "${kernel_list_modules[@]}" && exit_code=0
        else
            apt -y purge "${kernel_list_image[@]}" "${kernel_list_modules[@]}" && exit_code=0
        fi
        if [ $exit_code -ne 0 ]; then
            apt -y -f install
            red "卸载失败！"
            yellow "按回车键继续或Ctrl+c退出"
            read -s
        else
            green "卸载成功"
        fi
    else
        local kernel_list
        kernel_list=($(rpm -qa |grep '^kernel-[0-9]\|^kernel-ml-[0-9]'))
        local kernel_list_devel
        kernel_list_devel=($(rpm -qa | grep '^kernel-devel\|^kernel-ml-devel'))
        if version_ge "$redhat_version" 8; then
            local kernel_list_modules
            kernel_list_modules=($(rpm -qa |grep '^kernel-modules\|^kernel-ml-modules'))
            local kernel_list_core
            kernel_list_core=($(rpm -qa | grep '^kernel-core\|^kernel-ml-core'))
        fi
        if [ $((${#kernel_list[@]}-${#kernel_list_first[@]})) -le 0 ] || [ $((${#kernel_list_devel[@]}-${#kernel_list_devel_first[@]})) -le 0 ] || (version_ge "$redhat_version" 8 && ([ $((${#kernel_list_modules[@]}-${#kernel_list_modules_first[@]})) -le 0 ] || [ $((${#kernel_list_core[@]}-${#kernel_list_core_first[@]})) -le 0 ])); then
            red "内核可能未安装！不卸载"
            return 1
        fi
        exit_code=1
        if version_ge "$redhat_version" 8; then
            rpm -e --nodeps "${kernel_list_first[@]}" "${kernel_list_devel_first[@]}" "${kernel_list_modules_first[@]}" "${kernel_list_core_first[@]}" && exit_code=0
        else
            rpm -e --nodeps "${kernel_list_first[@]}" "${kernel_list_devel_first[@]}" && exit_code=0
        fi
        if [ $exit_code -ne 0 ]; then
            red "卸载失败！"
            yellow "按回车键继续或Ctrl+c退出"
            read -s
            return 1
        else
            green "卸载成功"
        fi
    fi
}

update_kernel() {
    check_mem
    check_important_dependence_installed lsb-release redhat-lsb-core
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    if [ ${release} == "centos" ] || [ ${release} == "fedora" ] || [ ${release} == "other-redhat" ]; then
        kernel_list_first=($(rpm -qa |grep '^kernel-[0-9]\|^kernel-ml-[0-9]'))
        kernel_list_devel_first=($(rpm -qa | grep '^kernel-devel\|^kernel-ml-devel'))
        if version_ge "$redhat_version" 8; then
            kernel_list_modules_first=($(rpm -qa |grep '^kernel-modules\|^kernel-ml-modules'))
            kernel_list_core_first=($(rpm -qa | grep '^kernel-core\|^kernel-ml-core'))
        fi
        if ! version_ge "$redhat_version" 7; then
            red "仅支持Redhat 7+ (CentOS 7+)"
            exit 1
        fi
        if ! rpm --import "https://www.elrepo.org/RPM-GPG-KEY-elrepo.org"; then
            red "导入elrepo公钥失败"
            yellow "按回车键继续或Ctrl+c退出"
            read -s
        fi
        if version_ge "$redhat_version" 8; then
            local elrepo_url="https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm"
        else
            local elrepo_url="https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm"
        fi
        if ! $redhat_package_manager -y install "$elrepo_url"; then
            red "Install elrepo failed, please check it and retry."
            yellow "按回车键继续或Ctrl+c退出"
            read -s
        fi
        if $redhat_package_manager --help | grep -q "\\-\\-enablerepo="; then
            local redhat_install_command=("$redhat_package_manager" "-y" "--enablerepo=elrepo-kernel" "install")
        else
            local redhat_install_command=("$redhat_package_manager" "-y" "--enablerepo" "elrepo-kernel" "install")
        fi
        if version_ge "$redhat_version" 8; then
            local temp_install=("kernel-ml" "kernel-ml-core" "kernel-ml-devel" "kernel-ml-modules")
        else
            local temp_install=("kernel-ml" "kernel-ml-devel")
        fi
        [ $install_header -eq 1 ] && temp_install+=("kernel-ml-headers")
        if ! "${redhat_install_command[@]}" "${temp_install[@]}"; then
            red "Error: Install latest kernel failed, please check it."
            yellow "按回车键继续或Ctrl+c退出"
            read -s
        fi
        #[ ! -f "/boot/grub2/grub.cfg" ] && red "/boot/grub2/grub.cfg not found, please check it."
        #grub2-set-default 0
    else
        check_important_dependence_installed wget wget
        get_latest_version
        local latest_kernel_version="${image_deb_name##*/}"
        latest_kernel_version="${latest_kernel_version%%_*}(${latest_kernel_version#*_}"
        latest_kernel_version="${latest_kernel_version%%_*})"
        tyblue "latest_kernel_version=${latest_kernel_version}"
        local temp_your_kernel_version
        temp_your_kernel_version="$(uname -r)($(dpkg --list | grep "$(uname -r)" | head -n 1 | awk '{print $3}'))"
        tyblue "your_kernel_version=${temp_your_kernel_version}"
        if [[ "${latest_kernel_version}" =~ "${temp_your_kernel_version}" ]]; then
            echo
            green "Info: Your kernel version is lastest"
            return 0
        fi
        rm -rf kernel_
        mkdir kernel_
        cd kernel_
        if ! ([ ${release} == "ubuntu" ] && version_ge "$systemVersion" 18.04) && ! ([ ${release} == "debian" ] && version_ge "$systemVersion" 10) && ! ([ ${release} == "deepin" ] && version_ge "$systemVersion" 20); then
            install_header=0
        fi
        local wget_temp=("${image_deb_url}" "${modules_deb_url}")
        [ $install_header -eq 1 ] && wget_temp+=("${headers_all_deb_url}" "${headers_generic_deb_url}")
        if ! wget "${wget_temp[@]}"; then
            cd ..
            rm -rf kernel_
            red "下载内核失败！"
            exit 1
        fi
        if ! dpkg -i *; then
            apt -y -f install
            cd ..
            rm -rf kernel_
            red "安装失败！"
            exit 1
        fi
        cd ..
        rm -rf kernel_
        apt -y -f install
    fi
    ask_if "是否卸载其余内核？(y/n)" && remove_kernel
    green "安装完成"
    yellow "系统需要重启"
    if ask_if "现在重启系统? (y/n)"; then
        reboot
    else
        yellow "请尽快重启！"
    fi
}

get_char() {
    SAVEDSTTY="$(stty -g)"
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty "$SAVEDSTTY"
}
echo -e "\\n\\n\\n"
echo "---------- System Information ----------"
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
