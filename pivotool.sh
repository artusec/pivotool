#!/bin/bash

################################################################################
# pivotool -- by artuyero                                                      #
#                                                                              #
# pivotool in ethical hacking, as expected, is a simple tool written in bash   #
# that could help you in the post exploitation phase to pivot to other systems.#
#                                                                              #
# Usage:                                                                       #
# $ ./pivotool                                                                 #
# _PIVOTOOL_:~$ <command> <args>                                               #
################################################################################

# vars -------------------------------------------------------------------------
declare -a nets
declare -a targets
declare -a ports
declare -a tunnels

PROMPT="_PIVOTOOL_:~$"

# history ----------------------------------------------------------------------
set -o history

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
        house_cleaning
        echo -e "\n[*] Exiting.\n"; exit 1
        bye
}

bye(){
        echo -e "Bye!"
}

trap ctrl_c INT

# usages -----------------------------------------------------------------------
usage(){
        echo "Usage:"
        echo -e '\t$ ./pivotool.sh';echo
        echo "Commands:"
        echo -e '\tget\tObtains data from the victim server and its environment.'
        echo -e '\tscan\tPerforms a scan of a network or host.'
        echo -e '\tpivot\tPerforms port forwarding.'
        echo -e '\tshow\tDisplays the information that has been collected.'
        echo -e '\texec\tRun a bash command on the system.'
        echo -e '\treport\tShow all the information.';echo
        echo "Use the "-h" option after each command to get its help.";echo
}

get_usage() {
        echo "[*] Displaying \"get\" help.";echo
        echo "\$ get [flags] -> Obtains data from the victim server and its environment.";echo
        echo "Flags:"
        echo -e '\t-n\tGets the networks to which the host is connected.'
        echo -e '\t-i\tGets system info.';echo
}

scan_usage() {
        echo "[*] Displaying \"scan\" help.";echo
        echo "\$ scan [flags] -> Performs a scan of a network or host.";echo
        echo "Flags:"
        echo -e '\t-n INT\tPerforms a ping scan on the selected network.'
        echo -e '\t-t INT\tPerforms a simple port scan on the selected host.'
        echo
}

pivot_usage() {
        echo "[*] Displaying \"pivot\" help.";echo
        echo "\$ pivot [flags] -> Perform a port forwarding.";echo
        echo "Flags:"
        echo -e '\t-t INT\tIndex of the target (show -t).'
        echo -e '\t-p INT\tRemote port.'
        echo -e '\t-P INT\tLocal port.';echo
}

show_usage() {
        echo "[*] Displaying \"show\" help.";echo
        echo "\$ show [flags] -> Displays the information that has been collected.";echo
        echo "Flags:"
        echo -e '\t-n\tShow the nets.'
        echo -e '\t-t\tShow the targets.'
        echo -e '\t-p\tShow the ports of each target.'
        echo -e '\t-T\tShow the created tunnels.';echo
}

exec_usage() {
        echo "Displaying \"exec\" help.";echo
        echo "\$ exec [command] -> Exec bash -c <command>";echo
}

report_usage() {
        echo "Displaying \"report\" help.";echo
        echo "\$ report -> Write all info in a file.";echo
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
                echo "$cont -> $(echo $target | awk -F, '{print $2}')"
                ((cont=cont+1))
        done 
}

show_ports() {
        for line in "${ports[@]}"
        do
                indexTarget=$(echo $line | awk -F, '{print $1}')
                port=$(echo $line | awk -F, '{print $2}')
                target=$(echo ${targets[$indexTarget]} | awk -F, '{print $2}')
                echo "$indexTarget -> $target : $port"
        done
}

show_tunnels() {
        cont=0
        for tunnel in "${tunnels[@]}"
        do
                echo "$cont -> ${tunnels[$cont]}"
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

house_cleaning(){
        echo "[*] Cleaning..."
        history -c
        rm ./fifo ./report.pt 2>/dev/null
        for tunnel in "${tunnels[@]}"
        do
                pid=$(echo $tunnel | cut -d" " -f2)
                pkill -TERM -P $pid
                ((cont=cont+1))
        done
        bye
}

# commands ---------------------------------------------------------------------
get_command(){
        while getopts "hni" opt; do
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
                                if [ "$OPTARG" -ge ${#nets[@]} ] ; then echo "[ERROR] Invalid network number. Enter from 0 to $((${#nets[@]}-1))"; return; fi
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
                                        ping -c 1 -W 5 ${i} 2>/dev/null | grep -q "bytes from" && echo "${i}" &
                                done; wait)

                                for host in $(echo $temp)
                                do
                                        echo "[*] Discovered ${host}"
                                        if [[ ! " ${targets[*]} " =~ " $OPTARG,${host} " ]]; then
                                                targets=( "${targets[@]}" "${OPTARG},${host}" )
                                        fi
                                done
                                show_targets
                                ;;
                        t) # port scan
                                if [ "${#targets[@]}" -eq 0 ] ; then echo '[ERROR] There are no registered targets. Run "scan -n <net>".'; return; fi
                                if ! is_positive_integer "$OPTARG" ; then return; fi
                                if [ "$OPTARG" -ge ${#targets[@]} ] ; then echo "[ERROR] Invalid target number. Enter from 0 to $((${#targets[@]}-1))"; return; fi
                                target=$(echo ${targets[$OPTARG]} | awk -F, '{print $2}')
                                echo "Scanning target: $target"
                                unset temp; temp=$(for i in $(seq 1 81) # change to 65535
                                do
                                        timeout 1 bash -c "echo > /dev/tcp/${target}/${i}" 2>/dev/null && echo -n "${i} " &
                                done; wait)
                                if [ -z "$temp" ]; then
                                        temp="no open ports"
                                fi
                                echo "[*] Discovered ${temp}"
                                if [[ ! " ${ports[*]} " =~ " $OPTARG,${temp} " ]]; then
                                        ports=( "${ports[@]}" "$OPTARG,${temp}" )
                                fi
                                show_ports
                                ;;
                esac
        done
}

pivot_command(){
        while getopts "ht:p:P:" opt; do
                case "$opt" in
                        h|\?)
                                pivot_usage
                                return
                                ;;
                        t)
                                if [ "${#targets[@]}" -eq 0 ] ; then echo "[ERROR] There are no registered targets. Run 'scan -n INT'."; return; fi
                                if ! is_positive_integer "$OPTARG" ; then return; fi
                                if [ "$OPTARG" -gt ${#targets[@]} ] ; then echo "[ERROR] Invalid target number. Enter from 0 to $((${#targets[@]}-1))"; return; fi
                                pivotTarget=$(echo ${targets[$OPTARG]} | awk -F, '{print $2}')
                                ;;
                        p)
                                remotePort=$OPTARG
                                ;;
                        P)
                                localPort=$OPTARG
                                ;;
                esac
        done
        shift $((OPTIND -1))
        if [ -z "$pivotTarget" ] || [ -z "$remotePort" ] || [ -z "$localPort" ]; then
                echo "[ERROR] Mandatory opts: -t -p -P"
                return
        else
                bash -c "rm -f fifo;mkfifo fifo;nc -l -p \"$localPort\" <fifo | nc \"$pivotTarget\" \"$remotePort\" >fifo" &
                sleep 2
                tunnels=( "${tunnels[@]}" "PID: $! -> $localPort:$pivotTarget:$remotePort" )
                echo "[*] Tunnel created, check port $localPort"
        fi
}

show_command(){
        while getopts "hntpT" opt; do
                case "$opt" in
                        h)
                                show_usage
                                return
                                ;;
                        n)
                                show_nets
                                ;;
                        t)
                                show_targets
                                ;;
                        p)
                                show_ports
                                ;;
                        T)
                                show_tunnels
                                ;;
                esac
        done
}

exec_command() {
        while getopts "h" opt; do
                case "$opt" in
                        h) # help
                                exec_usage
                                return
                                ;;
                esac
        done
        echo "[*] Executing shell command: ${1}"
        bash -c "${1}"
}

report_command() {
        while getopts "h" opt; do
                case "$opt" in
                        h) # help
                                report_usage
                                return
                                ;;
                esac
        done
        indexNet=0
        date >> report.pt
        for net in "${nets[@]}"
        do
                echo $net
                indexTarget=0
                for target in "${targets[@]}"
                do
                        actualNet=$(echo $target | awk -F, '{print $1}')
                        if [ "$indexNet" -eq "$actualNet" ] ; then
                                echo -ne '\t';echo ${targets[$indexTarget]} | awk -F, '{print $2}'
                                for line in "${ports[@]}"
                                do
                                        actualTarget=$(echo $line | awk -F, '{print $1}')
                                        if [ "$actualTarget" -eq "$indexTarget" ] ; then
                                                echo -ne '\t\t';echo $line| awk -F, '{print $2}'
                                        fi
                                done
                        fi
                        ((indexTarget=indexTarget+1))
                done
                ((indexNet=indexNet+1))
        done >> report.pt
        cat report.pt
}

# main -------------------------------------------------------------------------
banner
cd /tmp
while true
do
        read -e -p "$PROMPT " line
        history -s "$line"
        cmd=$(echo -e "$line \c" | cut -d ' ' -f1)
        args=$(echo -e "$line \c" | cut -d' ' -f2-)
        case "$cmd" in
                get)
                        get_command $(echo "$args")
                        ;;
                scan)
                        scan_command $(echo "$args")
                        ;;
                pivot)
                        pivot_command $(echo "$args")
                        ;;
                show)
                        show_command $(echo "$args")
                        ;;
                exec)
                        exec_command "$args"
                        ;;
                clear)
                        clear
                        ;;
                report)
                        report_command
                        ;;
                exit)
                        break
                        ;;
                help|*)
                        usage
                        ;;
        esac
        unset OPTIND
done

house_cleaning
