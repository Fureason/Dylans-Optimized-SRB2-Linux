#!/bin/bash













DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"






dirlevel=0  
dirtails=()


makedirtailname () {
	dirtailname=""
	for tail in $dirtails; do
		if [[ "$dirtailname" == "" ]]; then
			dirtailname="/$tail";
		else
			dirtailname="$dirtailname/$tail";
		fi;
	done;
}

evaldirectory () {
	if [ -d "$1" ]; then


		if (( $dirlevel > 0 )); then
			dirtails+=( "$(basename $1)" );
		else
			dirtails=();
		fi;
		dirlevel=$((dirlevel+1));


		makedirtailname;



		if (( $dirlevel > 1 )) && [[ "$3" != "" ]]; then
			eval "$3";
		fi;


		for name in $1/*; do
			if [ -d "$name" ]; then


				evaldirectory "$name" "$2" "$3";


				unset 'dirtails[ ${#dirtails[@]}-1 ]';
				dirlevel=$((dirlevel-1));
				makedirtailname;
			else

				if [ -f "$name" ] && [[ "$2" != "" ]]; then
					eval "$2";
				fi;
			fi;
		done;


		if (( $dirlevel == 1 )); then
			dirlevel=0;
		fi;
	fi;
}




if [[ "$__DEBIAN_PARAMETERS_INITIALIZED" != "1" ]]; then
	. ${DIR}/deployer/travis/deployer_defaults.sh;
fi;



__DEBIAN_PARAMETERS_INITIALIZED=0


export __PACKAGE_DATETIME="$(date '+%a, %d %b %Y %H:%M:%S %z')"
export __PACKAGE_DATETIME_DIGIT="$(date -u '+%Y%m%d%H%M%S')"

if [[ "$PACKAGE_REVISION" == "" ]]; then
	PACKAGE_REVISION="-$__PACKAGE_DATETIME_DIGIT";
	__PACKAGE_REVISION_BY_DATE=1;
	export PACKAGE_REVISION=${PACKAGE_REVISION};  
fi;




if [[ "$1" == "clean" ]]; then
	toclean=$2;
else
	toclean=$1;
fi;

if [[ "$toclean" == "" ]] || [[ "$toclean" == "main" ]]; then
	echo "Cleaning main package scripts";
	if [[ ! -f ${DIR}/debian ]]; then
		rm -rf ${DIR}/debian;
	fi;
fi;
if [[ "$toclean" == "" ]] || [[ "$toclean" == "asset" ]]; then
	echo "Cleaning asset package scripts";
	if [[ ! -f ${DIR}/assets/debian ]]; then
		rm -rf ${DIR}/assets/debian;
	fi;
fi;




if [[ "$1" != "clean" ]]; then
	totemplate=$1;



	export SHLIBS_DEPENDS=${SHLIBS_DEPENDS};
	export MISC_DEPENDS=${MISC_DEPENDS};
	export DEBFILEVAR='$$file';  



	if [[ "$totemplate" == "" ]] || [[ "$totemplate" == "main" ]]; then
		echo "Generating main package scripts";
		fromroot=${DIR}/debian-template;
		toroot=${DIR}/debian;
		mkdir ${toroot};

		evaldirectory ${fromroot} \
			"cat \$name | envsubst > ${toroot}\${dirtailname}/\$( basename \$name )" \
			"mkdir \"${toroot}\${dirtailname}\"";
	fi;

	if [[ "$totemplate" == "" ]] || [[ "$totemplate" == "asset" ]]; then
		echo "Generating asset package scripts";
		fromroot=${DIR}/assets/debian-template;
		toroot=${DIR}/assets/debian;
		mkdir ${toroot};


		evaldirectory ${fromroot} \
			"cat \$name | envsubst > ${toroot}\${dirtailname}/\$( basename \$name )" \
			"mkdir \"${toroot}\${dirtailname}\"";
	fi;
fi;

if [[ "$__DPL_ACTIVE" != "1" ]] && [[ "$__PACKAGE_REVISION_BY_DATE" == "1" ]]; then
	unset PACKAGE_REVISION;  
fi;
