#!/usr/bin/env bash
HOME_DIR=$(dirname `readlink -f ~/.bashrc`)
VERSION="LATEST"
folder=smud-cli
curr_dir=$(pwd)
destination_folder=$HOME_DIR/$folder
download_folder=$HOME_DIR/$folder-downloaded
download_json_file=$download_folder/downloaded-info.json
if [ -d "$download_folder" ];then
   rm -rf $download_folder 
fi
if [ -f "$download_json_file" ];then
    rm -f $download_json_file 
fi

AUTH_TOKEN=""
AUTH_USER=""
# if [ "$GITHUB_TOKEN" ]; then
#    AUTH_TOKEN="--header 'Authorization:$GITHUB_TOKEN'"
#    AUTH_USER="--user :$GITHUB_TOKEN"
# fi

mkdir $download_folder 
cd $download_folder

printf "${gray}Download '$folder' folder spec: ${normal}\n"  
response="$(curl --ssl-no-revoke -o $download_json_file $AUTH_TOKEN "https://api.github.com/repos/DIPSAS/smud-cli/contents/$folder" 2>&1)" || {
   echo "Failed to download '$download_json_file' file"    
   if [ "$response" ]; then
      echo "Error: "   
      echo "$response" | grep curl:    
   fi
   exit
}


if [ ! -f "$download_json_file" ];then
    echo "Missing '$download_json_file' file"    
   if [ "$response" ]; then
      echo "Error: "   
      echo "$response" | grep curl:    
   fi
    exit
fi
download_names=""
download_urls=""
if [ -f "$download_json_file" ];then
   download_names=($(cat $download_json_file | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p'))
   download_urls=("$(cat $download_json_file   | sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p')")
else
   echo "Missing '$download_json_file' file"    
   exit
fi

IFS=$'\n';read -rd '' -a download_urls <<< "$download_urls"
IFS=$'\n';read -rd '' -a download_names <<< "$download_names"
i=-1
for url in "${download_urls[@]}"; do
   i=$((i+1))
   file="${download_names[$i]}"
   if [ ! "$file" ]; then
      file="$(echo "$url"|sed -e 's/.*\/main\/smud-cli\/\(.*\)/\1/g')"
   fi   
   downloaded_file=$(basename $url)
   if [ "$file" ]; then
      printf "${gray}Download '$file' file: ${normal}\n"   
      # echo "Download:$url => $file"
      curl --ssl-no-revoke -o $file $url # > /dev/null 2>&1
      #  echo "Downloaded"
   else
      printf "${red}Unabled to Download '$file' file: ${normal}\n"   
      exit
   fi
   echo ""
done
changelog_download_file="$download_folder/CHANGELOG.md"
changelog_download_url="https://raw.githubusercontent.com/DIPSAS/smud-cli/main/CHANGELOG.md"

printf "${gray}Download 'CHANGELOG.md' file: ${normal}\n"  
curl  --ssl-no-revoke -o $changelog_download_file "$changelog_download_url" # > /dev/null 2>&1
if [ ! -f "$changelog_download_file" ];then
   echo "Failed to download '$changelog_download_file' file"    
fi

cd $curr_dir

if [ -d $download_folder ]; then
   if [ ! -d "$destination_folder" ];then
      mkdir $destination_folder 
   fi
   if [ -f "$download_json_file" ];then
     rm -f "$download_json_file"
   fi
   if [ -d $download_folder ]; then
      has_shell_files="$(ls $download_folder/* 2>&1 |grep .sh |tail -1)"
      # echo "has_shell_files: $has_shell_files"
      if [ "$has_shell_files" ]; then
         cp $download_folder/*.sh $destination_folder/ -r -u
      fi
      if [ -f "$download_folder/.bash_aliases" ];then
         cp $download_folder/.bash_aliases $destination_folder/ -r -u
      fi

   fi

   if [ -f "$download_folder/CHANGELOG.md" ];then
      cp $download_folder/*.md $destination_folder/ -r -u
   fi   

   rm -rf $download_folder 
   . $destination_folder/install-cli.sh
fi