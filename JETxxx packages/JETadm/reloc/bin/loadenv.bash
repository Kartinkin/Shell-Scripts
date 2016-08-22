# Version	1.0
# Date		15 Aug 2000
# Author	Kirill Kartinkin

# ��������� ��������� �� stdin ����
#	<�������������> <��������>
# <�������������> � <��������> ������ ���� ��������� ������������ �����������
# �������� � ���������. ���������� ��������������.
#
# �� �������� ������ ��������� ��� ������, � ������ ������� ����� "#".
#
# ��������� ���������� �� ������������� � ��������ʠBourne-Again-shell.
#
# ������ ������:
#	. /var/adm/bin/loadenv.bash <env.txt
#
TmpFile=/tmp/loadenv.$$.tmp

ccat >${TmpFile}
# ������� ��������� ����, ���� �������� ccat | while ...",
# bash �������� ��������� ������� ��� while, � ������ � ���
# ����� ���� ����������.
while read Var Val
do
	eval ${Var}=${Val}
	export ${Var}
done <${TmpFile}

rm -f ${TmpFile} >/dev/null 2>&1
