#!/bin/bash

#set -e

powered_by() {
local var
var='
 _____     _                
|  ___|_ _(_)______ _ _ __  
| |_ / _` | |_  / _` | `_ \ 
|  _| (_| | |/ / (_| | | | |
|_|  \__,_|_/___\__,_|_| |_|

'

cat <<EOF
$var
Author: faizan 
EOF
}

Usage() {

  cat >&2 <<EOF

./helper.sh [OPTIONS]

    Options:
        --webp                                  	Configure the server to serve webp images
        --allow-cloudflare                      	Configure nginx to allow only traffic from Cloudflare
        --install-node                          	Install the specified version of node
	--npm-package					Install any npm package (yarn, pm2 etc) and configure master user
        --version                               	Display version of this script
        -h , --help                             	Display this help and exit
    Examples:
	./helper.sh --webp [app1] [app2]		[Install and configure webp on multiple applications]
        ./helper.sh --allow-cloudflare [app1]		[Allow traffic from Cloudflare only]        
        ./helper.sh --install-node 14.16.0		[Install Specified node version]						
	./helper.sh --npm-package [package-name]	[Install the specified npm package and configure master user]
EOF

powered_by
}

_bold=$(tput bold)
_underline=$(tput sgr 0 1)
_reset=$(tput sgr0)

_purple=$(tput setaf 171)
_red=$(tput setaf 1)
_green=$(tput setaf 76)
_tan=$(tput setaf 3)
_blue=$(tput setaf 38)

function _header()
{
    printf '\n%s%s==========  %s  ==========%s\n' "$_bold" "$_purple" "$@" "$_reset"
}

function _arrow()
{
    printf '➜ %s\n' "$@"
}

function _success()
{
    printf '%s✔ %s%s\n' "$_green" "$@" "$_reset"
}

function _error() {
    printf '%s✖ %s%s\n' "$_red" "$@" "$_reset"
}

function _warning()
{
    printf '%s➜ %s%s\n' "$_tan" "$@" "$_reset"
}

function _underline()
{
    printf '%s%s%s%s\n' "$_underline" "$_bold" "$@" "$_reset"
}

function _bold()
{
    printf '%s%s%s\n' "$_bold" "$@" "$_reset"
}

function _note()
{
    printf '%s%s%sNote:%s %s%s%s\n' "$_underline" "$_bold" "$_blue" "$_reset" "$_blue" "$@" "$_reset"
}


ARGS=( "$@" )

#for ARG in ${ARGS[@]}; do
#	echo $ARG
#done

webp_configure() {

    if [[ -z "${ARGS[@]:1}" ]]; then
        _error "Missing argument.. See --help or -h for Usage"
        exit
    else
        _bold "Installing webp"
        apt-get update >> /dev/null 2<&1
        apt-get install -y webp >> /dev/null 2<&1

        if [ "$?" == 0 ]; then
            _success "Webp installed successfully"
        fi

        for ARG in "${ARGS[@]:1}"; do
	    webroot="$(awk '/DocumentRoot/ {print $2}' /etc/apache2/sites-available/${ARG}.conf)"
            _note "Removing extensions from $ARG"
            sed -r -i 's/\b(jpg\||jpeg\||png\|)\b//g' /etc/nginx/sites-available/$ARG
	    
#	    _note "Adding .htaccess rules"
#  	    find ${webroot} -maxdepth -1 -type f -name ".htaccess" | xargs sed -i '1s#^#<IfModule mod_rewrite.c>\nRewriteEngine On\nRewriteCond %{HTTP_ACCEPT} image/webp\nRewriteCond %{REQUEST_FILENAME} (.*)\.(jpe?g|png)$\nRewriteCond %{REQUEST_FILENAME}.webp -f\nRewriteRule (.+)\.(jpe?g|png)$ %{REQUEST_URI}.webp [T=image/webp,E=accept:1,L]\n</IfModule>\n<IfModule mod_headers.c>\nHeader append Vary Accept env=REDIRECT_accept\n</IfModule>\n#'
	    
	    _note "Setting up varnish exclusions"
  	    sed -i '1s#^#if (req.url ~ "/(.+\.(jpeg|jpg|png))?$") { return (pipe); } \#For_Webp\n#' /home/master/applications/${ARG}/conf/custom-recv.vcl
	    
	    _note "Adding webp to Nginx vhost"
	    sed -i 's#tgz|#tgz|webp|#' /etc/nginx/sites-available/${ARG}

        done

        _bold "Restarting Nginx"
        /etc/init.d/nginx restart >> /dev/null 2<&1

        if [ "$?" == 0 ]; then
            _success "Nginx restarted successfully"
        else
            _error "Unexpected error, see \'systemctl status nginx\' "
            exit
        fi
    fi
}

allow_cf() {

    if [[ -z "${ARGS[@]:1}" ]]; then
        _error "Missing argument.. See --help or -h for Usage"
        exit
    else
        _bold "Changing the configurations"

cf_ips=$(cat <<-EOF > /etc/nginx/cf_ips
geo \$realip_remote_addr \$giveaccess {
        proxy 127.0.0.1;
        default 0;
        103.21.244.0/22 1;
        103.22.200.0/22 1;
        103.31.4.0/22 1;
        104.16.0.0/13 1;
        104.16.0.0/14 1;
        108.162.192.0/18 1;
        131.0.72.0/22 1;
        141.101.64.0/18 1;
        162.158.0.0/15 1;
        172.64.0.0/13 1;
        173.245.48.0/20 1;
        188.114.96.0/20 1;
        190.93.240.0/20 1;
        197.234.240.0/22 1;
        198.41.128.0/17 1;
        2400:cb00::/32 1;
        2405:b500::/32 1;
        2606:4700::/32 1;
        2803:f800::/32 1;
        2c0f:f248::/32 1;
        2a06:98c0::/29 1;
}
EOF
)

block=$(cat <<EOF
if (\$giveaccess = 0){
        return 403;
}
EOF
)

        for ARG in "${ARGS[@]:1}"; do
                CHECK=$(grep "cf_ips" "/etc/nginx/sites-available/$ARG" )

                if [[ ! -z $CHECK ]]; then
                    _note "$ARG file already has the changes. Exiting..."
                    exit
                else 
                _note "Making changes on $ARG"
                sed -i "1s/^/include \/etc\/nginx\/cf_ips;\n/g" "/etc/nginx/sites-available/$ARG"
                LINE=$(expr $(grep -n -o -m 1 location /etc/nginx/sites-available/$ARG | head -1 | awk -F ':' '{print $1}') - 1)
                echo "$block" | sed -i "$LINE r /dev/stdin" "/etc/nginx/sites-available/$ARG"
                fi
        done

        if [ "$?" == 0 ]; then
                _success "Changes made successfully successfully"
        else
                _error "Unexpected error"
                exit
        fi

        _bold "Restarting Nginx"
        /etc/init.d/nginx restart >> /dev/null 2<&1

        if [ "$?" == 0 ]; then
                _success "Nginx restarted successfully"
        else
                _error "Unexpected error, see \'systemctl status nginx\' "
                exit
        fi
    fi
}

node_install() {
    if [[ -z "${ARGS[@]:1}" ]]; then
        _error "Missing argument.. See --help or -h for Usage"
        exit
    else
        NODE_VER="${ARGS[@]:1}"
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://nodejs.org/dist/v$NODE_VER/node-v$NODE_VER-linux-x64.tar.gz")

        if [ "$STATUS_CODE" == "200" ]; then
            _note "Installing Node v$NODE_VER"
            cd /var/cw/systeam
            curl -sL "https://nodejs.org/dist/v$NODE_VER/node-v$NODE_VER-linux-x64.tar.gz" | tar -xzf -
            mv /usr/bin/node /tmp/
            cp /var/cw/systeam/node-v$NODE_VER-linux-x64/bin/node /usr/bin/
            _success "Node v$NODE_VER installed"

            _note "Updating npm"
            rm /usr/bin/npm
            ln -s /var/cw/systeam/node-v$NODE_VER-linux-x64/lib/node_modules/npm/bin/npm-cli.js /usr/bin/npm
            _success "npm updated successfully"

            _note "Updating npx"
            rm /usr/bin/npx
            ln -s /var/cw/systeam/node-v$NODE_VER-linux-x64/lib/node_modules/npm/bin/npx-cli.js /usr/bin/npx
            _success "npx updated successfully"

        else
            _error "Repository doesn't exist.. Exiting"
            exit
        fi
    fi
}

npm_package() {

    if [[ -z "${ARGS[@]:1}" ]]; then
        _error "Missing package name(s).. See --help or -h for Usage"
        exit
    else
        USER=$(ls -l /home/ | grep master | awk '{print $3}') #Changing to master user
        FILE=/home/master/.bash_aliases
MASTER=$(cat <<EOF
export NVM_DIR="\$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
)
        if [ -f "$FILE" ]; then
            ENV_CHECK=$(grep "NVM_DIR=" "$FILE")
            if [[ ! -z $ENV_CHECK ]]; then
                _warning "Environment is already there for master user. Skipping...."
            else 
                _note "Creating master user environment"
                (echo "$MASTER" && cat "$FILE") > /tmp/bash_aliases && mv /tmp/bash_aliases $FILE
                chown $USER:www-data $FILE
            fi
        else
            _warning "$FILE doesn't exist... Creating one"
            touch $FILE
            (echo "$MASTER" && cat "$FILE") > /tmp/bash_aliases && mv /tmp/bash_aliases $FILE
            chown $USER:www-data $FILE
        fi

        for ARG in "${ARGS[@]:1}"; do
            PKG_CHECK=$(grep "$ARG" "$FILE")
            if [[ ! -z $PKG_CHECK ]]; then
                _warning "Package $ARG is already there. Skipping...."
            else
                _note "Creating environment for $ARG package"
                ENVR="alias $ARG='/home/master/bin/npm/lib/node_modules/bin/$ARG'"
                echo "$ENVR" >> $FILE

                su - $USER -c "npm config set prefix \"/home/master/bin/npm/lib/node_modules\"" #>> /dev/null 2<&1

                _note "Installing $ARG"
                su - $USER -c "npm install -g $ARG" >> /tmp/npm-script.log 2<&1

                if [ "$?" == 0 ]; then
                        _success "$ARG installed successfully"
                else
                        _error "Unexpected error, see log file at /tmp/npm-script.log"
                        exit
                fi        
            fi
        done
    fi
}

if [[ "${ARGS[0]}" == "--webp" ]]; then
	webp_configure
elif [[ "${ARGS[0]}" == "--allow-cloudflare" ]]; then
	allow_cf
elif [[ "${ARGS[0]}" == "--install-node" ]]; then
	node_install
elif [[ "${ARGS[0]}" == "--npm-package" ]]; then
	npm_package
elif [[ "${ARGS[0]}" == "--version" || "${ARGS[0]}" == "-v" ]]; then
	echo "HelperScript v1.0.1"
else
	Usage
fi