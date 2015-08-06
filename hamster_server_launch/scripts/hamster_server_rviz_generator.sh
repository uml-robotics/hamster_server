#!/bin/bash
set +m
shopt -s lastpipe

ROBOTS=$1
shift
RVIZ_ARGS="$@"
RVIZ_CONF=""

for x in $RVIZ_ARGS; do
  if [ -f $x ]; then
    case $x in *.rviz)
     RVIZ_CONF=$x
     break
     ;;
    esac
  fi
done

echo "Git ignoring future local changes to $RVIZ_CONF" 2>&1
echo "To reverse this, run: git upadte-index --no-assume-unchanged $RVIZ_CONF" 2>&1
pushd `dirname $0` > /dev/null
git update-index --assume-unchanged $RVIZ_CONF
popd > /dev/null

echo "Regenerating hamsters.rviz for $ROBOTS robots" 2>&1
echo "NOTE: changes made to robot 1 will propagate to all other robot groups on the next run" 2>&1

PRE_GROUPS=`mktemp`
POST_GROUPS=`mktemp`
TEMPLATE=`mktemp`

IN_GROUP=
FOUND_ROBOT1=
DROP_GROUP=

do_default() {
  [ $DROP_GROUP ] && [ $IN_GROUP ] && return 0
  if [ $IN_GROUP ]; then
    echo "$LINE" >> $TEMPLATE
  else
    if [ -z $FOUND_ROBOT1 ]; then
      echo "$LINE" >> $PRE_GROUPS
    else
      echo "$LINE" >> $POST_GROUPS
    fi
  fi
}

# read the conf file, isolating the following sections:
# 1. everything before the per-agent groups
# 2. everything in Robot1's groups
# 3. everything after ALL per-agent groups
while IFS='' read -r LINE; do
  case $LINE in \ \ \ \ \-\ Class\:\ rviz/Group*)
    if [ ! $FOUND_ROBOT1 ]; then
      echo "$LINE" > $TEMPLATE
    else
      DROP_GROUP=1
    fi
    IN_GROUP=1
    ;;
  *Name\:\ Robot1)
    if [ $IN_GROUP ]; then
      if [ ! $FOUND_ROBOT1 ]; then
        FOUND_ROBOT1=1
        echo "$LINE" >> $TEMPLATE
      fi
    fi
    ;;
  \ \ \ \ \-\ Class\:*)
    IN_GROUP=
    do_default;;
  *) do_default;;
  esac
done < $RVIZ_CONF

#rebuild conf file with $ROBOTS repetitions of appropriately string-replaced templates
cat $PRE_GROUPS > $RVIZ_CONF
for ((r=0; r<$ROBOTS; r++)); do
  R=`expr $r + 1`
  cat $TEMPLATE | sed "s/agent1/agent${R}/g" | sed "s/Robot1/Robot${R}/g" >> $RVIZ_CONF
done
cat $POST_GROUPS >> $RVIZ_CONF

rm -f $PRE_GROUPS $POST_GROUPS $TEMPLATE

rosrun rviz rviz $RVIZ_ARGS
