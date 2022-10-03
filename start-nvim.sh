#!/bin/bash

workdir=${1:-'.'} #path to code location
declare -a urls=(
    "https://github.com/neovim/neovim.git" #Main neovim repository
    "https://github.com/lexavb76/nvim-lua.git" #neovim configuration and plugins
)

function main() {
    local url
    for url in ${urls[@]}
    do
        local name=$(basename $url)
        local repo_name=${name%.git}
        local com
        fetch "$url" || continue
        read -p "Choose your action (install | uninstall | restore). Empty - continue with another repo -> " com
        case "$com" in
            uninstall) eval "echo uninstall_$repo_name $url"
            ;;
            install) eval "echo install_$repo_name $url"
            ;;
            restore) eval "echo restore_$repo_name $url"
            ;;
            *) echo default
            ;;
        esac
    done
    exit_ $?
}

fetch () #params: url [revision]
{
    local url=$1
    [ -z $url ] && echo 'fetch needs URL parameter. Nothing to be done.' >&2 && return 1
    local rev_ans=${2:-HEAD}
    local rev=$rev_ans
    local stat
    local name=$(basename $url)
    local repo_name=${name%.git}
    local cur_path=$(realpath $workdir/$repo_name)
    local log=$cur_path/log.txt
    date > $log
    echo '****************' | tee -a $log
    echo $repo_name directory: $cur_path
    read -p "Pulling updates from $url. Continue? (Y/N): -> " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || return 1
    if [[ -d $cur_path ]]; then
        pushd $cur_path
        ls -al
        stat=$(git remote -v 2>/dev/null | grep "$repo_name\.git")
        #stat=$(git status 2>/dev/null)
        [[ -z $stat ]] && echo $cur_path already exist and is not neovim repository, first do \'rm -rf $cur_path\' && return 1
        git pull 2>/dev/null
        popd
    else
        git clone $url $cur_path
    fi
    pushd $cur_path
    git status | tee -a $log
    git branch -a
    git tag --column
    echo '****************'
    #git log | egrep 'NVIM v[[:digit:]]?\.[[:digit:]]?\.[[:digit:]]$' | head -n 5 | awk '{print $2}'
    stat=1
    while [[ $stat != 0 ]]; do
        read -p "Choose release: (<Enter> to continue with \"$rev\") -> " rev_ans
        [ -n "$rev_ans" ] && rev=${rev_ans}
        stat=1
        git checkout $rev && stat=0 && rev=$(git log | head -1 | tee -a $log) || rev=HEAD
    done
    git pull 2>/dev/null
    echo "Your current revision is: $rev" | tee -a $log
    git status | tee -a $log
}

#neovim
################################################################################
function install_neovim() {
    #make CMAKE_BUILD_TYPE=RelWithDebInfo USE_BUNDLED=OFF && \
    make CMAKE_BUILD_TYPE=RelWithDebInfo && \
    sudo make install
    if [ -d /usr/local/bin/nvim ]; then
        sudo mv /usr/local/bin/nvim /usr/local/bin/nvim.bak
        sudo mv /usr/local/bin/nvim.bak/nvim /usr/local/bin/
        sudo rm -rf /usr/local/bin/nvim.bak
    fi
}

function uninstall_neovim() { #param: URL
    local name=$(basename $1)
    local repo_name=${name%.git}
    local cur_path=$(realpath $workdir/$repo_name)
    local old_path=$(realpath $workdir/${repo_name}.old)
    local stat
    echo $repo_name backup:    $old_path
    read -p "Uninstalling your nvim. Backup here: ${old_path}. Continue? (Y/N): -> " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || exit_ 1
    mkdir -p $cur_path
    rm -rf $old_path
    cp -r $cur_path $old_path
    sudo mv /usr/local/bin/nvim $old_path/bin_nvim
    [ -e $old_path/share_nvim ] && rm -rf $old_path/share_nvim
    sudo mv /usr/local/share/nvim/ $old_path/share_nvim
    sudo rm -rf builds
    sudo rm -rf .deps
}

function restore_neovim() { #param: URL
    local name=$(basename $1)
    local repo_name=${name%.git}
    local old_path=$(realpath $workdir/${repo_name}.old)
    local stat
    read -p "Restoring your nvim from ${old_path}. Continue? (Y/N): " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || exit_ 1
    [ -f $old_path/bin_nvim ] && sudo rm -v /usr/local/bin/nvim && sudo mv $old_path/bin_nvim /usr/local/bin/nvim
    [ -d $old_path/share_nvim ] && sudo rm -rf /usr/local/share/nvim/ && sudo mv $old_path/share_nvim /usr/local/share/nvim/
}

function exit_() {
    local name=$(basename ${urls[1]})
    local repo_name=${name%.git}
    local cur_path=$(realpath $workdir/$repo_name)
    local log=${cur_path}/log.txt
    echo $log
    echo "---------------------------------------" |  tee -a $log
    which nvim && nvim --version | tee -a $log
    exit $1
}

all ()
{
    uninstall
    install
    exit_ 0
}

main $workdir
