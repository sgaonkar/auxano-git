#!/bin/nsh

###############################################################################
#
# Search Script on the Server
#
# BMC Software, Inc.
#
###############################################################################
#
# This script collects the script information data from the managed servers
# and converts  to an xml format
#
###############################################################################

function getScriptData()
{
	echo "In getScriptData"
	
	if [ -s $LOG_FILE ]
	then
		if [[ ! -f $TEMP_FILE ]]; then
			touch $TEMP_FILE
		fi
		
	    while read line
	    do
	        #read inode_number size_blocks file_permissions number_of_hard_links owner group size_in_bytes month date time_or_year pathname <<<$(IFS=" "; echo $line)
			echo $line | IFS=" " read inode_number size_blocks file_permissions number_of_hard_links owner group size_in_bytes month dateval time_or_year pathname

	    	if [[ ! -z $pathname ]]; then	
				FILENAME=`basename $pathname`
			    FILE_TYPE_STR=`file -b $pathname`
			    
			    echo $FILE_TYPE_STR
				
				#read attribute interpreter type mode <<<$(IFS=" "; echo $FILE_TYPE_STR)
				echo $FILE_TYPE_STR | IFS=" " read attribute interpreter type mode
				echo $attribute
				
				if [[ "$attribute" != "directory" ]]; then
					# Get File Checksum
					CHECKSUM=`md5sum $pathname`
					
					if [[ "$type" = "script" ]]; then
						echo $FILENAME,$pathname,$owner,$group,$size_in_bytes,$month $dateval $time_or_year,$file_permissions,$interpreter,$HOST,$CHECKSUM >> $TEMP_FILE
					else
						echo $FILENAME,$pathname,$owner,$group,$size_in_bytes,$month $dateval $time_or_year,$file_permissions,"Unknown",$HOST,$CHECKSUM >> $TEMP_FILE
					fi
	    		else	
	    			echo "$pathname is directory"
	    		fi	
				
 	        else	
 	           echo "PATHNAME Empty" 
		    fi	
			
		done < $LOG_FILE
	
		# Remove the tmp file	
		rm -rf $LOG_FILE
	fi			
}


#
# Convert the raw data to xml and write it to a new file.
#
function writeOutput() {
	echo "Replicating master file in XML format..."
	if [ -f $TEMP_FILE ]; then
		cat "$TEMP_FILE" | csv2xml -h > "$XML_FILE"
		rm -rf "$TEMP_FILE"
	else 
	    touch "$XML_FILE"	
	fi	
}

##########
#  Main
##########

DIRECTORY_PATHS=$1
EXTENSION_PATTERNS=$2
LOG_FILE=/scripts.txt
TEMP_FILE=/scripts.tmp
XML_FILE=/scripts.xml

if [ -f $XML_FILE ]; then
	rm -rf "$XML_FILE"
fi

HOST=`hostname`
IFS=","
for SEARCH_DIR in $DIRECTORY_PATHS
do	
	echo $SEARCH_DIR
	
	# Split the variable as "path" and "recursive flag"
	IFS=':' read DIR_PATH IS_RECURSIVE <<< $SEARCH_DIR
	
	echo $DIR_PATH
	echo $IS_RECURSIVE
	
	if [ -z "$IS_RECURSIVE" ]; then 
		IS_RECURSIVE="true"; 
	fi
	
	IFS="," read FILE_EXTENSIONS <<< $EXTENSION_PATTERNS
	
	# Check the folder exists
	if [ -d "$DIR_PATH" ]; then
	
		# For each file extension given check the available files in the given file paths
		for FILE_EXTENSION in $FILE_EXTENSIONS
	    do
	    	FILE_EXTENSION=$(echo "$FILE_EXTENSION" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	    	echo "Checking for File Extension $FILE_EXTENSION"
	    	
		    if [ "$IS_RECURSIVE" = "true" ]; then 
		    	echo "Search with recursion"
		    	echo Value find -L $DIR_PATH -name \\$FILE_EXTENSION -ls
		    	find -L $DIR_PATH -name $FILE_EXTENSION -ls > $LOG_FILE 
			else
		    	echo "Search without recursion"
		    	echo value find -L $DIR_PATH -maxdepth 1 -name \\$FILE_EXTENSION -ls 
		    	find -L $DIR_PATH -maxdepth 1 -name $FILE_EXTENSION -ls > $LOG_FILE
			fi;
			
			# Evaluate the script data and write to file
			getScriptData
	    done
	 else
	 	echo  "Directory $DIR_PATH does not exists"  
	 fi  
	    
done		

writeOutput
echo Done.	