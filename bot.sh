#!/bin/bash
source ShellBot.sh
. variaveis.sh

apiurl="https://api.telegram.org/bot$TOKEN"
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

read offset username command <<< $(curl -s  -X GET "$apiurl/getUpdates"  |\
jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"' |\
tail -1)

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
		. variaveis.sh
		for comando in $(curl -s  -X POST --data "offset=$((offset+1))" "$apiurl/getUpdates" |\
		jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"'|\
		sed 's/ /_/g'); do
			read offset username command <<< $(echo $comando | sed 's/_/ /g')
			shopt -s extglob
			grep -Eoq "$USUARIOS" <<< "$username" && {
				grep -Eoq "^/[lb]tcm[ai][xn] [0-9]+$|^/help$|^/parametros$|^/intervalo [0-9]+(\.[0-9])?$" <<< "$command" && {
					source variaveis.sh
					[ "$command" != "$last" ] && {
						echo $offset - $command - $last >> comandos.log
						case $command in 
							/ltcmax*) (( ${command/* /} != $LTCMAX )) && {
								envia "@${username}, setando *LTCMAX* para ${command/* /}";
								atualizavar LTCMAX ${command/* /}; atualizavar last "$command"; 
							};;
							/ltcmin*) (( ${command/* /} != $LTCMIN )) && {
								envia "@${username}, setando *LTCMIN* para ${command/* /}";
								atualizavar LTCMIN ${command/* /};
								atualizavar last "$command"; 
							};;
							/btcmax*) (( ${command/* /} != $BTCMAX )) && {
								envia "@${username}, setando *BTCMAX* para ${command/* /}";
								atualizavar BTCMAX ${command/* /};
								atualizavar last "$command";
							};;
							/btcmin*) (( ${command/* /} != $BTCMIN )) && {
								envia "@${username}, setando *BTCMIN* para ${command/* /}";
								atualizavar BTCMIN ${command/* /};
								atualizavar last "$command";
							};;
							/intervalo*) [ "${command/* /}" != "$INTERVALO" ] && {
								envia "@${username}, setando *intervalo* para ${command/* /} minutos";
								atualizavar INTERVALO ${command/* /};
								atualizavar last "$command";
							};;
							/parametros) parametros $username; atualizavar last "$command";;
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
	read foxbitsell foxbithigh foxbitlow <<< $(curl -s "https://api.blinktrade.com/api/v1/BRL/ticker?crypto_currency=BTC" |\
	jq -r '"\(.sell) \(.high) \(.low)"')
	dolarbb=$(wget -qO- https://internacional.bb.com.br/displayRatesBR.bb | grep -iEA1 "real.*Dólar" | tail -1 |\
	grep -Eo "[0-9]\.[0-9]+")
	xapo=$(printf "%0.2f" $(wget -qO- https://api.xapo.com/v3/quotes/BTCUSD | jq '.fx_etoe.BTCUSD.destination_amt'))
	dolar2000=$(echo "scale=4; ${dolarbb:-0}*1.0844" | bc)
	dolar3000=$(echo "scale=4; ${dolarbb:-0}*1.0664" | bc)
	dolar4000=$(echo "scale=4; ${dolarbb:-0}*1.0574" | bc)
	read btc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read ltc ltchigh ltclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker_litecoin |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read bitcambiobuy bitcambiosell <<< $(printf "%0.2f " $(curl -s https://api.bitcambio.com.br/api/cotacao |\
	jq -r '"\(.comprepor) \(.vendapor)"'))
	(( ${foxbitsell/.*/} >= ${btc/.*/} )) && {
		maior=FoxBit
		menor=MercadoBTC
		diff=$(echo "scale=3; (($foxbitsell/$btc)-1)*100" | bc | grep -Eo "[0-9]{1,}\.[0-9]")
	} || { 
		maior=MercadoBTC
		menor=FoxBit
		diff=$(echo "scale=3; (($btc/$foxbitsell)-1)*100" | bc | grep -Eo "[0-9]{1,}\.[0-9]")
	}

	msg="*Bitcoin: *
MercadoBTC: R\$ $btc
(*>* $btchigh / *<* $btclow) Var: $(echo "scale=5; ($btchigh/$btclow-1)*100"|bc|\
grep -Eo "[0-9]*\.[0-9]{2}")%
FoxBit: R\$ $foxbitsell
(*>* $foxbithigh / *<* $foxbitlow) Var: $(echo "scale=4; ($foxbithigh/$foxbitlow-1)*100"|bc|\
grep -Eo "[0-9]*\.[0-9]{2}")%

BitCambio: R\$ $bitcambiosell

*( Diferença: $maior ${diff:-0}% mais caro que $menor )*

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
(*>* $ltchigh / *<* $ltclow) Var: $(echo "scale=4; ($ltchigh/$ltclow-1)*100"|bc|\
grep -Eo "[0-9]*\.[0-9]{2}")%
"
	(( ${#msg} > 2 )) && { 
		ShellBot.sendMessage --parse_mode markdown --chat_id $CHATID --text "$msg"
	}
	[ -s $(date "+%Y%m%d").dat ] && {
		[ -s $(date "+%Y%m%d" --date="1 day ago").dat ] && rm $(date "+%Y%m%d" --date="1 day ago").dat
		maior=$(cat $(date "+%Y%m%d").dat | grep -Eo "[0-9]{3,}"| sort -n | tail -1)
		menor=$(cat $(date "+%Y%m%d").dat | grep -Eo "[0-9]{3,}"| sort -n | head -1)
		sed -i "s/set yrange.*/set yrange [ $((${menor/.*/}-100)):$((100+${maior/.*/}))]/g" geraimagem.pb
		gnuplot -c geraimagem.pb $(date "+%Y%m%d").dat > out.png
		curl -s -X POST "$apiurl/sendPhoto" -F chat_id=$CHATID -F photo=@out.png >/dev/null
	}
}

mensagem

alerta(){
	valorhigh=$1
	valormin=$2
	valoraferido=$3
	exchangemax=$4
	exchangemin=$5
	exchange=$6
	(( ${valoraferido/.*/} > ${valorhigh} )) ||\
	(( ${valoraferido/.*/} < ${valormin} )) && {
		msg+="*${exchange}:* R\$ $valoraferido
"
		(( exchangemax > 0 )) && {
			msg+="(*Max* R\$ $exchangemax / *Min* R\$ $exchangemin)
Δ% na $exchange: $(echo "scale=4; ($exchangemax/$exchangemin-1)*100"|bc|grep -Eo "[0-9]*\.[0-9]{2}")% 
"
		}
	}
}

while : 
do
	source variaveis.sh
	let ct+=1
	(( ct % 12 == 0 )) && { mensagem; sed -i "s/last=.*/last=oe/g" variaveis.sh ; }
	sleep ${INTERVALO}m
	msg=
	
	xapo=$(printf "%0.2f " $(wget -qO- https://api.xapo.com/v3/quotes/BTCUSD |\
	jq '.fx_etoe.BTCUSD.destination_amt'))
	read btc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read ltc ltchigh ltclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker_litecoin |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read foxbitsell foxbithigh foxbitlow <<< $(curl -s "https://api.blinktrade.com/api/v1/BRL/ticker?crypto_currency=BTC" |\
	jq -r '"\(.sell) \(.high) \(.low)"')
	(( ${foxbitsell/.*/} >= ${btc/.*/} )) && {
		maior=FoxBit
		menor=MercadoBTC
		diff=$(echo "scale=3; (($foxbitsell/$btc)-1)*100" | bc | grep -Eo "[0-9]{1,}\.[0-9]")
	} || { 
		maior=MercadoBTC
		menor=FoxBit
		diff=$(echo "scale=3; (($btc/$foxbitsell)-1)*100" | bc | grep -Eo "[0-9]{1,}\.[0-9]")
	}
	alerta $BTCMAX $BTCMIN $btc $btchigh $btcmin MercadoBitcoin
	alerta $BTCMAX $BTCMIN $foxbitsell $foxbithigh $foxbitlow FoxBit
	alerta $BTCMAX $BTCMIN $bitcambiosell 0 0 BitCambio
	alerta $LTCMAX $LTCMIN $ltc $ltchigh $ltclow "MercadoBitcoin(Litecoin)"

	rate=$(echo "scale=2; $btc/$xapo" |bc)
	rate=${rate:-3}
	(( ${rate/.*/} >= 4 )) && {
		msg+="
*MercadoBTC/Xapo:* $rate ($btc/$xapo)"
	}
	diff=${diff:-0}
	(( ${diff/.*} >= 4 )) && {
		msg+="
*$maior ${diff}% mais caro que $menor*
*FoxBit:* R\$ $foxbitsell
*MercadoBitcoin:* R\$ $btc"
	}
	echo "$msg"
	(( ${#msg} > 2 )) && {
		ShellBot.sendMessage --parse_mode markdown --chat_id $CHATID --text "$msg"
	}
	[ ! -s $(date "+%Y%m%d").dat ] && echo "##hora valor" > $(date "+%Y%m%d").dat
	echo "$(date "+%H:%M:%S") ${btc/.*/} ${foxbitsell/.*/} ${bitcambiosell/.*/}" >> $(date "+%Y%m%d").dat
done

