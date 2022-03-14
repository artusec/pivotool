#!/bin/bash

################################################################################
# pivotool -- by artuyero                                                      #
#                                                                              #
# As expected, is a simple tool written in bash that could help you in the     #
# post exploitation phase to pivot to other systems.                           #
# Usage:                                                                       #
# $ ./pivotool                                                                 #
# (promt in progress)~$ <command> <args>                                       #
################################################################################

# vars -------------------------------------------------------------------------
declare -a nets
declare -a targets
declare -a ports

# banner -----------------------------------------------------------------------
banner(){
cat << "EOF"

██████╗ ██╗██╗   ██╗ ██████╗ ████████╗ ██████╗  ██████╗ ██╗
██╔══██╗██║██║   ██║██╔═══██╗╚══██╔══╝██╔═══██╗██╔═══██╗██║
██████╔╝██║██║   ██║██║   ██║   ██║   ██║   ██║██║   ██║██║
██╔═══╝ ██║╚██╗ ██╔╝██║   ██║   ██║   ██║   ██║██║   ██║██║
██║     ██║ ╚████╔╝ ╚██████╔╝   ██║   ╚██████╔╝╚██████╔╝███████╗
╚═╝     ╚═╝  ╚═══╝   ╚═════╝    ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝
by artuyero

EOF
}

# exit -------------------------------------------------------------------------
ctrl_c(){
        echo -e "\n [*] Exiting...\n"
        exit 1
}

trap ctrl_c INT

# usages -----------------------------------------------------------------------
usage(){
        echo "Displaying help"
}

get_usage() {
        echo "Displaying get help"
}

scan_usage() {

        echo "Displaying scan help"
}

info_usage() {
        echo "Displaying info help"
}

# commands ---------------------------------------------------------------------
get_command(){
        while getopts "hnt:i" opt; do
                case "$opt" in
                        h) # help
                                get_usage
                                return
                                ;;
                        n) # nets
                                echo "[*] Getting nets..."
                                temp=$(ip a | grep "inet " | awk '{print $2}')
                                for net in $(echo $temp)
                                do
                                        nets=( "${nets[@]}" "$net" )
                                done
                                echo "${nets[@]}"
                                ;;
                        i) # system info
                                echo "[*] Getting system info..."
                                echo $(uname -a)
                                ;;
                esac
        done
}

scan_command(){
        while getopts "hn:t:" opt; do
                case "$opt" in
                        h)
                                scan_usage
                                return
                                ;;
                        n) # ping scan
                                net=${nets[$OPTARG]}
                                echo "[*] Scanning net: $net"
                                BASE_IP=$(echo $net | awk -F\/ '{print $1}')
                                IP_CIDR=$(echo $net | awk -F\/ '{print $2}')
                                IP_MASK=$((0xFFFFFFFF << (32 - ${IP_CIDR})))
                                IFS=. read a b c d <<<${BASE_IP}
                                ip=$((($b << 16) + ($c << 8) + $d))
                                ipstart=$((${ip} & ${IP_MASK}))
                                ipend=$(((${ipstart} | ~${IP_MASK}) & 0x7FFFFFFE))
                                ips=$(seq ${ipstart} ${ipend} | while read i; do
                                    echo $a.$((($i & 0xFF0000) >> 16)).$((($i & 0xFF00) >> 8)).$(($i & 0x00FF))
                                done)
                                temp=$(for i in $(echo $ips)
                                do
                                        ping -c 1 -W 5 ${i} | grep -q "bytes from" && echo "${i}" &
                                done; wait)
                                for host in $(echo $temp)
                                do
                                        echo "[*] Discovered ${host}"
                                        targets=( "${targets[@]}" "${host}" )
                                done
                                echo "${targets[@]}"
                                ;;
                        t) # port scan
                                target=${targets[$OPTARG]}
                                echo "Scanning target: $target"
                                for port in $(seq 1 65535)
                                do
                                        timeout 1 bash -c "echo '' > /dev/tcp/${target}/${port}" 2>/dev/null && echo "[*] PORT $port ACTIVE" && ports=( "${ports[@]}" "${port}" ) &
                                done; wait
                                echo "${ports[@]}"
                                ;;
                esac
        done
}

pivot_command(){
        while getopts "h?vf:" opt; do
                case "$opt" in
                        h|\?)
                                usage
                                ;;
                        v)
                                echo "v detected"
                                ;;
                        f)
                                echo "f detected"
                                ;;
                esac
        done
}

show_command(){
        while getopts "hntp" opt; do
                case "$opt" in
                        h)
                                info_usage
                                return
                                ;;
                        n)
                                echo "${nets[@]}"
                                return
                                ;;
                        t)
                                echo "${targets[@]}"
                                return
                                ;;
                        p)
                                return
                                ;;
                esac
        done
        # show info
}

exec_command() {
        echo "Executing shell command: $1"
        bash -c "${1}"
}

# main -------------------------------------------------------------------------
banner
while true
do
        read -p "_PIVOTOOL_:~$ " line
        command=$(echo $line | cut -d " " -f1)
        args=$(echo $line | cut -d " " -f2-)
        case $(echo $command | cut -f1) in
                get)
                        get_command "$args"
                        ;;
                scan)
                        scan_command "$args"
                        ;;
                pivot)
                        pivot_command "$args"
                        ;;
                show)
                        show_command "$args"
                        ;;
                exec)
                        exec_command "$args"
                        ;;
                help)
                        usage
                        ;;
                *)
                        usage
                        ;;
        esac
        unset OPTIND
done
