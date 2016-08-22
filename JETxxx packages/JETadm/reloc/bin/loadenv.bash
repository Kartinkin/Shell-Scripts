# Version	1.0
# Date		15 Aug 2000
# Author	Kirill Kartinkin

# Программа считывает из stdin пары
#	<ИмяПеременной> <Значение>
# <ИмяПеременной> и <Значение> должны быть разделены произвольной комбинацией
# пробелов и табуляций. Переменная экспортируется.
#
# Из входного текста удаляются все строки, в начале которых стоит "#".
#
# Программа рассчитана на использование с оболочкой═Bourne-Again-shell.
#
# Формат вызова:
#	. /var/adm/bin/loadenv.bash <env.txt
#
TmpFile=/tmp/loadenv.$$.tmp

ccat >${TmpFile}
# Создали временный файл, если написать ccat | while ...",
# bash запустит отдельный процесс для while, и только в нем
# будут наши переменные.
while read Var Val
do
	eval ${Var}=${Val}
	export ${Var}
done <${TmpFile}

rm -f ${TmpFile} >/dev/null 2>&1
