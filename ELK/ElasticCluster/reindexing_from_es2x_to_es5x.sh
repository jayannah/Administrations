#!/bin/bash


captureCounts() {
  index=$1
  wtype=$2
  count=`curl -u admin_user:Watcher_admin -XGET http://query-watcher-east.kdc.domain.com:9200/$index*/$wtype/_count?pretty -H 'Content-Type: application
/json' -d'
  {
      "query": {
          "match_all": {}
      }
  }' | grep count | awk '{print $3}'| sed 's/.\{1\}$//'`

  echo `date +"%Y-%m-%d.%H.%M.%S"`";"$index";"$count

  echo `date +"%Y-%m-%d.%H.%M.%S"`";"$index";"$count >> watcher_count.txt
}



getWatcherMapping() {

  #This is only required if we don't have the cross reference file for Watcher indices and document-type

  curl -u admin_user:Watcher_admin -XGET 'http://query-watcher-east.kdc.domain.com:9200/'$1'/_mapping?pretty' 2> /dev/null | jq '[.[keys[] | select(cont
ains("$em_index_prefix-"))]]' >> $em_index_prefix.json

}

applyMapping() {


  if [ -z $1 ];then
    echo "error: no input file provided. Usage: $0, index file"
    return 1
  fi

  em_index_prefix=$1

  #Not required since the index file now contains only prefix
  #em_index_prefix=$(echo $em_index | awk -F "-" '{print $1}')

  em_index=$em_index_prefix"-2017.10.21"
  emValidation=$em_index_prefix"_validation.json"
  emJson=$em_index_prefix".json"

  echo "Getting the mapping for index:" $em_index

  curl -u readonly:read1234 -XGET 'http://elasticco-pe.cloud.domain.com/'$em_index'/_mapping?pretty'  | sed '$d' | sed '2d' > $emJson

  #curl  -u watcher:Horses22  -XGET 'http://elasticco-pe.cloud.domain.com/'$1'/_mapping?pretty' 2> /dev/null >> $em_index_prefix.json

  #Just make sure that this is not an empty/dummy file and it does contain mapping text.

  cat $emJson | grep 'mappings'

  #if [[  $(cat $em_index_prefix.json | grep 'mappings' | wc -m)  -gt 8 ]]; then
  if [ $? -eq 0 ]; then
     echo "success getting Mapping from EM Prod Index - " $em_index
  else
    echo "ERROR: Getting Mapping from EM Prod Index - " $em_index " -validation file - " $emJson
    return 1
  fi

  #Create the Mapping in EM-Stage
  curl -u elastic:changeme -XPUT 'http://watcherstage-e-es-co.cloud.domain.com:80/'$em_index_prefix'-2017?pretty' -H 'Content-Type: application/json' -d
 @$emJson > $em_index_prefix.log


  echo "Validation result. Press to continue or Ctrl+D to stop"
  read continueprogress


  #Get the index from the staging, and validate that it worked
  curl -u readonly:read1234 -XGET 'http://watcherstage-e-es-co.cloud.domain.com:80/'$em_index_prefix'-2017/_mapping?pretty' | sed '$d' | sed '2d' > $emV
alidation

  #TODO :Do the Diff of the files from $em_index_prefix.error  && $em_index_prefix_validation.json
  #cat "$em_index_prefix"_validation.json | grep 'mappings'

  diff $emValidation $emJson

  #if [[  $(cat $em_index_prefix.json | grep 'mappings' | wc -m)  -gt 8 ]]; then
  if [ $? -eq 0 ]; then
  #if [[  $(cat $em_index_prefix_validation.json | grep 'mappings' | wc -m ) -gt 8 ]]; then
    echo `date +"%Y-%m-%d.%H.%M.%S"` "SUCCESS: Mapping Validation for - " $em_index " -validation file - " $em_index_prefix "_validation.json"
        echo `date +"%Y-%m-%d.%H.%M.%S"` "SUCCESS: Mapping Validation for - " $em_index " -validation file - " $em_index_prefix "_validation.json" >> $em_in
dex_prefix.log
  else
    echo "ERROR: Mapping validation for - " $em_index " -validation file - " $em_index_prefix "_validation.json"
    exit 1
  fi
  #exit 1
  #return 0

}


runreindex(){

 echo "In the function - runreindex - $1 : $2 : $3: $4"

 if [ $# -ne 4 ]; then
   echo "runreindex - incorrect # of parameters passed"
   return 1
 fi

 echo "reindexing starting"

  #Step -1: Get the count from watcher and write to a file
  curl -u elastic:changeme -o $3_curl.log  -XPOST 'http://watcherstage-e-es-co.cloud.domain.com:80/_reindex?pretty' -H 'Content-Type: application/json'
-d'
  {
  "source": {
    "remote": {
      "host": "http://10.200.126.229:9200",
      "username": "user",
      "password": "Watcher_user"
    },
    "index": "'$1'*",
    "type": "'$2'"
    },
  "dest": {
    "index": "'$3'-2017",
     "type": "'$4'"
  }
  }
  '

  #status="$(cat $3_curl.log  | jq '.failures | length')"

  #the length of failures should be 0.
  #if [ "$status" -ne 0 ]; then
  #  echo "Non-zero status to mark success and break from the loop from the main program"
  #  #return 1
  #fi

  # This is to get the length of the root cause
  #cat $3.log  |  jq '.error.root_cause | length'

  # This is to get the length of the root cause
  #cat $3.log  |  jq '.error.root_cause | length'


  #TODO: If time permits - Check that the index got created after sometime ... http://watcherstage-e-es-co.cloud.domain.com/_cat/indices

  #return 0

}

echo "=================================================================================================================="
echo "Start - Executing Reindex Script - $0"


if [ -z "$1" ];then
  echo "ERROR : no input file provided. Usage: $0 indexfile"
  exit 1
fi

XRefFile=$1

#Check if the index file exists
if [ ! -f "$XRefFile" ]; then
  echo "Index file - $XRefFile does not exist."
  exit 1
fi

XRefFile=$1
watcherindex=""
mainPath=`pwd`
#Iterate through each line in the file and call the method for reindexing
for i in `cat $XRefFile`
  do
   cd $mainPath
   watcherindex="$( echo $i | cut -d','  -f1)"
   watcherdocument="$( echo $i | cut -d','  -f2)"
   EMindex="$( echo $i | cut -d','  -f3)"
   EMtype="$( echo $i | cut -d','  -f3)"  #Making Column #3 for EM index name and document_type
   #EMtype="$( echo $i | cut -d','  -f4)"

  echo "Request for Reindex for FROM_Index:" $watcherindex " FROM_Type:" $watcherdocument "TO_Index:" $EMindex  "TO_Type:" $EMtype >> logreindex.log

  echo "Request for Reindex for FROM_Index:" $watcherindex " FROM_Type:" $watcherdocument "TO_Index:" $EMindex  "TO_Type:" $EMtype
  read confirm
  mkdir $EMindex
  cd $EMindex
  #Capture the counts
  captureCounts $watcherindex $watcherdocument

  #Get the mapping from the EM Prod and apply to EM Stage
  applyMapping $EMindex
  #exit 1

  #echo $mappingstatus

  #if [ "$mappingstatus" -ne 0 ]; then
  #    echo "ERROR: Mapping Failure - " $EMindex
  ##    exit 1
  #fi

  #Calling thre reindex method
  #reindexStatus=`runreindex $watcherindex $watcherdocument $EMindex $EMtype`
  runreindex $watcherindex $watcherdocument $EMindex $EMtype
  echo `date +"%Y-%m-%d.%H.%M.%S"` "SUCCESS: Reindexing for FROM_Index:" $watcherindex " FROM_Type:" $watcherdocument "TO_Index:" $EMindex  "TO_Type:" $EMty
pe >> logreindex.log
  echo `date +"%Y-%m-%d.%H.%M.%S"` "SUCCESS: Reindexing for FROM_Index:" $watcherindex " FROM_Type:" $watcherdocument "TO_Index:" $EMindex  "TO_Type:" $EMty
pe
  #echo $reindexStatus


  #if [ "$reindexStatus" -eq 0 ]
  #then
  #  echo "SUCCESS: Reindexing for FROM_Index:" $watcherindex " FROM_Type:" $watcherdocument "TO_Index:" $EMindex  "TO_Type:" $EMtype >> logreindex.log
  #else
  #  echo "ERROR: Reindexing for FROM_Index:" $watcherindex " FROM_Type:" $watcherdocument "TO_Index:" $EMindex  "TO_Type:" $EMtype >> logreindex.log
  #  exit 1
  #fi
done

echo ==================================THE END ========================================
