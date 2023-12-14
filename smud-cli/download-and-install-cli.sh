#!/usr/bin/env bash
HOME_DIR=$(dirname `readlink -f ~/.bashrc`)
VERSION="LATEST"
folder=smud-cli
curr_dir=$(pwd)
destination_folder=$HOME_DIR/$folder
download_folder=$HOME_DIR/$folder-downloaded
download_json_file=$download_folder/downloaded-info.json
changelog_download_json_file=$download_folder/changelog-downloaded-info.json
if [ -d "$download_folder" ];then
   rm -rf $download_folder 
fi

mkdir $download_folder 
cd $download_folder

curl --ssl-no-revoke https://api.github.com/repos/DIPSAS/smud-cli/contents/$folder --no-progress-meter -o $download_json_file

if [ ! -f "$download_json_file" ];then
    echo "Missing $$download_json_file file"    
fi
download_names=($(cat $download_json_file | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p'))
download_urls=$(cat $download_json_file   | sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p')
i=-1
for url in $download_urls; do
    i=$((i+1))
    file=${download_names[$i]}
    downloaded_file=$(basename $url)
    printf "${gray}Download '$file' file: ${normal}\n"   
    curl --ssl-no-revoke $url -o $file # > /dev/null 2>&1
    echo ""
done

curl --ssl-no-revoke https://api.github.com/repos/DIPSAS/smud-cli/contents/CHANGELOG.md --no-progress-meter -o $changelog_download_json_file
changelog_name=($(cat $changelog_download_json_file | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p'))
changelog_download_url=$(cat $changelog_download_json_file   | sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p')

printf "${gray}Download '$changelog_name' file: ${normal}\n"   
curl --ssl-no-revoke $changelog_download_url -o $changelog_name # > /dev/null 2>&1

rm -f "$changelog_download_json_file"

cd $curr_dir

if [ -d $download_folder ]; then
   if [ ! -d "$destination_folder" ];then
      mkdir $destination_folder 
   fi
   if [ -f "$download_json_file" ];then
     rm -f "$download_json_file"
   fi

   cp $download_folder/*.sh $destination_folder/ -r -u
   cp $download_folder/.bash_aliases $destination_folder/ -r -u

   if [ -f "$download_folder/CHANGELOG.md" ];then
      cp $download_folder/*.md $destination_folder/ -r -u
   fi   

   rm -rf $download_folder 
   . $destination_folder/install-cli.sh
fi