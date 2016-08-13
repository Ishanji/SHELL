devOutput='devOutput/'
devScript='devScript/'
expScrip='./expectScript/'
expOutput='./expectOutput/'
function command(){
case "$1" in
        viewinfo)  Cmmd='export storage-view summary';;
        viewVvol)  Cmmd="ll -t /clusters/cluster-1/exports/storage-views/*::virtual-volumes";;
		volumeInfo) Cmmd="show-use-hierarchy -t /clusters/cluster-1/virtual-volumes/"$2;;
		initInfo) Cmmd="ll -t /clusters/cluster-1/exports/storage-views/*::initiators";;
		*) echo 'WRONG COMMAND *** FUCK**YOU**!!!' ;exit;;
esac
}
function makeExpdoc(){
d=$expScrip$1
echo $d
echo 'set timeout -1'>$d
echo spawn vplexcli>> $d
echo 'expect "Enter User Name:"'>>$d
echo send service'\r' >>$d
echo 'expect "Password:"'>>$d
echo send Mi@Dim7T'\r'>>$d
echo 'expect "VPlexcli:/>"' >>$d
echo send \"$2'\r"'>>$d
echo 'expect "VPlexcli:/>"'>>$d
echo send 'exit\r"'>>$d
}
command initInfo
makeExpdoc viewInit "$Cmmd"
expect -f $expScrip/viewInit > $expOutput/viewinit.txt
rmvartail=`cat $expOutput/viewinit.txt |wc -l`
echo $rmvartail
rmtail=`expr $rmvartail - 1`
echo  $rmtail
rmvarupper=`cat $expOutput/viewinit.txt |grep -n "ll"|awk -F: '{print $1}' |awk '{print $1}'`
echo $rmvarupper
rmupper=`expr $rmtail - $rmvarupper `
echo $rmupper
cat $expOutput/viewinit.txt |head -"$rmtail" |tail -"$rmupper"  >$expOutput/tempviewinit.txt
cat $expOutput/tempviewinit.txt|tr "/" " " |grep -Ev "^-|^Name" | tr -d [] |tr "," "\n" |sed '/^\s*$/d'|awk '{if($1=="clusters"){k=$5;}else if($1 == "initiators"){print k,$2;}else{print k, $1;}}' > $expOutput/lookupviewinit.txt
command viewVvol
makeExpdoc mvVol "$Cmmd"
expect -f $expScrip/mvVol > $expOutput/mvvol.txt
rmvartail=`cat $expOutput/mvvol.txt |wc -l`
rmtail=`expr $rmvartail - 1`
rmvarupper=`cat $expOutput/mvvol.txt |grep -n "ll"|awk -F: '{print $1}'`
rmupper=`expr $rmtail - $rmvarupper `
cat $expOutput/mvvol.txt |head -"$rmtail" |tail -"$rmupper"  >$expOutput/tempmvvol.txt
cat $expOutput/tempmvvol.txt |tr "/" " " |grep -Ev "^-|^Name"| tr -d [] |sed '/^\s*$/d'|awk '{if($1=="clusters"){k=$5;}else if($1 =="virtual-volumes"){print k,$2;}else{print k, $1;}}' > $expOutput/lookupviewvvol.txt
rm $expOutput/mvvol.txt $expOutput/tempmvvol.txt  $expOutput/viewinit.txt $expOutput/tempviewinit.txt
command viewinfo
makeExpdoc Exportlist "$Cmmd"
expect -f $expScrip/Exportlist > $expOutput/exportlist.txt
rmvartail=`cat $expOutput/exportlist.txt |grep -n Total|awk -F: '{print $1}'`
rmtail=`expr $rmvartail - 2`
rmvarupper=`cat $expOutput/exportlist.txt |grep -n "^-"|awk -F: '{print $1}'`
rmupper=`expr $rmtail - $rmvarupper`
for mv in `cat $expOutput/exportlist.txt |head -"$rmtail" |tail -"$rmupper" |awk '{print $1}'`
do
    for i in `cat $expOutput/lookupviewvvol.txt  |tr -d \( |sed s/\)/,/|grep -w "$mv:" |awk '{print $2}'`
    do
        vVol=`echo $i |awk -F, '{print $2}'|sort -u`
        vVolnaa=`echo $i |awk -F, '{print $3}'|sort -u`
        vVolvarsizeparameter=`echo $i |awk -F, '{print $4}'|awk '{print substr($0,length($0),1)}' |sort -u`
        vVolvarsize=`echo $i |awk -F, '{print $4}'|awk '{print substr($0,1,length($0)-1)}'|sort -u`
        if [[ $vVolvarsizeparameter == "M" ]]
        then
            vVolsize=`echo $vVolvarsize`
        elif [[ $vVolvarsizeparameter == "G" ]]
        then
            vVolsize=`echo 1024*$vVolvarsize |bc`
        elif [[ $vVolvarsizeparameter == "T" ]]
        then
            vVolsize=`echo 1048576*$vVolvarsize |bc`
        else
            echo "****Wrong Size*****"
            vVolsize=""
        fi
        if [ ! -f "$expOutput$devOutput$vVol.txt" ]
        then
            command volumeInfo $vVol
            makeExpdoc "$devScript$vVol" "$Cmmd"
            expect -f "$expScrip$devScript$vVol" > $expOutput$devOutput$vVol.txt
        fi
        backLunstrbox=`cat -v $expOutput$devOutput$vVol.txt |tr -d  ^[[ |sed s/1m// |sed s/mM// |sed s/0m/" "/  |sed s/m33m// |grep storage-array |awk '{print $3}'`
        echo $backLunstrbox
        backLunnaa=` cat -v $expOutput$devOutput$vVol.txt |tr -d  ^[[ |sed s/1m// |sed s/mM// |sed s/0m/" "/  |sed s/m33m// |grep "logical-unit" |awk '{print $3}'`
        echo $backLunnaa
        backLunname=`cat -v  $expOutput$devOutput$vVol.txt  |tr -d  ^[[ |sed s/1m// |sed s/mM// |sed s/0m/" "/  |sed s/m33m// |grep "storage-volume" |awk '{print $3}'`
        echo $backLunname
	    intor=`cat $expOutput/lookupviewinit.txt |grep -w $mv: |awk '{print $2}'|tr "\n" ":"`
        echo $mv,$vVol,$vVolnaa,$vVolsize, $backLunstrbox,$backLunnaa,$backLunname,$intor |tee -a main.csv
    done
done
