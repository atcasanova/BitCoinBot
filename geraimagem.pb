#!/usr/bin/gnuplot
reset
set terminal png

set xdata time
set timefmt "%H:%M:%S"
set format x "%H:%M"
set xlabel "horario"

set ylabel "Valor"
set yrange [8351:8650]

set title "Valor do Bitcoin hoje"
set key reverse left outside
set grid

set style data linespoints
plot ARG1 using 1:2 title "Btc"
#
