#!/bin/bash

function main() {
    com=${1:-'.'} #Command: path to code location
    fetch https://github.com/neovim/neovim.git #Main neovim repository
    exit_ $?
}

fetch () #params: url [revision]
{
    local url=$1
    [ -z $url ] && echo 'fetch needs URL parameter. Nothing to be done.' >&2 && return 1
    local rev=$2
    local stat
    local name=$(basename $url)
    local repo_name=${name%.git}
    cur_path=$(realpath $com/$repo_name)
    old_path=$(realpath $com/${repo_name}.old)
    echo $repo_name directory: $cur_path
    echo $repo_name backup:    $old_path
    read -p "Pulling updates from $url. Continue? (Y/N): " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || return 1
    if [[ -d $cur_path ]]; then
        pushd $cur_path
        ls -al
        stat=$(git remote -v 2>/dev/null | grep "$repo_name\.git")
        #stat=$(git status 2>/dev/null)
        [[ -z $stat ]] && echo $cur_path already exist and is not neovim repository, first do \'rm -rf $cur_path\' && return 1
        git pull
        popd
    else
        git clone $url $cur_path
    fi
    pushd $cur_path
    git status
    git branch -a
    git tag --column
    echo '****************'
    #git log | egrep 'NVIM v[[:digit:]]?\.[[:digit:]]?\.[[:digit:]]$' | head -n 5 | awk '{print $2}'
    [ -z "$rev" ] && read -p "Choose release: (empty to continue) -> " rev
    [ -n "$rev" ] && git checkout $rev || return 1
    echo "Your current revision is: $rev"
    echo '****************'
}

function install_nvim() {
    #make CMAKE_BUILD_TYPE=RelWithDebInfo USE_BUNDLED=OFF && \
    make CMAKE_BUILD_TYPE=RelWithDebInfo && \
    sudo make install
    if [ -d /usr/local/bin/nvim ]; then
        sudo mv /usr/local/bin/nvim /usr/local/bin/nvim.bak
        sudo mv /usr/local/bin/nvim.bak/nvim /usr/local/bin/
        sudo rm -rf /usr/local/bin/nvim.bak
    fi
}

function uninstall_nvim() {
    local stat
    read -p "Uninstalling your nvim. Backup here: ${old_path}. Continue? (Y/N): " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || exit_ 1
    mkdir -p $cur_path
    rm -rf $old_path
    cp -r $cur_path $old_path
    sudo mv /usr/local/bin/nvim $old_path/bin_nvim
    sudo mv /usr/local/share/nvim/ $old_path/share_nvim
    sudo rm -rf builds
    sudo rm -rf .deps
}

function restore_nvim() {
    local stat
    read -p "Restoring your nvim from ${old_path}. Continue? (Y/N): " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || exit_ 1
    [ -f $old_path/bin_nvim ] && sudo rm -v /usr/local/bin/nvim && sudo mv $old_path/bin_nvim /usr/local/bin/nvim
    [ -d $old_path/share_nvim ] && sudo rm -rf /usr/local/share/nvim/ && sudo mv $old_path/share_nvim /usr/local/share/nvim/
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

all ()
{
    uninstall
    install
    exit_ 0
}

main $@
