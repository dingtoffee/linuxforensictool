#!/bin/bash

# Linux Analysis Script by DingToffee (A modification to the script from R-CSIRT) 
# Date: 2021.07.29
# Version: 1.0
# usage: sudo bash linux_triage.sh [image_mounted_path] [OPTIONAL: 1 to enable Timelineing of Image into bodyfile] 
# Licence: MIT

[[ $UID == 0 || $EUID == 0 ]] || (
  echo "Must be root! Please execute after 'su -' OR with 'sudo' . "
  exit 1
  ) || exit 1


### dynamic Configs
WEBROOT=()
WEBSERVICE=()
WEBROOT+=                                    ###### web server document root dir (IF YOU ALREADY KNOW, Please ADD)
WEBSERVICE+=                                 ###### web server installed directory (IF YOU ALREADY KNOW, Please ADD)
STARTDATE=$((`date -I | cut -d"-" -f1`-1))-`date -I | cut -d"-" -f2,3` ###### start date score for getting log rotation file (DEFAULT 1 year ago) except for boot.log,kern.log,auth.log
ENDDATE=`date -I | cut -d"-" -f1,2`-$((`date -I | cut -d"-" -f3`+1))   ###### end date score for getting log rotation file ( TODAY ) except for boot.log,kern.log,auth.log
###

### static Configs 
MOTHERPATH=`dirname "$1/12"`
EXCLUDES_PATHS=./options/excludes.txt   ###### exclude paths from the directory listing. Each path should be on a new line.
SaveCWD=1                               ###### SAVE OUTPUT FILE TO WORKING DIRECTORY (SAME AS SCRIPT) 
STORAGETEST=1                           ###### STORAGE TEST VARIABLES : STORAGETEST: 1=enable
MINSPACE=1000000                        ###### MINSPACE(KB): Set to minimum number of KB required to keep temp files locally
IRCASE=`cat $1/etc/hostname`                       ###### basename of results archive
LOC=/tmp/$IRCASE                        ###### output destination, change according to needs
TMP=$LOC/$IRCASE'-tmp.txt'              ###### tmp file to redirect results
ERROR_LOG=$LOC/0_SCRIPT-ERRORS.txt      ###### redirect stderr and Debug echo
PHPBACKDOOR=./options/backdoorscan.php  ###### phpbackdoor script
## FLAG options
HASHFLAG=1                              ###### HashFlag 1=enable : get binary hash
CLAMAVFLAG=0                            ###### clamavFlag 1= install clamav and scan full
RKHUNTERFLAG=0                          ###### rkhunterFlag 1= install rkhunter and scan
MESSAGEFLAG=1                           ###### messageFlag 1= collect /var/log/messages and syslog (eg: mail log)
BACKUPFLAG=0                            ###### BACKUPFLAG 1= copy web server conf, contents for backup
### 

check_tmpstorage(){
    # Check that there is at least MINSPACE KB available on /
    if [ "$STORAGETEST" = "1" ] ; then
    echo -e "\n[Debug][check_tmpstorage] check /tmp storage enough..."
        DF=$(df /tmp)
        while IFS=' ' read -ra RES; do
            LEN=${#RES[@]}
            AVAIL=`expr $LEN - 3`
            if [ ${RES[$AVAIL]} -lt $MINSPACE ]
            then
                echo Less than $MINSPACE available. Exiting.
                exit
            fi
        done <<< $DF
    fi
}

excludes_paths(){
    # To exclude paths from the directory listing, provide a file called
    EXCLUDES="-path /var/cache -o -path /var/spool"
    if [ -f $EXCLUDES_PATHS ]; then
        while read line
        do
            EXCLUDES="$EXCLUDES -o -path $line"
        done <$EXCLUDES_PATHS
    fi
    echo -e "\n[Debug][excludes_paths] set excludes_paths [$EXCLUDES]..."
}


prepare(){
    mkdir $LOC
    touch $ERROR_LOG
    echo -e "\n[Debug][prepare] mkdir "$LOC"\n"
} 2> /dev/null

get_userprofile(){
    # userprofile
    mkdir $LOC/Dir_userprofiles

    while read line
    do
        user=`echo "$line" | cut -f1 -d:`
        home=`echo "$line" | cut -f6 -d:`
        mkdir $LOC/Dir_userprofiles/$user        
        # user shell history

        echo -e "\n[Debug][userprofile][$user] get user shell history ... to Dir_userprofiles/$user/shellhistory.txt"
        for f in $MOTHERPATH/home/$user/.*_history; do
            count=0
            while read line
            do
                echo $f $count $line >> $LOC/Dir_userprofiles/$user/$IRCASE'-shellhistory.txt'
                echo $f $count $line >> $LOC/Dir_userprofiles/$user/$IRCASE'-shellhistory.txt'
                count=$(( $count + 1 ))
            done < $f
        done        
        # user contabs
        #echo -e "\n[Debug][userprofile][$user] get user crontabs ... to Dir_userprofiles/$user/crontab.txt"
        #crontab -u $user -l > $LOC/Dir_userprofiles/$user/$IRCASE'-crontab.txt'
        # ssh known hosts
        echo -e "\n[Debug][userprofile][$user] get ssh known hosts ... to Dir_userprofiles/$user/ssh_known_hosts.txt"
        cp -RH $MOTHERPATH/home/$user/.ssh/known_hosts $LOC/Dir_userprofiles/$user/$IRCASE'-ssh_known_hosts.txt'
        # ssh config
        echo -e "\n[Debug][userprofile][$user] get ssh config ... to Dir_userprofiles/$user/ssh_config.txt"
        cp -RH $MOTHERPATH/home/$user/.ssh/config $LOC/Dir_userprofiles/$user/$IRCASE'-ssh_config.txt'
         echo -e "\n[Debug][userprofile][$user] get ssh key ... to Dir_userprofiles/$user/ssh_key.txt"
        cp  -RH $MOTHERPATH/home/$user/.ssh/authorized_keys $LOC/Dir_userprofiles/$user/ssh_key.txt
        cp  -RH $MOTHERPATH/home/$user/.ssh/authorized_keys2 $LOC/Dir_userprofiles/$user/ssh_key2.txt
        
        cp -RH $MOTHERPATH/root/.ssh/known_hosts $LOC/Dir_userprofiles/root/$IRCASE'-ssh_known_hosts.txt'
        cp -RH $MOTHERPATH/root/.ssh/authorized_keys2 $LOC/Dir_userprofiles/root/$IRCASE'-ssh_key.txt'
        cp -RH $MOTHERPATH/root/.ssh/authorized_keys $LOC/Dir_userprofiles/root/$IRCASE'-ssh_key2.txt'
        cp -RH $MOTHERPATH/root/.ssh/config $LOC/Dir_userprofiles/root/$IRCASE'-ssh_config.txt'
        cp -RH $MOTHERPATH/root/.bash_history $LOC/Dir_userprofiles/root/$IRCASE'-shellhistory.txt'
        
        
        	
    done < $MOTHERPATH/etc/passwd

    # user accounts
    echo -e "\n[Debug][userprofile] get user accounts ... to passwd.txt"
    cp -RH $MOTHERPATH/etc/passwd $LOC/$IRCASE'-passwd.txt'

    # user groups
    echo -e "\n[Debug][userprofile] get user groups ... to group.txt"
    cp -RH $MOTHERPATH/etc/group $LOC/$IRCASE'-group.txt'

    # user accounts
    {
        echo -e "\n[Debug][userprofile] get user shadows ... to shadow.txt"
        while read line
        do
            user=`echo "$line" | cut -d':' -f1`
            pw=`echo "$line" | cut -d':' -f2`
            # ignore the salt and hash, but capture the hashing method
            hsh_method=`echo "$pw" | cut -d'$' -f2`
            rest=`echo "$line" | cut -d':' -f3,4,5,6,7,8,9`
            echo "$user:$hsh_method:$rest"
        done < $MOTHERPATH/etc/shadow
    } > $LOC/$IRCASE'-shadow.txt'
}

get_systeminfo(){
    # version information
    echo -e "\n[Debug][systeminfo] get version infomation ... to virsion.txt"
    {
        cat $MOTHERPATH/etc/os-release;
        cat $MOTHERPATH/proc/version

    } > $LOC/$IRCASE'-version.txt'

    # locale information
    echo -e "\n[Debug][systeminfo] get locale info ... to locale.txt"
    $MOTHERPATH/etc/default/locale > $LOC/$IRCASE'-locale.txt'

    # installed packages with version information - ubuntu
    echo -e "\n[Debug][systeminfo] get installed packages on ubuntu ... to package.txt"
    cat $MOTHERPATH/var/lib/dpkg/status | grep -B 1 "Status: install ok installed" > $LOC/$IRCASE'-packages.txt'
 }
 
 get_servicereg(){

    # cron
    echo -e "\n[Debug][servicereg] get cron information ... to cron*.txt"
    # users with crontab access
    cp -RH $MOTHERPATH/etc/cron.allow $LOC/$IRCASE'-cronallow.txt'
    # users with crontab access
    cp -RH $MOTHERPATH/etc/cron.deny $LOC/$IRCASE'-crondeny.txt'
    # crontab listing
    cp -RH $MOTHERPATH/etc/crontab $LOC/$IRCASE'-crontab.txt'
    # cronfile listing
    ls -al $MOTHERPATH/etc/cron.* > $LOC/$IRCASE'-cronfiles.txt'
}

get_logs(){
    # logs
    # SCOPE : STARTDATE ~ ENDDATE  find . -type f -name "*.php" -newermt "$STARTDATE" -and ! -newermt "$ENDDATE" -ls

    mkdir $LOC/Dir_logs
    cp -r $MOTHERPATH/var/log $LOC/Dir_logs
    cp -RH $MOTHERPATH/run/utmp $LOC/Dir_logs/log/run_utmp 
    mkdir $LOC/Dir_logs/$IRCASE-last
    last -f $LOC/Dir_logs/log/wtmp > $LOC/Dir_logs/$IRCASE-last/$IRCASE'-wtmp.txt'
    last -f $LOC/Dir_logs/log/utmp > $LOC/Dir_logs/$IRCASE-last/$IRCASE'-utmp.txt'
    last -f $LOC/Dir_logs/log/btmp > $LOC/Dir_logs/$IRCASE-last/$IRCASE'-btmp.txt'
    last -f $LOC/Dir_logs/log/run_utmp > $LOC/Dir_logs/$IRCASE-last/$IRCASE'-run_utmp.txt'

}

get_hash(){
    echo -e "\n[Debug][hash] try to get SHA256 hash value for bin ..." 
    if [ "$HASHFLAG" = "1" ] ; then
        echo -e "\n[Debug][hash] get SHA256 hash value for bin ... to binhashlist.txt" 
        cat $LOC/$IRCASE'-ls.txt' | rev | cut -d" " -f1 | rev | grep -e '$MOTHERPATH/bin/' -e '$MOTHERPATH/sbin/' | xargs -i sha256sum {}  > $LOC/$IRCASE'-binhashlist.txt' 
    else
        echo -e 'HASHFLAG = '$HASHFLAG' -> NOT Enabled' 
    fi
}

get_timeline(){
	# Generating bodyfile 
	echo -e "\n[Debug][timeline] generating bodyfile of the image ..."
	mkdir $LOC/Timeline 
	mac-robber $MOTHERPATH > $LOC/Timeline/$IRCASE'_timeline' 
}
######################   MAIN    ##########################

# die if path not provided
[ "$#" -lt 1 -o "$#" -gt 2 ] && { echo "Usage: ./linux_triage.sh [imagepath] [OPTIONAL: To enable Timeline function - \"1\" to enable it \"0\" to disable it ] ..."; exit 1;}
{
    check_tmpstorage 2>&1
    excludes_paths 2>&1
    prepare 2>&1
} 

# start timestamp
date '+%Y-%m-%d %H:%M:%S %Z %:z' > $LOC/$IRCASE'-date.txt'
#echo -e "$1" 


echo -e "\n[Debug] Collect triage data  ..."
{
    get_userprofile 2>&1
    get_systeminfo 2>&1
    get_activity 2>&1
    #get_fileinfo 2>&1   
    get_servicereg 2>&1
    get_logs 2>&1
    #get_srvconf 2>&1
    #get_srvcontents 2>&1
    #scan_virus 2>&1    
    get_hash 2>&1
    if [ $2 = 1 ]; then 
    	get_timeline 2>&1
    fi 
    echo -e "\n##############  DEBUG & ERROR LOGS END ####################"
} >> $ERROR_LOG


if [ "$BACKUPFLAG" = "1" ] ; then
    echo -e "\n[Debug] Back Up collection  ..."
    {
        additional_backup 2>&1
    } >> $ERROR_LOG
else
    echo -e 'BACKUPFLAG = '$BACKUPFLAG' -> NOT Enabled' 
fi

# tree of outputs 
{
 echo -e "\n[Debug] make OUTPUT-TREE  ..."
 if tree &> /dev/null; then
    tree -alh $LOC > $LOC/1_OUTPUT-TREE.txt
 else
    find $LOC | sort | sed '1d;s/^\.//;s/\/\([^/]*\)$/|--\1/;s/\/[^/|]*/| /g' > $LOC/1_OUTPUT-TREE.txt
 fi
}

echo -e "\n[Debug] Compress to tar.gz  ..."
CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $LOC
tar -zcvf "/tmp/"$IRCASE".tar.gz" * > /dev/null
cd $CUR_DIR

echo -e "\n[Debug] move tar.gz to here ..."
if [ "$SaveCWD" = "1" ] ; then
    mv "/tmp/"$IRCASE".tar.gz" $CUR_DIR
fi

# end timestamp
date '+%Y-%m-%d %H:%M:%S %Z %:z' >> $LOC/$IRCASE'-date.txt'

echo -e "\n[Debug] del /tmp file ..."
cd /tmp
rm -r $LOC

echo -e "\n[Debug] triage script END "

