#!/bin/bash
source variaveis.sh
[ ! -s credits ] && { echo vou zerar; for admin in ${ADMINS[@]}; do echo $admin $DAILYCREDITS; done > credits; }

ct=0
curl -s $apiurl/getMe 2>&1 >/dev/null

envia(){
	source variaveis.sh
	curl -s -X POST "$apiurl/sendMessage" \
	-F text="$*" -F parse_mode="markdown" \
	-F chat_id=$CHATID 2>&1 >/dev/null 
}

parametros(){
	local mensagem="Parâmetros:
BTC: > $BTCMAX e < $BTCMIN
LTC: > $LTCMAX e < $LTCMIN
CHECAGEM A CADA $INTERVALO minutos
ALERTA SE DIFERENÇA MAIOR QUE $PORCENTAGEM %
"
	envia "$mensagem"
}

parametros

isAdmin(){
	grep -q $1 <<< "${ADMINS[@]}"
}

isValidCommand(){
	grep -Eoq "$COMANDOS" <<< "$1"
}

getLastDollar(){
	local offset=1;
	local dolar=a;
	while grep -vq "[0-9]" <<< $dolar; do
		dolar=$(curl -s "https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarDia(dataCotacao=@dataCotacao)?@dataCotacao='$(date -d "-$offset days" "+%m-%d-%Y")'&$top=100&$skip=0&$format=json&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao" | jq '.value[].cotacaoCompra');
		let offset++
	done;
	echo $dolar;
}

checkCredits(){
	[ "$1" == "$MASTER" ] && {
		envia "\`\`\`
$(cat credits)
\`\`\`"
	} || {
		envia "Seus Créditos:
\`$(grep "$1 " credits)"\`
	}
}	

getPrice(){
	local pair=$1
	curl -sk "https://api.binance.com/api/v3/ticker/price?symbol=${pair^^}" | jq '.price' -r
}



resetCredits(){
	[ "$1" == "atc1235" ] || { envia "sonha, @$1!"; checkCredits $1; return 1; }
	source variaveis.sh
	for admin in ${ADMINS[@]}; do echo $admin $DAILYCREDITS; done > credits
	
	envia "\`\`\`
$(cat credits)
\`\`\`"
}

formata(){
	LC_ALL=pt_BR.utf-8 numfmt --format "%'0.2f" -- ${1/./,}
}

checkRecord(){
			dono=$1
			teste=$2
			IFS=, read diamesano valorr <<< "$(sort -n -k2 -t, $dono.history  | tail -1)"
			bc <<< "$teste-$valorr" | grep -q "^-" || {
				teste=$(formata $teste)
				envia "Boa, @$dono! Bateu seu recorde historico com R\$ $teste 🎉👏🥳"
			}
}

coin() {
	creditos=$(grep "^$dono " credits | cut -f2 -d " ")
	(( $creditos < 1 )) && { envia "Vc tá consultando demais, @$dono seu arrombado. Utilize o /binance"; return; }
	coin=${1^^}
	(( $# == 2 )) \
		&& qtd=$2 \
		|| qtd=0
	json="$(echo "$(curl -sH "$COINMARKET" -H "Accept: application/json" https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=$coin | jq -r ".data.$coin.quote.USD | \"\(.price) \(.percent_change_1h) \(.percent_change_24h)\"") $(curl -sH "$COINMARKET" -H "Accept: application/json" "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=$coin&convert=BTC" | jq -r ".data.$coin.quote.BTC.price") $coin")"
	local usdt=$(getPrice USDTBRL)
	cotacao=$(getPrice ${coin^^}USDT); 
	local img=$(curl -s https://coinmarketcap.com | grep -Po "font-size=\"1\">${coin^^}.*(?=(alt=\"[0-9]+-price-graph))"| sed 's/price-graph/\n/g'| head -1| grep -Eo "https://.*png")
	(( ${#img} > 5 )) && wget -q "$img" -O ${coin^^}.png
	grep "null" <<< "$json" && envia "${coin^^} não encontrada na coinmarketcap" || {
	read usd change1h change24h btc symbol <<< $json
	grep -q "e" <<< $btc && btc=$(sed 's/e/*10^/' <<< "$btc" | bc -l)
	grep -q "e" <<< $usd && usd=$(sed 's/e/*10^/' <<< "$usd" | bc -l)
	[[ $qtd =~ [^[:digit:]\.] ]] && qtd=0
	[ "$qtd" == "0" ] && { 
		local msg="\`\`\`
Cotação CoinMarketCap para ${symbol^^}:
USD $(formata $usd)
"
		grep -q null <<< $cotacao || msg+="USDT $(formata $cotacao) (Binance)
"
msg+="BTC $btc
24h: $change24h
1h: $change1h
\`\`\`"
} || {
	read mbtc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/btc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	IFS=, read reais maiorexchange <<< ${mbtc/.*/},MercadoBitCoin
	local msg="\`\`\`
${qtd} ${symbol^^} valem:
${symbol^^} $btc (USD $(formata $usd))
USD $(formata $(bc <<< "$usd*$qtd" ))
"
grep -q null <<< $cotacao || msg+="USDT $(formata $cotacao) (Binance)
"
msg+="BRL $(formata $(bc <<< "$qtd*$usdt*$usd"))
BTC $(bc <<< "$btc*$qtd")
24h: $change24h
1h: $change1h
\`\`\`"
}
envia "$msg"
	}
	[ -f ${coin^^}.png ] && {
		convert ${coin^^}.png -resize 250x187 -background white -gravity center -extent 250x187 tmp.png 2>/dev/null
		imagem=$(curl -s -X POST "$apiurl/sendPhoto" -F chat_id=$CHATID -F photo=@tmp.png |\
	        jq -r '.result.photo[] | .file_id' | tail -1)
		rm -f tmp.png ${coin^^}.png
	} 
	let creditos--
	sed -i "s/$dono .*/$dono $creditos/g" credits
}

ajuda(){
	local mensagem="Comandos aceitos:
*/ltcmax 170*
*/ltcmin 110*
*/btcmax 9500*
*/btcmin 8000*
*/intervalo 5*
*/porcentagem 4.01*
*/parametros*
*/cotacoes*
*/coin moeda*
*/coin moeda 1.3*
*/adiciona moeda 30.3*
*/remove moeda*
*/consulta*
*/evolucao*
"
	envia "$mensagem"
}

read offset username command <<< $(curl -s  -X GET "$apiurl/getUpdates"  |\
jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"' |\
tail -1)

export offset
export command

mensagem (){
	source variaveis.sh
	dolarbb=$(curl -s "https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarDia(dataCotacao=@dataCotacao)?@dataCotacao='$(date -d "yesterday" "+%m-%d-%Y")'&$top=100&$skip=0&$format=json&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao"|jq '.value[].cotacaoCompra')
	xapo=$(printf "%0.2f" $(curl -sH "$COINMARKET" -H "Accept: application/json" "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=BTC" | jq -r ".data.BTC.quote.USD.price"))
	read btc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/btc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read ltc ltchigh ltclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ltc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read maior menor <<< "${btc/.*/},MercadoBitCoin ${btc/.*/},MercadoBitCoin"
	IFS=, read maiorvlr maiorexchange <<< $maior
	IFS=, read menorvlr menorexchange <<< $menor
	diff=$(bc <<< "scale=3; (($maiorvlr/$menorvlr)-1)*100" | grep -Eo "[0-9]{1,}\.[0-9]")
	msg="*Bitcoin: *
*MercadoBTC:* R\$ $btc
(*>* $btchigh / *<* $btclow) Var: $(bc <<< "scale=5; ($btchigh/$btclow-1)*100"|\
grep -Eo "[0-9]*\.[0-9]{2}")%

*BTCUSD:* USD $xapo
"
	rate=$(bc <<< "scale=2; $maiorvlr/$xapo")
	msg+="
*${maiorexchange:-MercadoBitCoin}/BTCUSD:* $rate
"
	(( ${#msg} > 2 )) && { 
		envia "$msg"
	}
	[ -s $(date "+%Y%m%d").dat ] && {
		[ -s $(date "+%Y%m%d" --date="1 day ago").dat ] \
		&& cat $(date "+%Y%m%d" --date="1 day ago").dat >> /historico.dat
		maior=$(grep -Eo "[0-9]{3,}" $(date "+%Y%m%d").dat | sort -n | tail -1)
		menor=$(grep -Eo "[0-9]{3,}" $(date "+%Y%m%d").dat | sort -n | head -1)
		sed -i "s/set yrange.*/set yrange [ $((${menor/.*/}*95/100)):$((${maior/.*/}*105/100))]/g" geraimagem.pb
		gnuplot -c geraimagem.pb $(date "+%Y%m%d").dat > btc.png
		idphoto=$(curl -s -X POST "$apiurl/sendPhoto" -F chat_id=$CHATID -F photo=@btc.png |\
		jq -r '.result.photo[] | .file_id' | tail -1)
		rm btc.png
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
	if (( ${valoraferido/.*/} != 0 )); then
		(( ${valoraferido/.*/} > ${valorhigh} )) ||\
		(( ${valoraferido/.*/} < ${valormin} )) && {
			msg+="*${exchange}:* R\$ $valoraferido
"
			(( ${exchangemax/.*/} > 0 )) && {
				msg+="(*Max* R\$ $exchangemax / *Min* R\$ $exchangemin)
Δ% na $exchange: $(bc <<< "scale=4; ($exchangemax/$exchangemin-1)*100" | grep -Eo "[0-9]*\.[0-9]{2}")% 
"
			}
		}
	fi
}

adiciona(){
	(( $# != 3 )) && return 1;
	local dono=$3
	local coin=${1^^}
	local quantidade=$2
	touch $dono.coins
	[[ $quantidade =~ [^[:digit:]\.-] ]] || {
		grep -qi "^$coin " $dono.coins && {
			read moeda valor <<< $(grep -i "$coin " $dono.coins);
			quantidade=$(bc <<< "$valor+$quantidade")
			sed -i "s/$coin .*/$coin $quantidade/g" $dono.coins
			envia "Quantidade de $coin atualizada para $quantidade para @$dono"
		} || {
			echo "${coin} $quantidade" >> $dono.coins
			envia "$quantidade $coin adicionada para @$dono"
		}
	  local usdt=$(getPrice USDTBRL)
	  local cotacao=$(getPrice ${coin^^}USDT);
		local totalusd=$(bc <<< "scale=2; $cotacao*$2")
		local totalbrl=$(bc <<< "scale=2; $totalusd*$usdt")
		msg="$coin USD $(formata $cotacao) (+$2)
Total adicionado: R\$ $(formata $totalbrl) (USD $(formata $totalusd))"
		envia "$msg"
	}
}

remove(){
	dono=$2
	moeda=${1^^}
	touch $dono.coins
	grep -q "^$moeda " $dono.coins && {
		sed -i "/$moeda/d" $dono.coins
		envia "$moeda removida de @$dono"
	} || envia "$dono não tem $moeda"
}


binance(){
	[ -f .binancelock ] && { envia "Usuario $(cat .binancelock) já está consultando. Espere sua vez, fominha"; return 1; }
	(( $# == 1 )) && { local flag=0; local dono=$1; }
	(( $# == 2 )) && { local flag=1; local dono=$2; }
	echo "@$dono" > .binancelock
	local lista=
	local usdt=$(getPrice USDTBRL)
	local btc=$(getPrice BTCBRL)
	envia "Consultando valores de @$dono na binance baseado em USDT (1 USDT = $usdt BRL)"
	totalreais=0
	totaldolares=0
	while read coin qtd; do
		[ ${coin^^} == "USDT" ] && {
			cotacao=1.0 
			cotacaobtc=$(getPrice BTCUSDT); 
		} || {
			cotacao=$(getPrice ${coin^^}USDT); 
			cotacaobtc=$(getPrice ${coin^^}BTC); 
		}
		grep -qE "([0-9]+)?\.[0-9]+" <<< $cotacao || { envia "${coin^^} nao encontrada na Binance"; continue; }
		value=$(bc <<< "scale=2; $cotacao*$qtd");
		brl=$(bc <<< "scale=2; $value*$usdt");
		btcbrl=$(bc -l <<< "$brl/$btc")
		totaldolares=$(bc <<< "scale=2; $totaldolares+$value")
		totalreais=$(bc <<< "scale=2; $totalreais+$brl")
		local msg+="\`\`\`
=========================
${qtd} ${coin^^} valem:
${coin^^} $cotacaobtc (USDT $(formata $cotacao))
USDT $(formata $value)
BRL $(formata $brl)
BTC $btcbrl
\`\`\`
"	
		lista+="$brl,${coin^^}
"
	done < $dono.coins
	envia "$msg"
	totalbtc=$(bc -l <<< "$totalreais/$btc")
	stack="Totais para @${dono}:
\`\`\`
USD $(formata $totaldolares)
BRL $(formata $totalreais)
BTC $totalbtc
\`\`\`
"
	envia "$stack"
	checkRecord $dono $totalreais
	lista=$(echo "${lista::-1}"| sort -nr)
	argvalor= 
	argmoeda=
	arglabel=
	while IFS=, read valor moeda; do
		echo buscando $moeda
		percent=$(bc <<< "scale=2; (100*$valor)/$totalreais")
		argvalor+="$percent,"
		valor=$(formata $valor)
		argmoeda+="${moeda^^} R\$ ${valor::-3}|"
		arglabel+="${percent}%|"
	done <<< "${lista}"
	argvalor=${argvalor::-1}
	argmoeda=${argmoeda::-1}
	arglabel=${arglabel::-1}
	cores=$(wc -l < $dono.coins)
	
	wget -q "https://chart.googleapis.com/chart?cht=p3&chd=t:$argvalor&chs=600x400&chdl=$argmoeda&chco=$(tr ' ' '|' <<< ${COLORS[@]:0:$cores})&chds=a&chtt=$dono BRL $(formata $totalreais)&chl=$arglabel&chdlp=b" -Ograph.png
	grafico=$(curl -s -X POST "$apiurl/sendPhoto" -F chat_id=$CHATID -F photo=@graph.png |\
        jq -r '.result.photo[] | .file_id' | tail -1)
	rm .binancelock -f
	(( ${flag:-0} == 1 )) && echo "$(date +%Y%m%d%H%M),$totalreais" >> $dono.history
#	mv graph.png history/$dono.$(date "+%Y%m%d-%Hh%M").png
}

consulta(){
	graph=1
	lista=
	dono=$1
	creditos=$(grep "^$dono " credits | cut -f2 -d " ")
	linhas=$(wc -l < $dono.coins)
	(( $creditos < $linhas )) && { envia "Vc precisa de $linhas créditos, mas tem apenas $creditos. Use o /binance."; return; }
	(( $creditos < 1 )) && { envia "Vc tá consultando demais, @$dono seu arrombado. Utilize o /binance"; return; }
	echo $dono tem $creditos creditos
#	[[ "$dono" == "eliashamu" ]] && { envia "Suas moedas desapareceram. Chame o FBI"; return 0; }
	envia "Consultando moedas de @$dono"
	read mbtc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/btc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	echo "mbtc: $mbtc btchigh: $btchigh btclow: $btclow"
	read maior menor <<< $(echo "${mbtc/.*/},MercadoBitCoin ${btc/.*/},MercadoBitCoin")
	IFS=, read reais maiorexchange <<< $maior
	echo "reais: $reais maiorexchange: $maior"
	dol=$(getLastDollar)
	(( ${#reais} < 2 )) && {
		echo reais vazio buscando na binance
		reais=$(curl -sk "https://api.binance.com/api/v3/ticker/price?symbol=BTCBRL" | jq '.price')
		echo reais: $reais
	}

	msg=
	totalreais=0
	totaldolares=0
	totalbtc=0
	btcprice=$(curl -sH "$COINMARKET" -H "Accept: application/json" \
		https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=BTC \
		| jq -r ".data.BTC.quote.USD.price")
	while read coin qtd; do
		(( $creditos < 1 )) && { envia "Seus Créditos acabaram. Se fudeu"; graph=0; break; }
		echo buscando $moeda
		json="$(echo "$(curl -sH "$COINMARKET" -H "Accept: application/json" \
			https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=$coin \
			| jq -r ".data.$coin.quote.USD | \"\(.price) \(.percent_change_1h) \(.percent_change_24h)\"") \
			$btcprice $coin")"
		grep "null" <<< "$json" && envia "${coin^^} não encontrada na coinmarketcap" || {
			read usd change1h change24h btc symbol <<< $json
			btc=$(bc -l <<< "$usd/$btc")
			grep -q "e" <<< "$btc" && btc=$(sed 's/e/*10^/' <<< "$btc" | bc -l)
			grep -q "e" <<< "$usd" && usd=$(sed 's/e/*10^/' <<< "$usd" | bc -l)
			dolares=$(bc <<< "$usd*$qtd")
			reaist=$(bc <<< "$dolares*$dol")
			totalreais=$(bc <<< "scale=2; $totalreais+$reaist");
			totaldolares=$(bc <<< "scale=2; $totaldolares+$dolares");
			totalbtc=$(bc <<< "${totalbtc}+${btc:-0.0000000001}*$qtd")
			local msg+="\`\`\`
=========================
${qtd} ${symbol^^} valem:
${symbol^^} $btc (USD $(formata $usd))
USD $(formata $dolares)
BRL $(formata $reaist)
BTC $(bc <<< "$btc*$qtd")
24h: $change24h
1h: $change1h
\`\`\`
"
			lista+="$reaist,${symbol^^}
"
		}
		let creditos--
		sleep 0.8
	done < $dono.coins
	envia "$msg"
	stack="Totais para @${dono}:
\`\`\`
USD $(formata $totaldolares)
BRL $(formata $totalreais)
BTC ${totalbtc}\`\`\`"
	envia "$stack"
	checkRecord $dono $totalreais
	(( $graph == 1 )) && {
	echo $graph valor de graph
	echo "$(date +%Y%m%d%H%M),$totalreais" >> $dono.history
	lista=$(sort -nr <<< "${lista::-1}")
	argvalor= 
	argmoeda=
	arglabel=
	while IFS=, read valor moeda; do
		echo buscando $moeda
		percent=$(bc <<< "scale=2; (100*$valor)/$totalreais")
		argvalor+="$percent,"
		valor=$(formata $valor)
		argmoeda+="${moeda^^} R\$ ${valor::-3}|"
		arglabel+="${percent}%|"
	done <<< "${lista}"
	argvalor=${argvalor::-1}
	argmoeda=${argmoeda::-1}
	arglabel=${arglabel::-1}
	cores=$(wc -l < $dono.coins)
	wget -q "https://chart.googleapis.com/chart?cht=p3&chd=t:$argvalor&chs=600x400&chdl=$argmoeda&chco=$(tr ' ' '|' <<< ${COLORS[@]:0:$cores})&chds=a&chtt=$dono BRL $(formata $totalreais)&chl=$arglabel&chdlp=b" -Ograph.png
	grafico=$(curl -s -X POST "$apiurl/sendPhoto" -F chat_id=$CHATID -F photo=@graph.png |\
        jq -r '.result.photo[] | .file_id' | tail -1)
	mv graph.png history/$dono.$(date "+%Y%m%d-%Hh%M").png
	}
	sed -i "s/$dono .*/$dono $creditos/g" credits
	echo $dono tem $creditos creditos
}

evolucao(){
	dono=$1
	[ ! -s $dono.history ] && {
		envia "Nao ha dados para $dono. Use /consulta antes";
	} || {
		(( $(wc -l < $dono.history) < 2 )) && {
			envia "Poucos registros para gerar o grafico para @$dono. Mínimo: 2";
		} || {
			arg=
			while IFS=, read data valor; do
				arg+=${valor//.*/},
			done < $dono.history
			arg=${arg::-1}
			arg=$(tr -s ',' <<< "$arg")
			local last=$(formata $(tail -1 $dono.history| cut -f2 -d,))
			IFS=, read diamesano valorr <<< "$(sort -n -k2 -t, $dono.history  | tail -1)"
			local data="${diamesano:6:2}/${diamesano:4:2}/${diamesano:0:4}, ${diamesano:8:2}:${diamesano:10:2}"
			local valor=$(formata $valorr)
			while [ ! -s out.png ]; do
				wget -q --post-data="chdl=Total&cht=lc&chd=t:$arg&chs=600x500&chtt=Stack+de+$dono:+R%24+$last|Recorde:+R%24+$valor+em+$data&chxt=y&chds=a&chg=10,10" \
				"https://chart.googleapis.com/chart" -Oout.png
			done
			grafico=$(curl -s -X POST "$apiurl/sendPhoto" -F chat_id=$CHATID -F photo=@out.png |\
			jq -r '.result.photo[] | .file_id' | tail -1)
			rm out.png
		}
	}
}

commandlistener(){
	atualizavar() {
		sed -i "s%$1.*%$1=\"$2\"%g" variaveis.sh
	}
	last=oe
	while : ; do
		source variaveis.sh
		for comando in $(curl -s  -X POST --data "offset=$(($offset+1))&limit=1" "$apiurl/getUpdates" |\
		jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"'|\
		sed 's| |\||g' | sort | uniq); do
			read offset username command <<< $(sed 's/|/ /g' <<< "$comando")
			shopt -s extglob
			isAdmin "$username" && {
				command=${command%%@*}
				isValidCommand "$command" && {
					source variaveis.sh
					[ "$command" != "$last" ] && {
						echo $offset - @$username - $command - $last >> comandos.log
						case $command in 
							/ltcmax*) (( ${command/* /} != $LTCMAX )) && {
								envia "${username}, setando *LTCMAX* para ${command/* /}";
								atualizavar LTCMAX ${command/* /}; 
								atualizavar last "$command";
							};;
							/ltcmin*) (( ${command/* /} != $LTCMIN )) && {
								envia "${username}, setando *LTCMIN* para ${command/* /}";
								atualizavar LTCMIN ${command/* /};
								atualizavar last "$command"; 
							};;
							/btcmax*) (( ${command/* /} != $BTCMAX )) && {
								envia "${username}, setando *BTCMAX* para ${command/* /}";
								atualizavar BTCMAX ${command/* /};
								atualizavar last "$command";
							};;
							/btcmin*) (( ${command/* /} != $BTCMIN )) && {
								envia "${username}, setando *BTCMIN* para ${command/* /}";
								atualizavar BTCMIN ${command/* /};
								atualizavar last "$command";
							};;
							/intervalo*) [ "${command/* /}" != "$INTERVALO" ] && {
								envia "${username}, setando *intervalo* para ${command/* /} minutos";
								atualizavar INTERVALO ${command/* /};
								atualizavar last "$command";
							};;
							/porcentagem*) [ "${command/* /}" != "$PORCENTAGEM" ] && {
								envia "${username}, setando *porcentagem* para ${command/* /}%";
								atualizavar PORCENTAGEM ${command/* /};
								atualizavar last "$command";
							};;
							/coin*) [ "${command}" != "$last" ] && {
								dono=$username
								coin ${command/\/coin /};
								atualizavar last "$command"; };;
							/cotacoes) mensagem; 
								atualizavar last "$command";;
							/parametros) parametros $username; 
								atualizavar last "$command";;
							/help) ajuda $username; 
								atualizavar last "$command";;
							/adiciona*) adiciona ${command/\/adiciona /} $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/remove*) remove ${command/\/remove /} $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/consulta) consulta $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/binance) binance $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/binancegrava) binance flag $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/evolucao) evolucao $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/creditos) checkCredits $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/reset) resetCredits $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
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
	echo "bot inicializado"
	dolar=$(getLastDollar)
	echo "valor do dolar: $dolar"
	let ct+=1
	(( ct % 2 == 0 )) && { mensagem; sed -i "s/last=.*/last=oe/g" variaveis.sh ; }
	sleep ${INTERVALO}m
	source variaveis.sh
	msg=
	
	tmp=$(curl -sH "$COINMARKET" -H "Accept: application/json" "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=BTC" | jq -r ".data.BTC.quote.USD.price")
	xapo=$(printf "%0.2f " ${tmp})
	tmp=$(wget -qO- $mbtc/btc/ticker |jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"')
	(( ${#tmp} < 2 )) && {
		echo reais vazio buscando na binance
		tmp=$(getPrice BTCBRL)
		echo reais: $tmp
	}

	read btc btchigh btclow <<< $(printf "%0.2f " ${tmp:-$btc $btchigh $btclow})
	read maior menor <<< $(echo "${btc/.*/},MercadoBitCoin ${btc/.*/},MercadoBitCoin")
	IFS=, read maiorvlr maiorexchange <<< $maior
	IFS=, read menorvlr menorexchange <<< $menor
	diff=$(bc <<< "scale=3; (($maiorvlr/$menorvlr)-1)*100" | grep -Eo "[0-9]{1,}\.[0-9]")
	
	rate=$(bc <<< "scale=2; $maiorvlr/$xapo")
	rate=${rate:-3}
	btcusd=$(bc <<< "scale=2; $xapo*$dolar")
	(( $(bc <<< "${rate} >= ${PORCENTAGEM}") == 1 )) && {
		msg+="
*$maiorexchange/BTCUSD:* $rate ($btc/$xapo)"
	}
	diff=${diff:-0}
	(( $(bc <<< "${diff} >= ${PORCENTAGEM}") == 1 )) && {
		msg+="
*$maiorexchange ($maiorvlr) ${diff}% mais caro que $menorexchange ($menorvlr)*
"
	}
	(( ${#msg} > 2 )) && {
		envia "$msg"
	}
	[ ! -s $(date "+%Y%m%d").dat ] && {
		echo "##hora valor" > $(date "+%Y%m%d").dat
		for admin in ${ADMINS[@]}; do echo $admin $DAILYCREDITS; done > credits
		envia "Todos os usuários agora tem $DAILYCREDITS consultas"
	}
	read gmbtc gfoxbit btcusd <<< "${btc:-0} ${foxbitsell:-0} ${btcusd:-0}"
	echo "$(date "+%H:%M:%S") ${gmbtc/.*/} ${gfoxbit/.*/} ${btcusd/.*/}" >> $(date "+%Y%m%d").dat
done
