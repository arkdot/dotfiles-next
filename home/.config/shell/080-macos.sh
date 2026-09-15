if os_is_darwin; then
    alias hidedt="defaults write com.apple.finder CreateDesktop false; killall Finder"
    alias showdt="defaults write com.apple.finder CreateDesktop true; killall Finder"
    alias umount="diskutil eject"
fi
