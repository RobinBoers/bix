#!/bin/fish

set destination_path "$HOME/.local/bin/bix"

echo "Installing bix.sh to $destination_path"

wget --quiet https://git.geheimesite.nl/libre0b11/bix/raw/branch/master/bix.sh -O $destination_path
chmod +x $destination_path

echo "✨ Ty for trying bix!"
