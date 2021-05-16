#!/bin/bash

# Usage of kvv.sh
# 	Find StopID: 			 ./kvv.sh find 'Bruchsal Gewerbl. Bildungsz.'
# 	Stop Departure: 		 ./kvv.sh departure 'de:8215:1855'
# 	Stop Direction Departure: 	 ./kvv.sh departure 'de:8215:1855' 'Karlsruhe'

#########

DEBUG=false
MAX_DEPARTURE_ITEMS="1"

API_KEY="377d840e54b59adbe53608ba1aad70e8"
API_BASE="https://live.kvv.de/webapp"

####### FUNCTIONS: GET STOP ID

urlencode() {
    # urlencode <string>

    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:$i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done

    LC_COLLATE=$old_lc_collate
}

jsonPretty(){

	echo "$1" #| grep -Eo '"[^"]*" *(: *([0-9]*|"[^"]*")[^{}\["]*|,)?|[^"\]\[\}\{]*|\{|\},?|\[|\],?|[0-9 ]*,?' | awk '{if ($0 ~ /^[}\]]/ ) offset-=4; printf "%*c%s\n", offset, " ", $0; if ($0 ~ /^[{\[]/) offset+=4}'
}

getStopQueryUrl() {

	local URL="$API_BASE/stops/byname/$1?key=$API_KEY"
	echo "$URL"
}

extractAndCheckStopId() {

	local STOP_ID_EXTRACT_REGEX="\"id\":\"(.*)\",\"name\":\"(.*)\",\"lat\""


	if $DEBUG
	then

		echo "DEBUG: Checking <$STOP_ID_EXTRACT_REGEX> against <$1>"

	fi



    [[ "$1" =~ $STOP_ID_EXTRACT_REGEX ]]
    
    local REGEX_RESULT_STOP_NAME="${BASH_REMATCH[2]}"
    local REGEX_RESULT_STOP_ID="${BASH_REMATCH[1]}"

    if [ "$2" == "$REGEX_RESULT_STOP_NAME" ]
    then    

      echo "$REGEX_RESULT_STOP_ID"

    else
      echo "ERROR: Lookup for <$2> does not match <$REGEX_RESULT_STOP_NAME> for Stop ID <$REGEX_RESULT_STOP_ID>"
      echo "INFO: Exiting"
      exit 1    

    fi
}

getStopResultJsonByName() {

	local STOP_NAME_URLENCODED=$(urlencode "$1")

	if $DEBUG
	then

		echo "DEBUG: Encoded stop name <$1> to <$STOP_NAME_URLENCODED>"

	fi



	local STOP_LOOKUP_URL=$(getStopQueryUrl "$STOP_NAME_URLENCODED")

	if $DEBUG
	then

		echo "DEBUG: Using stop name <$STOP_NAME_URLENCODED> ID lookup url: <$STOP_LOOKUP_URL>"

	fi

	local ID_BY_NAME_RESPONSE="$(curl -s $STOP_LOOKUP_URL)"
	echo "$ID_BY_NAME_RESPONSE"
}

queryStop(){
	
	local STOP_QUERY_RESPONSE=$(getStopResultJsonByName "$1")
	local STOP_QUERY_RESPONSE_PRETTY=$(jsonPretty "$STOP_QUERY_RESPONSE")
	echo "$STOP_QUERY_RESPONSE_PRETTY"
}

getStopIdByName() {

	local ID_BY_NAME_RESPONSE=$(getStopResultJsonByName "$1")

	if $DEBUG
	then

		echo "DEBUG: ID by Name Response BEGIN"
		echo ""
		echo $ID_BY_NAME_RESPONSE
		echo ""
		echo "DEBUG: ID by Name Response END"
	fi



	local RESULT=$(extractAndCheckStopId "$ID_BY_NAME_RESPONSE" "$1")
	echo "$RESULT"
}

####### FUNCTIONS: GET STOP INFORMATION VIA ID

getStopDepartureInfoUrl() {

	local URL="$API_BASE/departures/bystop/$1?maxInfos=$2&key=$API_KEY"
	echo "$URL"
}

getDepartureByStopId(){

	local URL=$(getStopDepartureInfoUrl "$1" "2")
	local RESPONSE=$(curl -s $URL)

	echo "$RESPONSE"
}

getDepartureByStopName(){

	local STOP_ID=$(getStopIdByName "$1")
	
	local DEPARTURE_INFO_RESPONSE_JSON=$(getDepartureByStopId "$STOP_ID" "$2")

	echo "$DEPARTURE_INFO_RESPONSE_JSON"
}

####### FUNCTIONS: GET STOP INFORMATION VIA ID AND LINE ID

getStopAndLineDepartureInfoUrl() {

	local URL="$API_BASE/departures/byroute/$2/$1?maxInfos=$3&key=$API_KEY"
	echo "$URL"
}

getDepartureByStopIdAndLine(){

	local URL=$(getStopAndLineDepartureInfoUrl "$1" "$2" "$3")

	local RESPONSE=$(curl -s $URL)

	echo "$RESPONSE"
}

getDepartureByStopNameAndLine(){

	local STOP_ID=$(getStopIdByName "$1")
	
	local DEPARTURE_INFO_RESPONSE_JSON=$(getDepartureByStopIdAndLine "$STOP_ID" "$2" "$3")

	echo "$DEPARTURE_INFO_RESPONSE_JSON"
}

getNextDepartureForDestination(){


			local TIME_BY_DESTINATION_REGEX='"destination":"([a-zA-Z0-9 ]+)","direction":"([0-9])","time":"([0-9]+:[0-9]+|[0-9]+ min)"'


			local msg_departure="$1"

			while [[ "$msg_departure" =~ $TIME_BY_DESTINATION_REGEX ]]; do

				DESTINATION="${BASH_REMATCH[1]}"
								
				if [ "$DESTINATION" = "$2" ]; then

					DEPARTURE_TIME="${BASH_REMATCH[3]}"

					
					if [ -z "$DEPARTURE_TIME" ]
					then
					      echo "NO KVV DATA"
					else
					      echo $DEPARTURE_TIME
					fi

					break

				fi

		        msg_departure=${msg_departure/"${BASH_REMATCH[0]}"/}

			done
}

printCmdInfo(){
	echo -e "\n"
	echo -e "Usage of kvv.sh"
	echo -e "\tFind StopID: \t\t\t ./kvv.sh find 'Bruchsal Gewerbl. Bildungsz.'"
	echo -e "\tStop Departure: \t\t ./kvv.sh departure 'de:8215:1855'"
	echo -e "\tStop Direction Departure: \t ./kvv.sh departure 'de:8215:1855' 'Karlsruhe'"
}

if (( $# == 2 )); then


	if [ "$1" = "find" ]; then
    		
    		#./kvvinfo find 'Bruchsal Gewerbl. Bildungsz.'
    		
    		QUERY_TERM="$2"
    		STOP_QUERY_RESULT=$(queryStop "$QUERY_TERM")
    		RESULT_PRETTY=$(jsonPretty "$STOP_QUERY_RESULT")

			echo "$STOP_QUERY_RESULT"
			exit 0


	elif [ "$1" = "departure" ]; then
    		
    		#./kvvinfo departure 'de:8215:1855'

    		STOP_ID="$2"
    		DEPARTURE_BY_STOP_ID=$(getDepartureByStopId "$STOP_ID")
    		RESULT_PRETTY=$(jsonPretty "$DEPARTURE_BY_STOP_ID")

			echo "$RESULT_PRETTY"
			exit 0
	else

		echo "ERROR: $1 unknown value"
		printCmdInfo

		exit 0

	fi

elif (( $# == 3 )); then

	if [ "$1" = "departure" ]; then
    		
    		#./kvvinfo departure 'de:8215:1855' 'Karlsruhe'

    		STOP_ID="$2"
    		TRAIN_DESTINATION="$3"
    		DEPARTURE_BY_STOP_ID=$(getDepartureByStopId "$STOP_ID")
    		DEPARTURE_BY_STOP_ID_IN_DIRECTION=$(getNextDepartureForDestination "$DEPARTURE_BY_STOP_ID" "$TRAIN_DESTINATION")
    	

			echo "$DEPARTURE_BY_STOP_ID_IN_DIRECTION"
			exit 0
	else

		echo "ERROR: $1 unknown"
		printCmdInfo

		exit 0

	fi

else

	echo "ERROR: Invalid parameters"
	printCmdInfo

	exit 1

fi
