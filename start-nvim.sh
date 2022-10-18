#!/bin/bash

workdir=${1:-'.'} #path to code location
declare -a urls=(
    'https://github.com/neovim/neovim.git'     #Main_neovim_repository
    'https://github.com/lexavb76/nvim-lua.git' #Neovim_configuration_and_plugins
    #'https://github.com/neovide/neovide.git'   #Neovide_GUI_for_neovim (strange behaviour with keymappings)
)


function main() {
    local repo
    for repo in ${urls[*]}
    do
        local name=$(basename $repo)
        local repo_name=${name%.git}
        local cur_path=$(realpath $workdir/$repo_name)
        local postfix=$(echo "$repo_name" | sed 's/-/_/g')
        local com
        local stat
        log=$cur_path/log.txt
        echo "**************** ${repo} ****************"
        echo $repo_name directory: $cur_path
        read -p "Pulling updates from $repo. Continue? (Y/N): -> " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || continue
        fetch "$repo_name" || continue
        read -p "Choose your action (install | uninstall | restore). Empty - continue with another repo -> " com
        case "$com" in
            uninstall) eval "echo uninstall_$postfix $repo_name"
            ;;
            install) eval "install_$postfix $repo_name"
            ;;
            restore) eval "echo restore_$postfix $repo_name"
            ;;
            *) echo default
            ;;
        esac
    done
    exit_ $?
}

fetch () #params: repo_name [revision]
{
    local repo_name=$1
    [ -z "$repo_name" ] && echo 'fetch needs repo_name parameter. Nothing to be done.' >&2 && return 1
    local rev_ans=${2:-HEAD}
    local rev=$rev_ans
    local stat
    local cur_path=$(realpath $workdir/$repo_name)
    if [[ -d $cur_path ]]; then
        pushd $cur_path
        ls -al
        stat=$(git remote -v 2>/dev/null | grep "$repo_name\.git")
        [[ -z $stat ]] && echo $cur_path already exist and is not neovim repository, first do \'rm -rf $cur_path\' && return 1
        git pull 2>/dev/null
        popd
    else
        git clone $url $cur_path
    fi
    date > $log
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
    popd
}

#neovim
################################################################################
function install_neovim() { #param: repo_name
    local repo_name=$1
    local cur_path=$(realpath $workdir/$repo_name)
    pushd $cur_path
    #make CMAKE_BUILD_TYPE=RelWithDebInfo USE_BUNDLED=OFF && \
    make CMAKE_BUILD_TYPE=RelWithDebInfo && \
    sudo make install
    if [ -d /usr/local/bin/nvim ]; then
        sudo mv /usr/local/bin/nvim /usr/local/bin/nvim.bak
        sudo mv /usr/local/bin/nvim.bak/nvim /usr/local/bin/
        sudo rm -rf /usr/local/bin/nvim.bak
    fi
    popd
}

function uninstall_neovim() { #param: repo_name
    local repo_name=$1
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

function restore_neovim() { #param: repo_name
    local repo_name=$1
    local old_path=$(realpath $workdir/${repo_name}.old)
    local stat
    read -p "Restoring your nvim from ${old_path}. Continue? (Y/N): " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || exit_ 1
    [ -f $old_path/bin_nvim ] && sudo rm -v /usr/local/bin/nvim && sudo mv $old_path/bin_nvim /usr/local/bin/nvim
    [ -d $old_path/share_nvim ] && sudo rm -rf /usr/local/share/nvim/ && sudo mv $old_path/share_nvim /usr/local/share/nvim/
}

#neovide GUI
################################################################################
install_neovide () #param: repo_name
{
    local repo_name=$1
    local cur_path=$(realpath $workdir/$repo_name)
    curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | sh && source "$HOME/.cargo/env" #Install Rust
    pushd $cur_path
    cargo install --path $cur_path || cat 1>&2 <<EOF

Check all these packages are installed:
"sudo apt install -y curl \
gnupg ca-certificates git \
gcc-multilib g++-multilib cmake libssl-dev pkg-config \
libfreetype6-dev libasound2-dev libexpat1-dev libxcb-composite0-dev \
libbz2-dev libsndio-dev freeglut3-dev libxmu-dev libxi-dev libfontconfig1-dev"

EOF

    popd
}

exit_() {
    local name=$(basename ${urls[0]})
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
