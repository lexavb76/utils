#!/bin/bash

workdir=${1:-'.'} #path to code location
workdir=$workdir/nvim
declare -a urls=(
    'https://github.com/neovim/neovim.git'            #Main_neovim_repository
    'https://github.com/lexavb76/nvim-lua.git'        #Neovim_configuration_and_plugins
    'https://github.com/equalsraf/neovim-qt.git'      #Qt based GUI for neovim
    #'https://github.com/neovide/neovide.git'          #Neovide_GUI_for_neovim (strange behaviour with keymappings)
    'https://github.com/ryanoasis/nerd-fonts'         #Hack nerd-fonts family is needed
)


main()
{
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
            install) eval "uninstall_$postfix $repo_name && install_$postfix $repo_name"
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
install_neovim()
{ #param: repo_name
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
    command -v nvim 1>&2>/dev/null || return 1
    echo "Start neovim: nvim" | tee -a $log
}

uninstall_neovim()
{ #param: repo_name
    local repo_name=$1
    local cur_path=$(realpath $workdir/$repo_name)
    local old_path=$(realpath $workdir/${repo_name}.old)
    local stat
    command -v nvim 1>&2>/dev/null || return 0
    echo $repo_name backup:    $old_path
    read -p "Uninstalling your nvim. Backup here: ${old_path}. Continue? (Y/N): -> " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || return 1
    mkdir -p $cur_path
    rm -rf $old_path
    cp -r $cur_path $old_path
    sudo mv /usr/local/bin/nvim $old_path/bin_nvim
    [ -e $old_path/share_nvim ] && rm -rf $old_path/share_nvim
    sudo mv /usr/local/share/nvim/ $old_path/share_nvim
    sudo rm -rf builds
    sudo rm -rf .deps
}

restore_neovim()
{ #param: repo_name
    local repo_name=$1
    local old_path=$(realpath $workdir/${repo_name}.old)
    local stat
    read -p "Restoring your nvim from ${old_path}. Continue? (Y/N): " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || return 1
    [ -f $old_path/bin_nvim ] && sudo rm -v /usr/local/bin/nvim && sudo mv $old_path/bin_nvim /usr/local/bin/nvim
    [ -d $old_path/share_nvim ] && sudo rm -rf /usr/local/share/nvim/ && sudo mv $old_path/share_nvim /usr/local/share/nvim/
}

#nvim-lua
################################################################################
install_nvim_lua()
{ #param: repo_name
    local repo_name=$1
    local cur_path=$(realpath $workdir/$repo_name)
    ln -sv $cur_path $HOME/.config/nvim
    mkdir -p $workdir/share
    ln -sv $workdir/share $HOME/.local/share/nvim
    #TODO:
    #Set link to $workdir/share
    #Elaborate work directories tree scheme
}

uninstall_nvim_lua()
{ #param: repo_name
    local repo_name=$1
    local cur_path=$(realpath $workdir/$repo_name)
    local nvim_conf=$HOME/.config/nvim
    if [ -e $nvim_conf ]; then
        read -p "$nvim_conf exists. Do you really want to remove it? (Y/N): " stat && [[ $stat == [yY] || $stat == [yY][eE][sS] ]] || return 1
        rm -rf $nvim_conf || return 1
    fi
}

#neovim-qt
################################################################################
install_neovim_qt()
{ #param: repo_name
    local repo_name=$1
    local cur_path=$(realpath $workdir/$repo_name)
    pushd $cur_path
    mkdir -p build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release .. && make || return 1
    echo "Start GUI: nvim-qt" | tee -a $log
    popd
}

uninstall_neovim_qt()
{ #param: repo_name
    local repo_name=$1
    local cur_path=$(realpath $workdir/$repo_name)
    if command -v nvim-qt >/dev/null; then
        read -p "Uninstalling your neovim-qt GUI. Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || return 1
        sudo xargs rm -v < $cur_path/build/install_manifest.txt
    fi
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

################################################################################
################################################################################
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
