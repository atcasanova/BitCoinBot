#!/bin/bash
source ShellBot.sh
. variaveis.sh

foxbiturl="https://api.blinktrade.com/api/v1/BRL/ticker?crypto_currency=BTC"
bitcambiourl="https://api.bitcambio.com.br/api/cotacao"
apiurl="https://api.telegram.org/bot$TOKEN"
mbtc=https://www.mercadobitcoin.net/api
ct=0
ShellBot.init --token $TOKEN
parametros() {
	source variaveis.sh
	ShellBot.sendMessage --parse_mode markdown --chat_id $CHATID --text "@${1}, Parâmetros:
BTC: > $BTCMAX e < $BTCMIN
LTC: > $LTCMAX e < $LTCMIN
CHECAGEM A CADA $INTERVALO minutos
ALERTA SE DIFERENÇA MAIOR QUE $PORCENTAGEM %
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
*/porcentagem 4*
*/parametros*
*/cotacoes*"
}

read offset username command <<< $(curl -s  -X GET "$apiurl/getUpdates"  |\
jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"' |\
tail -1)

export offset
export command

mensagem (){
	source variaveis.sh
	read foxbitsell foxbithigh foxbitlow <<< $(curl -s "$foxbiturl" |\
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
	read bitcambiobuy bitcambiosell <<< $(printf "%0.2f " $(curl -s "$bitcambiourl" |\
	jq -r '"\(.comprepor) \(.vendapor)"'))
	read maior lixo menor <<< $(echo "${foxbitsell/.*/},Foxbit
${btc/.*/},MercadoBitCoin
${bitcambiosell/.*/},BitCambio" | sort -nrk1 -t, | tr '\n' ' ')
	IFS=, read maiorvlr maiorexchange <<< $maior
	IFS=, read menorvlr menorexchange <<< $menor
	diff=$(echo "scale=3; (($maiorvlr/$menorvlr)-1)*100" | bc | grep -Eo "[0-9]{1,}\.[0-9]")
	msg="*Bitcoin: *
*MercadoBTC:* R\$ $btc
(*>* $btchigh / *<* $btclow) Var: $(echo "scale=5; ($btchigh/$btclow-1)*100"|bc|\
grep -Eo "[0-9]*\.[0-9]{2}")%
*FoxBit:* R\$ $foxbitsell
(*>* $foxbithigh / *<* $foxbitlow) Var: $(echo "scale=4; ($foxbithigh/$foxbitlow-1)*100"|bc|\
grep -Eo "[0-9]*\.[0-9]{2}")%
*BitCambio:* R\$ $bitcambiosell

*( Diferença: $maiorexchange ${diff:-0}% mais caro que $menorexchange )*

*Xapo:* USD $xapo

*Custo Dolar BB -> Xapo*: 
*USD 2000*: $dolar2000
*USD 3000*: $dolar3000
*USD 4000*: $dolar4000
"
	rate=$(echo "scale=2; $maiorvlr/$xapo" |bc)
	msg+="
*$maiorexchange/Xapo:* $rate
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
	(( $# == 6 )) && {
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
			(( ${exchangemax/.*/} > 0 )) && {
				msg+="(*Max* R\$ $exchangemax / *Min* R\$ $exchangemin)
	Δ% na $exchange: $(echo "scale=4; ($exchangemax/$exchangemin-1)*100"|bc|grep -Eo "[0-9]*\.[0-9]{2}")% 
	"
			}
		}
	}
}

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
				grep -Eoq "^/cotacoes$|^/[lb]tcm[ai][xn] [0-9]+$|^/help$|^/parametros$|^/intervalo [0-9]+(\.[0-9])?$|^/porcentagem [0-9]{1,2}$" <<< "$command" && {
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
							/porcentagem*) [ "${command/* /}" != "$PORCENTAGEM" ] && {
								envia "@${username}, setando *porcentagem* para ${command/* /}%";
								atualizavar PORCENTAGEM ${command/* /};
								atualizavar last "$command";
							};;
							/cotacoes) mensagem; atualizavar last "$command";;
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
	read bitcambiobuy bitcambiosell <<< $(printf "%0.2f " $(curl -s "$bitcambiourl" |\
	jq -r '"\(.comprepor) \(.vendapor)"'))
	read maior lixo menor <<< $(echo "${foxbitsell/.*/},Foxbit
${btc/.*/},MercadoBitCoin
${bitcambiosell/.*/},BitCambio" | sort -nrk1 -t, | tr '\n' ' ')
	IFS=, read maiorvlr maiorexchange <<< $maior
	IFS=, read menorvlr menorexchange <<< $menor
	diff=$(echo "scale=3; (($maiorvlr/$menorvlr)-1)*100" | bc | grep -Eo "[0-9]{1,}\.[0-9]")
	
	alerta ${BTCMAX:-0} ${BTCMIN:-0} ${btc:-0} ${btchigh:-0} ${btcmin:-0} MercadoBitcoin
	alerta ${BTCMAX:-0} ${BTCMIN:-0} ${foxbitsell:-0} ${foxbithigh:-0} ${foxbitlow:-0} FoxBit
	alerta ${BTCMAX:-0} ${BTCMIN:-0} ${bitcambiosell:-0} 0 0 BitCambio
	alerta ${LTCMAX:-0} ${LTCMIN:-0} ${ltc:-0} ${ltchigh:-0} ${ltclow:-0} "MercadoBitcoin(Litecoin)"

	rate=$(echo "scale=2; $maiorvlr/$xapo" |bc)
	rate=${rate:-3}
	(( ${rate/.*/} >= ${PORCENTAGEM} )) && {
		msg+="
*$maiorexchange/Xapo:* $rate ($btc/$xapo)"
	}
	diff=${diff:-0}
	(( ${diff/.*} >= ${PORCENTAGEM} )) && {
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

