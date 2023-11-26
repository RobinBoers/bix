#!/bin/fish

set destination_path "$HOME/.local/bin/bix"
set destination_dir (dirname $destination_path)

echo "Installing bix.sh to $destination_path"

test -d $destination_dir || mkdir -p $destination_dir

wget --quiet http://git.dupunkto.org/~robin/libre0b11/bix/plain/bix.sh -O $destination_path
chmod +x $destination_path

echo "Installed in $destination_dir. Make sure it is available in your PATH"

echo "✨ Ty for trying bix!"
