TOKEN=SEU_TOKEN
CHATID=SEU_CHAT_ID
ADMINS=( lista de autorizados a dar comandos separados por espaco )
COLORS=( FFEBCD 0000FF 8A2BE2 A52A2A DEB887 5F9EA0 7FFF00 D2691E FF7F50 6495ED FFF8DC DC143C 00FFFF 00008B 008B8B B8860B A9A9A9 006400 BDB76B 8B008B 556B2F FF8C00 9932CC 8B0000 E9967A 8FBC8F 483D8B 2F4F4F 00CED1 9400D3 FF1493 00BFFF 696969 1E90FF B22222 FFFAF0 228B22 FF00FF 228B22)
INTERVALO="5"
BTCMAX="36500"
BTCMIN="25000"
LTCMAX="1300"
LTCMIN="100"
PORCENTAGEM="15"
last=oe
foxbiturl="https://api.blinktrade.com/api/v1/BRL/ticker?crypto_currency=BTC"
apiurl="https://api.telegram.org/bot$TOKEN"
mbtc=https://www.mercadobitcoin.net/api
coinmarketcap=https://api.coinmarketcap.com/v1/ticker
COMANDOS="^/cotacoes$|\
^/[lb]tcm[ai][xn] [0-9]+$|\
^/help$|^/parametros$|\
^/intervalo [0-9]+(\.[0-9])?$|\
^/porcentagem [0-9]{1,2}(\.[0-9]{1,2})?$|\
^/coin( [a-zA-Z0-9.-]+){1,2}$|\
^/adiciona [0-9a-zA-Z-]+ -?[0-9]+(\.[0-9]+)?$|\
^/remove [0-9a-zA-Z-]+$|\
^/consulta$"

