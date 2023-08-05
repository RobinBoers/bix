#!/bin/fish

set destination_path "$HOME/.local/bin/bix"

echo "Installing bix.sh to $destination_path"

mkdir (dirname $destination_path)

wget --quiet https://git.geheimesite.nl/libre0b11/bix/raw/branch/master/bix.sh -O $destination_path
chmod +x $destination_path

echo "Installed in $destination_dir. Make sure it is available in your PATH"

echo "✨ Ty for trying bix!"
