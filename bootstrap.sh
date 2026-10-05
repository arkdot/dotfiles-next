#!/bin/sh

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
bold=$(tput bold)
reset=$(tput sgr0)

has_command() {
    command -v "$@" &> /dev/null
}

title() {
    echo "${bold}==> $1${reset}"
    echo
}

echo -e "${red}!!! WARNING !!!${reset}"
echo -e "${red}This script will delete all your configuration files${reset}"
echo -e "${yellow}Press enter key to continue...${reset}"
read key


title "Cloning the repo"
git clone --recurse-submodules https://github.com/arkdot/dotfiles-next && \
cd dotfiles-next

# Installs uv if necessary
if ! has_command "uv"; then
    title "Installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh -s -- -q --no-modify-path
    PATH="${HOME}/.local/bin:${PATH}"
fi

uv run ./install.py


echo -e "${green}All done!. For the changes to take effect, run: source ~/.zshrc or source ~/.bashrc.${reset}"

unset red green yellow bold reset key
