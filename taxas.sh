#!/bin/bash
deposito(){
	exchange=${1,,}
	valor=$2
	case $exchange in
		mbtc) taxa=$(echo "scale=4; ($valor+2.90)/0.9801" | bc );;
		foxbit) taxa=$valor
	esac
	printf '%0.2f\n' $taxa
}

saque(){
	exchange=${1,,}
	valor=$2
	case $exchange in
		mbtc) taxa=$(echo "scale=4; $valor*0.9801-2.90" | bc );;
		foxbit) taxa=$(echo "scale=4; $valor*(1-.0139)" | bc);;
	esac
	printf '%0.2f\n' $taxa
}

transferencia(){
	exchange=${1,,}
	valor=$2
	case $exchange in
		mbtc) taxa=$(echo "scale=8; $valor-0.00030510" | bc);;
		foxbit) taxa=$(echo "scale=8; $valor-0.0004500" | bc);;
	esac
	printf '%0.8f\n' $taxa
}

