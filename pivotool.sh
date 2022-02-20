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
				nets=$(ip a | grep "inet " | awk '{print $2}')
				for net in $(echo $nets)
				do
					nets=("${nets[@]}" $net)
				done
				echo $nets
				;;
		    i) # system info
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
				BASE_IP=$(echo $net | awk -F\/ '{print $1}')
				IP_CIDR=$(echo $net | awk -F\/ '{print $2}')
				IP_MASK=$((0xFFFFFFFF << (32 - ${IP_CIDR})))
				IFS=. read a b c d <<<${BASE_IP}
				ip=$((($b << 16) + ($c << 8) + $d))
				ipstart=$((${ip} & ${IP_MASK}))
				ipend=$(((${ipstart} | ~${IP_MASK}) & 0x7FFFFFFF))
				ips=$(seq ${ipstart} ${ipend} | while read i; do
				    echo $a.$((($i & 0xFF0000) >> 16)).$((($i & 0xFF00) >> 8)).$(($i & 0x00FF))
				done)
				for i in $(echo $ips)
				do
					echo ${i}
					ping -c 1 -W 5 ${i} | grep -q "bytes from" && echo "${i} - UP" &
				done; wait
				;;
		    t) # port scan
				for i in $(seq 1 65535)
				do
			        for j in $(echo ips)
			        do
			                timeout 1 bash -c "echo '' > /dev/tcp/$j/$i" 2>/dev/null && echo "HOST $i - PORT $j ACTIVE" &
			        done; wait
				done
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
	while getopts "h" opt; do
		case "$opt" in
			h)
				info_usage
				return
				;;
		esac
	done
	# show info
}

exec_command(){

}

# main -------------------------------------------------------------------------
banner
while true
do
	read -p "Enter Command: " line
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