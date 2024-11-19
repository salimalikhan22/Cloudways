#!/bin/bash


if [ $# -eq 0 ]; then
    echo "Usage: $0 <folder1> <folder2> ..."
    exit 1
fi

array=()

#for A in $(ls -l /home/master/applications/| grep "^d" | awk '{print $NF}'); do 
for folder_name in "$@"; do
	app=$folder_name
	echo "Application: $app" 
		cd /home/master/applications/$app/public_html/
		if wp core is-installed; then 
			wp config set DISABLE_WP_CRON true --raw --skip-themes --skip-plugins
			url=$(wp option get siteurl --skip-themes --skip-plugins)
			line=$(cat /home/master/applications/$app/conf/server.nginx)
			domain=$(echo "$line" | grep -oE '[a-zA-Z0-9-]+\.cloudwaysapps\.com' | awk '{print $1}')
			data_json="{\"FQDN\": \"$domain\", \"URL\": \"$url\",\"APPNAME\": \"$app\" }"
			array+=("$data_json")
		fi; 
		json_data="[$(IFS=,; echo "${array[*]}")]"
	
		echo "$json_data" > /home/master/applications/$1/tmp/data.json
done

echo "$(cat /home/master/applications/$1/tmp/data.json)"

