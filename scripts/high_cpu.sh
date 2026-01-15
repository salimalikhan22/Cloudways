#!/bin/bash
# Purpose: Debug server load and application stats
# Author: Elisha | Cloudways (Modified)
# Last Edited: 15/01/2026

set -e

cd /home/master/applications/ || { echo "Failed to change directory"; exit 1; }

date_to_check=$1
time_in_UTC=$2
interval_in_mins=$3
iv=$4

# Function to fetch stats for a particular time duration
get_stats(){
    dd=$(echo "$date_to_check" | cut -d '/' -f1)
    mm=$(echo "$date_to_check" | cut -d '/' -f2)
    yy=$(echo "$date_to_check" | cut -d '/' -f3)

    date_new="$mm/$dd/$yy"
    time_a="$date_to_check:$time_in_UTC"
    time_b=$(date --date="$date_new $time_in_UTC UTC $interval_in_mins $iv" -u +'%d/%m/%Y:%H:%M')
    time_op=$(echo "$interval_in_mins" | cut -c1-1)

    if [[ "$time_op" = "-" ]]; then
        from_param=$time_b
        until_param=$time_a
    elif [[ "$time_op" = "+" ]]; then
        from_param=$time_a
        until_param=$time_b
    else
        from_param=$time_a
        until_param=$time_b
    fi

    echo "Stats from $(tput setaf 3)$from_param $(tput setaf 7)to $(tput setaf 3)$until_param $(tput setaf 7)"
    top_five=$(for i in $(ls -l | grep -v ^l | awk '{print $NF}' | awk 'FNR > 1'); do
        count=$(sudo apm -s "$i" traffic --statuses -f "$from_param" -u "$until_param" -j \
                | grep -Po "\d..\",\d*" | cut -d ',' -f2 | head -n1)
        echo "$i:$count"
    done | sort -k2 -nr -t ":" | cut -d : -f1 | head -n 10)

    for A in $top_five; do
        echo $'\n'DB: $(tput setaf 3)$A $(tput setaf 7)
        cat "$A/conf/server.nginx" | awk '{print $NF}' | head -n1
        sudo apm -s "$A" traffic -n5 -f "$from_param" -u "$until_param"
        sudo apm -s "$A" mysql -n5 -f "$from_param" -u "$until_param"
        sudo apm -s "$A" php -n5 --slow_pages -f "$from_param" -u "$until_param"
    done
}

# Main execution logic
if [ -z "$date_to_check" ] && [ -z "$time_in_UTC" ] && [ -z "$interval_in_mins" ] && [ -z "$iv" ]; then
    read -p 'Enter duration: ' dur
    echo "Fetching logs for the last $(tput setaf 1)$dur$(tput setaf 7) ..."
    top_five=$(for i in $(ls -l | grep -v ^l | awk '{print $NF}' | awk 'FNR > 1'); do
        count=$(sudo apm -s "$i" traffic --statuses -l "$dur" -j \
                | grep -Po "\d..\",\d*" | cut -d ',' -f2 | head -n1)
        echo "$i:$count"
    done | sort -k2 -nr -t ":" | cut -d : -f 1 | head -n 10)

    for A in $top_five; do
        echo $'\n'DB: $(tput setaf 3)$A $(tput setaf 7)
        cat "$A/conf/server.nginx" | awk '{print $NF}' | head -n1
        sudo apm traffic -s "$A" -l "$dur" -n5
        sudo apm mysql -s "$A" -l "$dur" -n5
        sudo apm php -s "$A" --slow_pages -l "$dur" -n5

        slow_plugins=$(cat "/home/master/applications/$A/logs/php-app.slow.log" 2>/dev/null \
                        | grep -ai 'wp-content/plugins' \
                        | cut -d " " -f2- \
                        | cut -d '/' -f8 \
                        | sort | uniq -c | sort -nr)

        if [ -n "$slow_plugins" ]; then
            echo $'\n'$(tput setaf 1) "--- Slow plugins ---" $(tput setaf 7)$'\n'
            echo "$slow_plugins"
            echo $'\n'$(tput setaf 1) "--------------------" $(tput setaf 7)
        fi
    done

else
    [ -z "$iv" ] && iv="min"
    get_stats
fi

# Additional logs checks
echo $'\n'"Checking for OOM kills in syslog..."
grep oom-kill /var/log/syslog || echo "No OOM kills found"

echo $'\n'"Checking PHP-FPM logs for max_children..."
for php_log in /var/log/php*.log /var/log/php*.*-fpm.log; do
    [ -f "$php_log" ] && echo "=== $php_log ===" && grep -i max_children "$php_log" || true
done

exit 0
