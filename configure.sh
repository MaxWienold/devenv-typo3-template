#!/usr/bin/env bash
. ./scripts/inputs.sh


which composer &> /dev/null || {
  echo "Please make sure that composer is available in your \$PATH"
  exit 1
} 

which devenv &> /dev/null && which nix-env &> /dev/null || {
  echo "Please make sure that nix and devenv are installed"
  exit 2
}

[[ -f $PWD/devenv.nix ]] || { 
  echo "Please run this script from within your project's root directory"  
  exit 3
}

echo "devenv TYPO3 environment"
echo "------------------------"
printf "%s\n" "Let's configure your environment" 

# 2. input
echo "What's your project called? (${PWD##*/})"
read -r project_name
project_name="${project_name:=${PWD##*/}}"
echo "Which version of TYPO3 should be installed? (12.4)"
read -r version
version="${version:=^12.4}"
echo "On which port should the web server be listening? (8080)"
read -r port
port="${port:=8080}"
echo "How is your database user called? (admin)"
read -r mysql_user
mysql_user="${mysql_user:=admin}"
input_pw "assign a password for the database user" mysql_pw

printf "%s\n" "configuring devenv.nix file..."
sed -i "s@NGINX_PORT =.*@NGINX_PORT = \"${port}\";@" devenv.nix
sed -i "s@NGINX_ROOT =.*@NGINX_ROOT = \"$(pwd)\/public\/\";@" devenv.nix
sed -i "s@MYSQL_USER = .*@MYSQL_USER = \"${mysql_user}\";@" devenv.nix
sed -i "s@MYSQL_PW = .*@MYSQL_PW = \"${mysql_pw}\";@" devenv.nix

printf "%s\n" "creating composer project..."
composer create-project typo3/cms-base-distribution tmp "${version}" && \
  mv tmp/{public,composer*,vendor} . && \
  rm -r tmp/ || {
  echo "something went wrong with the creation of the project files"
  exit 3 
}

choices=(
  "install typo3 unattended" 
  "I will install manually"
)
choose_from_menu "Do you want to install typo3 with the applied values?" is_unattended_install "${choices[@]}"
[[ $is_unattended_install == 0 ]] && { 
  mv .devenv/processes.log .devenv/processes.log.bk &> /dev/null 
  devenv processes stop 2&> /dev/null 
  devenv up -d && \
  while true; do
    grep -e "\[mysql\s.*socket" .devenv/processes.log &> /dev/null \
      && break
    echo "waiting for database to be ready"
    sleep 1
    done

  while true; do
    echo "Please give additional Information for the initial backend user"

    echo "username: (admin)"
    read -r typo3_user
    typo3_user="${typo3_user:=admin}"

    echo "email:"
    read -r email 
    input_pw "" typo3_pw
    printf "username: %s\n email: %s " "$typo3_user" "$email" 
    confirm "correct?" || continue
    composer exec -- typo3 setup \
      --server-type=other --force\
      --no-interaction \
      --driver=mysqli \
      --username="${mysql_user}" \
      --password="${mysql_pw}" \
      --host=127.0.0.1 \
      --port=3306 \
      --dbname=typo3 \
      --admin-username="${typo3_user}" \
      --admin-email="${email}" \
      --admin-user-password="${typo3_pw}" \
      --project-name="${project_name}"  && break
  done
} 

