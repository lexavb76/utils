#!/bin/bash
com=$1
rev=$2

function update() {
    stat=$(git status)
    echo "$stat"
    if ! echo "$stat" | grep "Your branch is up to date with 'origin/master'" > /dev/null; then
        install
    fi
}

function install() {
    read -p "Reinstalling your nvim. Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
    git pull
    [ -n "$rev" ] && git checkout $rev
    uninstall
    mkdir -p build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make
}

function uninstall() {
    sudo xargs rm -v < build/install_manifest.txt
}

cur_ver=$(git log | head -1 | awk '{print $2}')
if [ "$com" = "uninstall" ]; then
    uninstall
elif [ "$com" = install ]; then
    install
elif [ "$com" = update ]; then
    update
else
    echo "Wrong option! Use <install|uninstall|update>"
fi

echo "---------------------------------------"
echo "To reset to the last working revision: git checkout $cur_ver"
cur_ver=$(git log | head -1 | awk '{print $2}')
echo "Your current revision is:                           $cur_ver"
