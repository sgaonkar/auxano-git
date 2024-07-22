#!/bin/nsh

###############################################################################
#
# Search Script on the Server for crontab
#
###############################################################################
#
# This script collects the script information data from crontab of the managed
# servers and converts to an xml format
#
###############################################################################

HOST=`hostname`
USER=$2
LOG_FILE=/scripts.txt
TEMP_FILE=/scripts.tmp
XML_FILE=/scripts_crontab_Pattern.xml

TMP_CRONTAB=/tmp/crontab.tmp

function getTargetOS()
{
    __target_host=$1
    __target_os=`blquery $__target_host -e "os_name()"`
    if [ $__target_os = "RedHat" ] ; then
        echo "el"
	elif [ $__target_os = "Ubuntu" ] ; then
        echo "ubuntu"
    fi
}

########
# Main #
########

host_os=`getTargetOS`
echo $host_os

uname -s | grep -q "^Windows"
	if [ $? -eq 0 ]
	then
		echo "Windows system, not running the discovery"
	else
		echo "linux system, getting the crontab"
		nexec $HOST crontab -u root -l >$TMP_CRONTAB
		
		if [ -s $TMP_CRONTAB ]
		then
       	while read line
    	do
        		read minute hour day month week command command1 <<<$(IFS=" "; echo $line)

                echo $command $command1

                VAR=`find -L $command1 -ls`
                echo $VAR
                read inode_number size_blocks file_permissions number_of_hard_links owner group size_in_bytes month date time_or_year pathname <<<$(IFS=" "; echo $VAR)
                
                FILENAME=`basename $pathname`
                FILE_TYPE_STR=`file -b $pathname`
                echo $FILE_TYPE_STR

                read attribute interpreter type mode <<<$(IFS=" "; echo $FILE_TYPE_STR)
                
                if [[ "$attribute" != "directory" ]]	
				then
					# Get File Checksum
					CHECKSUM=`md5sum $pathname`
					
					SCHEDULE=$minute:$hour:$day:$month:$week
					
					if [[ "$type" = "script" ]]
					then
						echo $FILENAME,$pathname,$owner,$group,$size_in_bytes,$month $dateval $time_or_year,$file_permissions,$interpreter,$HOST,$CHECKSUM,$SCHEDULE >> $TEMP_FILE
					else
						echo $FILENAME,$pathname,$owner,$group,$size_in_bytes,$month $dateval $time_or_year,$file_permissions,"Unknown",$HOST,$CHECKSUM,$SCHEDULE >> $TEMP_FILE
					fi
	    		else	
	    			echo "$pathname is directory"
	    		fi	
        done < $TMP_CRONTAB

        #
        # Convert the raw data to xml and write it to a new file.
        #
        echo -n Replicating master file in XML format...
        cat "$TEMP_FILE" | csv2xml -h > "$XML_FILE"
        rm -rf "$TEMP_FILE"
        echo Done.
	fi		
fi
