#!/bin/bash
com=$1
cur_ver=$(git log | head -3) # | awk '{print $2}')

function install() {
    echo '****************'
    git branch -a
    git tag --column
    #git log | egrep 'NVIM v[[:digit:]]?\.[[:digit:]]?\.[[:digit:]]$' | head -n 5 | awk '{print $2}'
    echo '****************'
    echo "Your current revision is: $cur_ver"
    echo '****************'
    read -p "Choose release: " rev
    [ -n "$rev" ] && git checkout $rev || exit_ 1
    git pull
    read -p "Reinstalling your nvim. Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit_ 1
    uninstall
    #make CMAKE_BUILD_TYPE=RelWithDebInfo USE_BUNDLED=OFF && \
    make CMAKE_BUILD_TYPE=RelWithDebInfo && \
    sudo make install
    if [ -d /usr/local/bin/nvim ]; then
        sudo mv /usr/local/bin/nvim /usr/local/bin/nvim.bak
        sudo mv /usr/local/bin/nvim.bak/nvim /usr/local/bin/
        sudo rm -rf /usr/local/bin/nvim.bak
    fi
}

function uninstall() {
    sudo rm  -v /usr/local/bin/nvim
    sudo rm -rv /usr/local/share/nvim/
    sudo rm -rf build
}

function exit_() {
    echo "---------------------------------------"
    new_ver=$(git log | head -3) # | awk '{print $2}')
    echo "Your old revision was: $cur_ver"
    echo "Your new current revision is: $new_ver"
    echo "---------------------------------------"
    nvim --version
    echo "---------------------------------------"
    echo "Uninstall: ./start-nvim.sh uninstall"
    exit $1
}

git status
if [ "$com" = "uninstall" ]; then
    uninstall
else
    install
fi

