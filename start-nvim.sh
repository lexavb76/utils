#!/bin/bash

function main() {
    com=${1-:'.'} #Command: all | install | uninstall
    cur_path=$(realpath $com/neovim)
    old_path=$(realpath $com/neovim.old)
    local stat
    echo Neovim directory: $cur_path
    echo Neovim backup:    $old_path
    read -p 'Continue? (y/n) -> ' stat
    [[ $stat != 'y' && $stat != 'Y' ]] && exit_ 1
    #[ -d $cur_path ] && cp -r $cur_path $old_path || git clone https://github.com/neovim/neovim.git $cur_path
    if [[ -d $cur_path ]]; then
        pushd $cur_path
        ls -al
        stat=$(git remote -v 2>/dev/null | grep 'neovim\.git')
        #stat=$(git status 2>/dev/null)
        [[ -n $stat ]] && echo $stat
        popd
    fi
    exit 0

    [ -d $old_path ] && rm -rf $old_path
    cd $cur_path
    cur_ver=$(git log | head -1 | awk '{print $2}') || exit_ 1
    fetch $cur_ver
    case "$com" in
        all) all
        ;;
        install) install
        ;;
        uninstall) uninstall
        ;;
        *) echo 'Options: all | install | uninstall'
            exit_ 1
        ;;
    esac
}

all ()
{
    uninstall
    install
    exit_ 0
}

fetch () #param: revision
{
    local rev=$1
    git checkout master
    git pull
    git status
    echo '****************'
    #git log | egrep 'NVIM v[[:digit:]]?\.[[:digit:]]?\.[[:digit:]]$' | head -n 5 | awk '{print $2}'
    git checkout $rev
    git branch -a
    git tag --column
    echo '****************'
    echo "Your current revision is: $rev"
    echo '****************'
}

function install() {
    local rev
    read -p "Choose release: " rev
    [ -n "$rev" ] && git checkout $rev || exit_ 1
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
    read -p "Uninstalling your nvim. Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit_ 1
    sudo rm  -v /usr/local/bin/nvim
    sudo rm -rf /usr/local/share/nvim/
    sudo rm -rf builds
    #sudo rm -rf .deps/.ninja_log
    sudo rm -rf .deps
}

function exit_() {
    local log=log.txt
    echo "---------------------------------------" | tee $log
    local new_ver=$(git log | head -3) # | awk '{print $2}')
    echo "Your old revision was: $cur_ver" | tee -a $log
    echo "Your new current revision is: $new_ver" |  tee -a $log
    echo "---------------------------------------" |  tee -a $log
    which nvim && nvim --version | tee -a $log
    echo "---------------------------------------" |  tee -a $log
    echo "Uninstall: ./start-nvim.sh uninstall" |  tee -a $log
    exit $1
}

main $@
