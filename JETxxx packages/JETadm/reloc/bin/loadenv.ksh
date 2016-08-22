# Version	0.0
# Date		15 Aug 2000
# Author	Kirill Kartinkin

# ��������� ��������� �� stdin ����
#	<�������������> <��������>
# <�������������> � <��������> ������ ���� ��������� ������������ �����������
# �������� � ���������. ���������� ��������������.
#
# �� �������� ������ ��������� ��� ������, � ������ ������� ����� "#".
#
# ��������� ���������� �� ������������� � ����������
# Korn-shell � POSIX-shell.
#
# ������ ������:
#	. /var/adm/bin/loadenv.ksh <env.txt
#

ccat | while read Var Val
do
	eval ${Var}=${Val}
	export ${Var}
done
