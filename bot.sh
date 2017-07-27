#!/bin/bash
# O funcionamento desse bot depende da ShellBot API
# Disponível em https://github.com/shellscriptx/ShellBot

source ShellBot.sh

. variaveis.sh

TOKEN=_SEU_TOKEN_
apiurl="https://api.telegram.org/bot$TOKEN"
CHATID=ChatID
mbtc=https://www.mercadobitcoin.net/api
ct=0
ShellBot.init --token $TOKEN
parametros() {
	source variaveis.sh
	ShellBot.sendMessage --parse_mode markdown --chat_id $CHATID --text "@${1}, Parâmetros:
BTC: > $BTCMAX e < $BTCMIN
LTC: > $LTCMAX e < $LTCMIN
INTERVALO DE CHECAGEM: $INTERVALO minutos
"
}
parametros

ajuda() {
	ShellBot.sendMessage --parse_mode markdown --chat_id $CHATID --text "@${1}, Comandos aceitos:
*/ltcmax 170*
*/ltcmin 110*
*/btcmax 9500*
*/btcmin 8000*
*/intervalo 5*
*/parametros*"
}

read offset username command <<< $(curl -s  -X GET "$apiurl/getUpdates"  | jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"' | tail -1)

export offset
export command

commandlistener(){
	atualizavar() {
		sed -i "s-$1.*-$1=\"$2\"-g" variaveis.sh
	}
	envia(){
		ShellBot.sendMessage --parse_mode markdown --chat_id $CHATID --text "$1"
	}
	last=oe
	while : ; do
		for comando in $(curl -s  -X POST --data "offset=$((offset+1))" "$apiurl/getUpdates"  | jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"'| sed 's/ /_/g'); do
			read offset username command <<< $(echo $comando | sed 's/_/ /g')
			shopt -s extglob
			# Preencher o Grep baixo com os usuarios autorizados a dar comandos separados por pipe
			grep -Eoq "usuarios|autorizados|a|dar|comandos" <<< "$username" && {
				grep -Eoq "^/[lb]tcm[ai][xn] [0-9]+$|^/help$|^/parametros$|^/intervalo [0-9]+(\.[0-9])?$" <<< "$command" && {
					source variaveis.sh
					[ "$command" != "$last" ] && {
						echo $offset - $command - $last >> comandos.log
						case $command in 
							/ltcmax*) (( ${command/* /} != $LTCMAX )) && { envia "@${username}, setando *LTCMAX* para ${command/* /}"; atualizavar LTCMAX ${command/* /}; atualizavar last "$command"; };;
							/ltcmin*) (( ${command/* /} != $LTCMIN )) && { envia "@${username}, setando *LTCMIN* para ${command/* /}"; atualizavar LTCMIN ${command/* /}; atualizavar last "$command"; };;
							/btcmax*) (( ${command/* /} != $BTCMAX )) && { envia "@${username}, setando *BTCMAX* para ${command/* /}"; atualizavar BTCMAX ${command/* /}; atualizavar last "$command"; };;
							/btcmin*) (( ${command/* /} != $BTCMIN )) && { envia "@${username}, setando *BTCMIN* para ${command/* /}"; atualizavar BTCMIN ${command/* /}; atualizavar last "$command"; };;
							/intervalo*) [ "${command/* /}" != "$INTERVALO" ] && { envia "@${username}, setando *intervalo* para ${command/* /} minutos"; atualizavar INTERVALO ${command/* /}; atualizavar last "$command"; };;
							/parametros) parametros $username;  atualizavar last "$command";;
							/help) ajuda $username; atualizavar last "$command";;
						esac
					}
				}
			}
		done
	sleep 10s
	done
}

commandlistener &

mensagem (){
	source variaveis.sh
	dolarbb=$(wget -qO- https://internacional.bb.com.br/displayRatesBR.bb | grep -iEA1 "real.*Dólar" | tail -1 | grep -Eo "[0-9]\.[0-9]+")
	xapo=$(printf "%0.2f" $(wget -qO- https://api.xapo.com/v3/quotes/BTCUSD | jq '.fx_etoe.BTCUSD.destination_amt'))
	dolar2000=$(echo "scale=4; $dolarbb*1.0844" | bc)
	dolar3000=$(echo "scale=4; $dolarbb*1.0664" | bc)
	dolar4000=$(echo "scale=4; $dolarbb*1.0574" | bc)
	read btc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker | jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read ltc ltchigh ltclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker_litecoin | jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	msg="*Bitcoin: *R\$ $btc
(*>* $btchigh / *<* $btclow) Var: $(echo "scale=5; ($btchigh/$btclow-1)*100"|bc|grep -Eo "[0-9]*\.[0-9]{2}")%

*Xapo:* USD $xapo

*Custo Dolar BB -> Xapo*: 
*USD 2000*: $dolar2000
*USD 3000*: $dolar3000
*USD 4000*: $dolar4000
"
	rate=$(echo "scale=2; $btc/$xapo" |bc)
	msg+="
*MercadoBTC/Xapo:* $rate
"
	msg+="
*Litecoin:* R\$ $ltc
(*>* $ltchigh / *<* $ltclow) Var: $(echo "scale=4; ($ltchigh/$ltclow-1)*100"|bc| grep -Eo "[0-9]*\.[0-9]{2}")%
"
	(( ${#msg} > 2 )) && ShellBot.sendMessage --parse_mode markdown --chat_id $CHATID --text "$msg"
	[ -s $(date "+%Y%m%d").dat ] && {
		rm $(date +"%Y%m%d" --date="1 day ago").dat
		sed -i "s/set yrange.*/set yrange [${btclow/.*/}:${btchigh/.*/}]/g" geraimagem.pb
	  gnuplot -c geraimagem.pb 20170727.dat > out.png
		curl -s -X POST "$apiurl/sendPhoto" -F chat_id=$CHATID -F photo=@out.png
	}
}

mensagem

lastltc=0
lastbtc=0

while : 
do
	source variaveis.sh
	let ct+=1
	(( ct % 12 == 0 )) && { mensagem; sed -i "s/last=.*/last=oe/g" variaveis.sh ; }
	sleep ${INTERVALO}m
	msg=
	
	xapo=$(printf "%0.2f " $(wget -qO- https://api.xapo.com/v3/quotes/BTCUSD | jq '.fx_etoe.BTCUSD.destination_amt'))
	read btc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker | jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read ltc ltchigh ltclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker_litecoin | jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	(( ${btc/.*/} > $BTCMAX )) || (( ${btc/.*/} < $BTCMIN )) && {
		((${btc/.*/} != $lastbtc )) && msg="*Bitcoin:* R\$ $btc
(*>* $btchigh / *<* $btclow) Var: $(echo "scale=4; ($btchigh/$btclow-1)*100"|bc| grep -Eo "[0-9]*\.[0-9]{2}")%" 
	} 
	rate=$(echo "scale=2; $btc/$xapo" |bc)
	(( ${rate/.*/} >= 4 )) && {
		msg+="
*MercadoBTC/Xapo:* $rate ($btc/$xapo)"
	}
	(( ${ltc/.*/} > $LTCMAX )) || (( ${ltc/.*/} < $LTCMIN )) && {
		(( ${ltc/.*/} != $lastltc )) && msg+="
*Litecoin:* R\$ $ltc
(*>* $ltchigh / *<* $ltclow) Var: $(echo "scale=4; ($btchigh/$btclow-1)*100"|bc| grep -Eo "[0-9]*\.[0-9]{2}")%"
	} 
	lastbtc=${btc/.*/}
	lastltc=${ltc/.*/}
	(( ${#msg} > 2 )) && ShellBot.sendMessage --parse_mode markdown --chat_id $CHATID --text "$msg"
	[ ! -s $(date "+%Y%m%d").dat ] && echo "##hora valor" > $(date "+%Y%m%d").dat
	echo "$(date "+%H:%M:%S") ${btc/.*/}" >> $(date "+%Y%m%d").dat
done
	

