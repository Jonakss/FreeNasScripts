#!/bin/bash

source "./helpers.sh"

## Parameters
# -n Name of file
# -l location of backup
# -s source
# 
#
# -r Restore Backup

## Variables
log="/var/log/backup.log"
snap="/etc/backup.snap"
d=`date +%d-%m-%Y`
n="DIF"
l="/mnt/USB/"
s="/mnt/Data/"

f=$n"_"$d"_"
ctail=full.tar.gz
itail=inc.tar.gz
dtail=dif.tar.gz

backup_days=15 # Default 15 dias

## Archivo de configuracion
# backup.rc
function checkConfigurationFile {
[[ -d "$1" ]] || (writeLog "No se encuentra el archivo de configuracion ("$l") o hay permiso de lectura" d; exit -1)
}

function loadConfiguration {
	checkConfigurationFile $1
	writeLog "Cargado informacion desde $1"
}
	
args=("$@")
i=0

function checkLocation {
[[ -d $l ]] || (writeLog "No se encuentra el destino del respaldo ("$l") o no se puede escribir ahi" d; exit -1)
}

function checkSource {
[[ -d $s ]] || (writeLog "No se encuentra el origuen de respaldo ("$s") o no se puede escribir ahi" d; exit -1)
}

fucntion backup_error {
	writeLog "$(cat $1)" d
	writeLog "Error al realizar respaldo $2" d
	sendMail "Error al realizar respaldo $2" "jona.digitaldata@gmail.com" "		
Origen: $s
Destino: $l$f
Tipo de respaldo: $2
	
Ultimas 20 lineas de log ($log):

$(cat $log | tail -20)

		"
		[ -o $snap ] && rm $snap
}

function doCompleteBackup {
	checkSource
	checkLocation

	writeLog "Iniciando respaldo completo"
	
	cd $l
	local f=$f$ctail
	TEMP=`mktemp`
	[ -f $snap ] && rm $snap	
	gtar -czpf $f $s -g $snap --exclude='*jails*' &>$TEMP
	if [ $? = 0 ]; then
		writeLog "Respaldo completo realizado correctamente $f -> $s"
	elif [ $? = 1 ]; then
		writeLog "$(cat $TEMP)" w
	else
		backup_error $TEMP "completo"
		exit -1
	fi
}

function incrementalBackup {
	writeLog "Iniciando respaldo incremental"
	cd $l

	local TEMP=`mktemp`
	gtar -czpf $f $s -g $snap --exclude='*jails*' &>$TEMP
	if [ $? = 0 ]; then
		writeLog "Respaldo incremetal realizado correctamente $f -> $s"
	elif [ $? = 1 ]; then
		writeLog "$(cat $TEMP)" w
	else
		backup_error $TEMP "incremental"
		exit -1
	fi

	echo Respaldo Incremental $s" > "$l$f
	writeLog "Respaldo incremetal realizado correctamente"
}

function doIncrementalBackup {
	checkSource
	checkLocation
	
	if [ -f $snap ]; then
		incrementalBackup
		cp $snap $l"backup_"$d".snap"
	else
		writeLog "No se encuentra $snap para realizar respaldo incremental. Pasando a  respaldo 
completo"
		doCompleteBackup
	fi
}

function doDiferencialBackup {
	checkSource
	checkLocation

	cd $l
	gtar -cpzf $f $s -g ./backup.snap

	echo Respaldo diferencial $s" > "$l$f
	writeLog "Respaldo diferencial realizado correctamente"
}

while [[ $i -lt $# ]]
do
	case ${args[$i]} in
		"-c") loadConfiguration "${args[((i+1))]}";;
		"-s") s="${args[((i+1))]}";;
		"-t") t="${args[((i+1))]}";;
		"-l") l="${args[((i+1))]}";;
	esac
	
i=$((i+1))
done

LS=`mktemp`
LS="$(ls $l$n* 2>/dev/null)"
if [ $? -eq 0 ]; then
	for ff in $LS
	do
		
		now=$(date +%s)
		bdis=$(($backup_days*60*60*24))
		ld=$(($now - ($bdis)))
	
		dd=$(echo $ff | cut -d "_" -f 2 | cut -d "-" -f 1) 
		mm=$(echo $ff | cut -d "_" -f 2 | cut -d "-" -f 2)
		yy=$(echo $ff | cut -d "_" -f 2 | cut -d "-" -f 3)		
		bdate=`date -j -f "%d%m%y" "$dd$mm$yy" +%s`	

		[ $bdate -lt $ld ] && (rm $ff; writeLog "Respaldo eliminado: $ff - Tiempo exedido $backup_days dias"; [ -f $l"backup_"$dd-$mm-$yy".snap" ] && rm $l"backup_"$dd-$mm-$yy".snap")
	done	
fi

case $t in
	"i") doIncrementalBackup;;	
	"d") doDiferencialBackup;;	
	"c" | "f" | *) doCompleteBackup;;
esac

unset d
unset s
unset n
unset l
unset i
unset f
unset ld
unset itail
unset ctail
unset dtail
unset log
unset snap
unset args
unset TEMP

exit 0
