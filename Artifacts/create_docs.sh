#!/usr/xpg4/bin/sh
# Version	0.0
# Date		2 Nov 2001
# Author	Kirill Kartinkin

set -A Hex 0 1 2 3 4 5 6 7 8 9 a b c d e f

for ExpFile in explorer.*.tar.gz
do
	ExpDir=${ExpFile%.tar.gz}
	HostName=${ExpDir#*.}
	HostName=${HostName#*.}
	HostName=${HostName%-*}
	
	ErrFile="doc.${HostName}.err"
	OutFile="doc.${HostName}.out"
	DiffFile="doc.${HostName}.diff"
	rm ${ErrFile} ${DiffFile} 2>/dev/null

	print "\nProcessing ${HostName}."
	print -n "\tExtracting ${ExpFile}... "
	gunzip <${ExpFile} | /usr/bin/tar xf -
	/usr/bin/mv ${OutFile} ${OutFile}.old 2>/dev/null
	print -n "Done.\n\tGenerating doc file... "
	Out=$(./doc.sh ${ExpDir} 2>&1 >${OutFile})
	if [[ -n "${Out}" ]]
	then
		print "Done with errors."
		print "${Out}" | tee ${ErrFile}
		print
	else
		print "Done."
	fi

	if [[ -f ${OutFile}.old ]]
	then
		Out=$(diff ${OutFile} ${OutFile}.old )
		if [[ -n "${Out}" ]]
		then
			print "\t\tAttention! Server ${HostName} modified."
			print "${Out}" >${DiffFile}
		else
			rm ${OutFile}.old ${DiffFile} 2>/dev/null
		fi
	fi
	
	print -n "\tRemoving ${ExpDir}... "
	rm -rf ${ExpDir}
	print "Done."
done
