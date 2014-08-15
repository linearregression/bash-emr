# 
# you must have the AWS Universal CLI installed 
# you must set EMR_HOME to point to the directory that has your credentials file
#
export PATH=$EMR_HOME:$PATH
export AWS_DEFAULT_OUTPUT="table"

[ -z "$EMR_CRED_JSON" ] && EMR_CRED_JSON=$EMR_HOME/credentials.json

if [ ! -f $EMR_CRED_JSON ];then
  echo "Credentias at $EMR_CRED_JSON do not exist!"
else
  echo "Using EMR credentials: $EMR_CRED_JSON"
fi

# EMR helpers
export EMR_SSH_KEY=`cat $EMR_CRED_JSON | grep '"key-pair-file"' | cut -d':' -f2 | sed -n 's|.*"\([^"]*\)".*|\1|p'`
export EMR_SSH_KEY_NAME=`cat $EMR_CRED_JSON | grep '"key-pair"' | cut -d':' -f2 | sed -n 's|.*"\([^"]*\)".*|\1|p'`

export EMR_SSH_OPTS="-i "$EMR_SSH_KEY" -o StrictHostKeyChecking=no -o ServerAliveInterval=30"

export ELASTIC_MAPREDUCE_CREDENTIALS=$EMR_CRED_JSON

function emr {
  RESULT=`aws  emr $*`
  ID=`echo "$RESULT" | head -1 | sed -n 's|^Cr.*\(j-[^ ]*\)$|\1|p'`
  
  [ -n "$ID" ] && export EMR_FLOW_ID="$ID"
  
  echo "$RESULT"
}

function emrset {
  if [ -z "$1" ]; then
    echo $EMR_FLOW_ID
  else
    export EMR_FLOW_ID=$1
  fi
}

function flowid {
  if [ -z "$EMR_FLOW_ID" ]; then
    echo "$1"
  else
    echo "$EMR_FLOW_ID"
  fi
}

function emrhost {
  if [[ $1 =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$ ]]; then
   echo $1
   return
  fi
    
  FLOW_ID=`flowid $1`
  unset H
  while [ -z "$H" ]; do
   H=`emr describe-cluster --cluster-id $FLOW_ID  --query [Cluster.MasterPublicDnsName] --output text`
   sleep 5
  done
  echo $H
}

function emrscreen {
 HOST=`emrhost $1`
 ssh $EMR_SSH_OPTS -t "hadoop@$HOST" 'screen -s -$SHELL -D -R'
}

function emrtail {
  if [ -z "$1" ]; then
    echo "Must provide step number to tail!"
    HOST=`emrhost $HH`
    ssh $EMR_SSH_OPTS -t "hadoop@$HOST" "ls -1 /mnt/var/log/hadoop/steps/"
    return
  fi
      
  if [ $# == 2 ]; then
    HH=$1
    STEP=$2
  else
    HH=""
    STEP=$1
  fi   
  HOST=`emrhost $HH`
  ssh $EMR_SSH_OPTS -t "hadoop@$HOST" "tail -100f /mnt/var/log/hadoop/steps/$STEP/syslog"
}

function emrlogin {
 HOST=`emrhost $1`
 ssh $EMR_SSH_OPTS "hadoop@$HOST"
}
 
function emrproxy {
 HOST=`emrhost $1`
 echo "ResourceManager: http://$HOST:9026"
 echo "NameNode  : http://$HOST:9101"
 echo "HUE  : http://$HOST:8080"
 echo "PRESTO  : http://$HOST:8888"
 ssh $EMR_SSH_OPTS -D 6666 -N "hadoop@$HOST"
}

function emrlist {
 emr list-clusters --query Clusters[*].[Id,Name,Status.State] 
}

function emractive {
 emr list-clusters --query Clusters[*].[Id,Name,Status.State] --active 
}

function emrstat {
 FLOW_ID=`flowid $1`
 emr describe-cluster --cluster-id $FLOW_ID  --query [Cluster.Name,Cluster.MasterPublicDnsName,Cluster.Status.State,Cluster.Status.StateChangeReason.Message]
}

function emrterminate {
 FLOW_ID=`flowid $1`
 emr terminate-clusters --cluster-ids $FLOW_ID
 export EMR_FLOW_ID=""
}

function emrscp {
 HOST=`emrhost`
 scp $EMR_SSH_OPTS $1 "hadoop@$HOST:"
}

function emrconf {
  if [ -z "$1" ]; then
    echo "Must provide target directory to place files!"
    return
  fi
      
  if [ $# == 2 ]; then
    HH=$1
    CONFPATH=$2
  else
    HH=""
    CONFPATH=$1
  fi   
  HOST=`emrhost $HH`
  scp $EMR_SSH_OPTS "hadoop@$HOST:conf/*-site.xml" $CONFPATH/
}



