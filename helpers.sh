#!/bin/bash
function writeLog {
	local logText=""
	case $2 in
		"d") logText="XXX ";
		echo XXX Danger $1 ;;
		"w") logText="!!! ";
			echo !!! Warning $1 ;;
		"" | "*") logText="   " ;;
	esac
	logText="$logText `date`  `whoami`  $1"
#	[ -f $log ] || touch $log
	echo $logText >> $log
}

function sendMail {
	exec &> /dev/null
	mail -s "$1" $2 <<-EOT
	Aviso!: Mensaje autogenerato por servidor de archivos (NAS)

	$3

	EOT
}

export -f sendMail
export -f writeLog