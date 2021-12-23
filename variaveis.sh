TOKEN=token do bot do telegram
COINMARKET=( "X-CMC_PRO_API_KEY: sua api key do coinmarketcap" ) # suporta várias apikeys
CHATID=chat_id do grupo onde o bot está
ADMINS=( lista de usernames no telegram )
MASTER=${ADMINS[0]}
DAILYCREDITS=50
COLORS=( FFEBCD 0000FF 8A2BE2 A52A2A DEB887 5F9EA0 7FFF00 D2691E FF7F50 6495ED FFF8DC DC143C 00FFFF 00008B 008B8B B8860B A9A9A9 006400 BDB76B 8B008B 556B2F FF8C00 9932CC 8B0000 E9967A 8FBC8F 483D8B 2F4F4F 00CED1 9400D3 FF1493 00BFFF 696969 1E90FF B22222 FFFAF0 228B22 FF00FF 228B22)
INTERVALO="30"
PORCENTAGEM="90"
THRESHOLD="3"
foxbiturl="https://api.blinktrade.com/api/v1/BRL/ticker?crypto_currency=BTC"
apiurl="https://api.telegram.org/bot$TOKEN"
mbtc=https://www.mercadobitcoin.net/api
coinmarketcap=https://api.coinmarketcap.com/v1/ticker
COMANDOS="^/cotacoes$|\
^/coin [a-zA-Z0-9.-]+( [0-9]+(\.[0-9]+)?)?$|\
^/adiciona [0-9a-zA-Z-]+ -?[0-9]+(\.[0-9]+)?$|\
^/remove [0-9a-zA-Z-]+$|\
^/consulta$|\
^/evolucao$|\
^/reset$|\
^/creditos$|\
^/monitorar (on|off) [0-9a-zA-Z-]+$|\
^/alertar (list|off|-?[0-9]+(\.[0-9]+)?) [0-9a-zA-Z-]+$|\
^/binancegrava$|\
^/binance$"
