#!/bin/bash


input_filepath="$1"

output_iconset_name="COPC.iconset"
rm -rf $output_iconset_name
mkdir -p $output_iconset_name

sizes=( 16 32 64 128 256 512)

for i in "${sizes[@]}"
do
    sips -z $i $i $input_filepath --out "${output_iconset_name}/icon_$ix$i.png"
    echo $i
done

iconutil -c icns $output_iconset_name
rm -rf $output_iconset_name
