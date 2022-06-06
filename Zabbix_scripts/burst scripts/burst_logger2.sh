#!/bin/bash
#собираем значения переданных байт с интерфейсов
#ifAlias.792	RASCOM
#ifAlias.791	GLOBAL_ae4
#ifAlias.789	DATA-IX_LAG_ae2

echo -n `date --rfc-3339=seconds`" input,"
snmpget -v 2c -c AlSiTeC  141.101.186.2 1.3.6.1.2.1.31.1.1.1.6.$1 | sed 's/.*:\(.*\)$/\1/g'
echo -n `date --rfc-3339=seconds`" output,"
snmpget -v 2c -c AlSiTeC  141.101.186.2 1.3.6.1.2.1.31.1.1.1.10.$1 | sed 's/.*:\(.*\)$/\1/g'

