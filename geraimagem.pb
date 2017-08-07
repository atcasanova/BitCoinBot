#!/usr/bin/gnuplot
reset
set terminal png enhanced font "/usr/share/fonts/truetype/msttcorefonts/arial.ttf,12" size 1200,600

set xdata time
set timefmt "%H:%M:%S"
set format x "%H:%M"
set xlabel "horario"

set ylabel "Valor"
set yrange [ 10132:11020]

set title "Valor do Bitcoin hoje"
set key reverse left outside
set grid

set style data linespoints
plot ARG1 using 1:2 title "MercadoBitCoin", \
	   ARG1 using 1:3 title "FoxBit", \
		 ARG1 using 1:4 title "BitCambio"
#
