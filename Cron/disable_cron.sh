#!/bin/bash

all_option=false
list_option=""
file_option=""
path=$(pwd)
array=()
token=""
token_provided=false


while getopts ":al:f:t:" opt; do
  case $opt in
    a)
      all_option=true
      ;;
    l)
      list_option="$OPTARG"
      ;;
    f)
      file_option="$OPTARG"
      ;; 
      t)
      token="$OPTARG"
      token_provided=true
      ;; 
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1	
      ;;
  esac
done


if [ "$token_provided" = true ]; then
  if [ "$all_option" = false ] && [ -z "$list_option" ] && [ -z "$file_option" ]; then
	  current_dir=$(pwd)
  if [[ $current_dir == *"/home/master/applications/"* ]]; then
  # Extract the folder name after "/home/master/applications/"
 
folder_name=$(echo "$current_dir" | awk -F"/home/master/applications/" '{print $2}' | cut -d'/' -f1)
list_option=$folder_name
  
# Continue with your script logic here
else
  echo "Error: Not inside the expected folder structure."
echo "You have to run the script under any application"
  exit 1  # Exit with an error code
fi

  
  fi
else
	echo "Token is not passed"
	exit 1
fi



if [ "$all_option" = true ]; then
  echo "Running with --all option."
list_option=""
file_option=""
  
for A in $(ls -l /home/master/applications/| grep "^d" | awk '{print $NF}'); do
	cd /home/master/applications
	echo "Application: $A"
	if [ -d "$A" ] && [ ! -L "$A" ]; then
	
	cd $A/public_html/
	if [ -f "wp-config.php" ];then

	if wp core is-installed; then
		wp config set DISABLE_WP_CRON true --raw --skip-plugins --skip-themes
		url=$(wp option get siteurl --skip-themes --skip-plugins)
		line=$(head -n 1 /home/master/applications/$A/conf/server.nginx)
		domain=$(echo "$line" | grep -oE '[a-zA-Z0-9-]+\.cloudwaysapps\.com' | awk '{print $1}')
		json_data="{\"FQDN\": \"$domain\", \"URL\": \"$url\",\"APPNAME\": \"$A\" }"
		array+=("$json_data")
		json_data="[$(IFS=,; echo "${array[*]}")]"

		echo "$json_data" > $path/data.json

	fi	
	else
	echo "Application $dbname is not the wordpress application"
	fi
	fi
	done
	cd $path
	echo "$(cat $path/data.json)"
fi

if [ -n "$list_option" ]; then
  echo "Running with --list option: $list_option"

file_option=""

# Set the IFS to ',' to split the string
IFS=','

# Iterate through the characters
for dbname in $list_option; do
  # Remove any leading or trailing whitespace
  cd /home/master/applications
  dbname=$(echo "$dbname" | tr -d '[:space:]')
  if [ -d "$dbname" ] && [ ! -L "$dbname" ]; then
  # Your code for each character here
  echo "Processing Application: $dbname"
		cd /home/master/applications/$dbname/public_html/
			if [ -f "wp-config.php" ];then
		if wp core is-installed; then 
			wp config set DISABLE_WP_CRON true --raw --skip-themes --skip-plugins
			url=$(wp option get siteurl --skip-themes --skip-plugins)
			line=$(head -n 1 /home/master/applications/$dbname/conf/server.nginx)
			domain=$(echo "$line" | grep -oE '[a-zA-Z0-9-]+\.cloudwaysapps\.com' | awk '{print $1}')
			data_json="{\"FQDN\": \"$domain\", \"URL\": \"$url\",\"APPNAME\": \"$dbname\" }"
			array+=("$data_json")
		fi; 
		json_data="[$(IFS=,; echo "${array[*]}")]"
	
		echo "$json_data" > $path/data.json
			else
	echo "Application $dbname is not the wordpress application"
		fi;
	
		fi
	done
cd $path
echo "$(cat $path/data.json)"


# Reset IFS to its default value (space, tab, newline)
IFS=$' \t\n'
		
fi

if [ -n "$file_option" ]; then
  echo "Running with --file option: $file_option"

# Check if the file exists
if [ -f "$file_option" ]; then
  # Read each line from the file
 
  while read -r line; do
   
 # Remove newline characters and any leading/trailing whitespace
    dbname=$(echo "$line" | tr -d '\n' | tr -d '[:space:]')
    cd /home/master/applications
    # Print the cleaned line (or you can perform other actions)
  echo "Processing Application: $dbname"
		if [ -d "$dbname" ] && [ ! -L "$dbname" ]; then
echo "$dbname"
			cd /home/master/applications/$dbname/public_html/
			if [ -f "wp-config.php" ];then
			if wp core is-installed; then 
			wp config set DISABLE_WP_CRON true --raw --skip-themes --skip-plugins
			url=$(wp option get siteurl --skip-themes --skip-plugins)
			line=$(head -n 1 /home/master/applications/$dbname/conf/server.nginx)
			domain=$(echo "$line" | grep -oE '[a-zA-Z0-9-]+\.cloudwaysapps\.com' | awk '{print $1}')
			data_json="{\"FQDN\": \"$domain\", \"URL\": \"$url\",\"APPNAME\": \"$dbname\" }"
			array+=("$data_json")
		fi; 
		json_data="[$(IFS=,; echo "${array[*]}")]"
	
		echo "$json_data" > $path/data.json
	else
	echo "Application $dbname is not the wordpress application"
		fi
	fi
done < "$file_option"

	cd $path
	echo "$(cat $path/data.json)"

else
  echo "File not found: $file_option"
fi

fi



############################################### PYTHON ############################################################################


python3 << END
import sys
import json
import re
import requests
import ast

#####################################################TOKEN SAVED IN A VARIABLE ################################################
token="$token"
sys.stdout.flush()

#if token == "":
#	raise ValueError("Invalid input")

##################################################### READING OF DATA.JSON FILE ################################################

with open('data.json', 'r') as file:
    json_data = json.load(file)

# Define a list to store the modified objects
modified_objects = []

# Iterate over the JSON objects
for item in json_data:
    FQDN = item['FQDN']
    URL = item['URL']
    AppName = item['APPNAME']
    # Extract app_id and server_id from FQDN
    server_id = FQDN.split('-')[1]
    app_id = FQDN.split('-')[2].split('.')[0]

    # Create a new JSON object with app_id, server_id, and URL
    new_object = {
        'app_id': app_id,
        'server_id': server_id,
        'FQDN': FQDN,
        'URL': URL,
        'APPNAME' : AppName
        
    }

    # Append the modified object to the list
    modified_objects.append(new_object)

############################### SAVED NEW OBJECT IN DATA JSON FILE WHICH NOW ALSO CONTAINS SERVER ID AND APP ID ###############################

# Save the modified objects back to data.json
with open('data.json', 'w') as file:
    json.dump(modified_objects, file, indent=4)

######################## INITIATING GET REQUEST TO EXTRACT ALREADY EXISTED CRON AND EXECUTE LOOP TO ITERATE OVER ALL THE APPS USING DATA.JSON FILE ######################

# Read JSON data from the data.json file
with open('data.json', 'r') as file:
    data = json.load(file)

# Iterate over the list of JSON objects
for json_object in data:
    # Work on one JSON object at a time
    server_id=json_object["server_id"]
    app_id=json_object["app_id"]
    url=json_object["URL"]
    appname = json_object["APPNAME"]
    # Construct the URL with variables
    url_with_params = f"https://api.cloudways.com/api/v1/app/manage/cronList?server_id={server_id}&app_id={app_id}"

    headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/json"
    }

# Send the GET request
    response = requests.get(url_with_params, headers=headers)

# Check the response
    if response.status_code == 200:
        # Request was successful, process the response here
      data = response.json()
      print("Successfully Get the Cron for App ID: {}, Appname: {}".format(app_id,appname))
    else:
        # Request failed
	    print("Failed to Get the Cron for App ID: {}, Appname: {}".format(app_id,appname))
	    print(response.json)
	    exit(1)
######################################### GET REQUEST ENDED ADN THE RESPONSE IS SAVED IN A VARIABLE AS STRING ##########################################################
    response_str = str(response.json()) 

######################################## ALTERATION OF THE STRING TO ONLY GET THE RESIRED PART ##################################################

# Extract the 'script' part from the response
    response_dict = ast.literal_eval(response_str)  # Convert the string to a dictionary
    script_part = response_dict.get('script')  # Get the 'script' value or an empty string if not found

# Split the 'script' part into a list of lines
#   script_lines = script_part.split('\n')
    script_lines = [line.strip() for line in script_part.split('\n') if line.strip()]
# Append the additional string to the end of the list
    additional_string = "*/5 * * * * wget -q -O - '{url}/wp-cron.php?doing_wp_cron' >/dev/null 2>&1"
    string_to_check='{url}/wp-cron.php'
    additional_string=additional_string.replace("{url}", url)
    string_to_check=string_to_check.replace("{url}", url)

###################################### CONDITION TO CHECK IF CRON ALREADY EXISTS OR NOT IF IT EXISTS THEN DO NOT ADD CRON #######################################
    exists = False
    for strings in script_lines:
        if string_to_check in strings:
            exists=True
            break

    if not exists:
        script_lines.append(additional_string)
# Print the formatted list of script lines
    
        request_url = "https://api.cloudways.com/api/v1/app/manage/cronList"

# Define headers
        headers = {
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
          }

        crons = json.dumps(script_lines)

# Define the data payload
        data = {
            "server_id": server_id,
            "app_id": app_id,
            "crons": crons,
            "is_script": "True",
          }

# Send the POST request
        response = requests.post(request_url, headers=headers, data=data)

# Check the response
        if response.status_code == 200:
        # Request was successful, process the response here
          data = response.json()
          print("Response:", data)
          print("Successfully Added the Cron for App ID: {}, Appname: {}".format(app_id, appname))
        else:
        # Request failed
	        print("Failed to add the Cron for App ID: {}, Appname: {}".format(app_id, appname))
	        print(response.json)
	        exit(1)
    else:
        print("Cron already Exists")


END
