#!/usr/bin/env zsh

set -eo pipefail

if [[ ! -f hammerspoon_init_lua ]]; then
  >&2 echo "ERROR: could not find hammerspoon_init_lua. please run this script like: ./go"
  exit 1
fi

# if not writable, output as an FYI. always ensure permissions regardless, since it's fast and harmless.
if [[ -d /usr/local/share/zsh ]]; then
  if ! test -w "/usr/local/share/zsh"; then
    echo 'about to run sudo chmod -R 755 /usr/local/share/zsh'
  fi

  echo 'This may prompt for your computer password'
  sudo chmod -R 755 /usr/local/share/zsh
fi

brew list --cask > /tmp/brew_cask_list
function install_brew_casks() {
  echo "ensuring brew casks installed: ${@}"
  for brew_cask in $@; do
    if ! grep -q "$brew_cask" /tmp/brew_cask_list; then
      echo "installing brew cask: ${brew_cask}"
      brew install --cask "$brew_cask"
    fi
  done
}

install_brew_casks dropbox hammerspoon iterm2

installed_chrome="false"
if [[ ! -d "/Applications/Google Chrome.app" ]]; then
  install_brew_casks google-chrome
  installed_chrome="true"
fi
# install_brew_casks spacelauncher

# https://osxdaily.com/2010/09/12/disable-application-downloaded-from-the-internet-message-in-mac-os-x/
mkdir -p /var/tmp/computer_setup

# i know this doesn't work for me after i've been using chrome for some time.
# not sure if it works during first time setup before chrome has been used.
# if so, this should fix it.
if [[ ! -f /var/tmp/computer_setup/ran_xattr_on_google_chrome ]]; then
  if [[ "$installed_chrome" == "true" ]]; then
    xattr -d -r com.apple.quarantine /Applications/Google\ Chrome.app
  fi
  touch /var/tmp/computer_setup/ran_xattr_on_google_chrome
fi

# previously did SpaceLauncher, too
for app_name in Dropbox Hammerspoon iTerm Docker; do
  if [[ -d "/Applications/${app_name}.app" ]]; then
    xattr -d -r com.apple.quarantine "/Applications/${app_name}.app"
  fi
done

# apps that ask for "Security & Privacy -> Accessibility" permission "to control your computer", which appears to be impossible to automate thanks to SIP: dropbox, google drive file stream, hammerspoon

mkdir -p "$HOME/.hammerspoon"
if [[ ! -f "$HOME/.hammerspoon/init.lua" ]] || ! diff hammerspoon_init_lua "$HOME/.hammerspoon/init.lua" > /dev/null; then
  echo 'putting in place hammerspoon configs'
  cp hammerspoon_init_lua "$HOME/.hammerspoon/init.lua"
fi

if [[ ! -d "$HOME/.hammerspoon/Spoons/SpoonInstall.spoon" ]]; then
  rm -rf /tmp/SpoonInstall.spoon
  echo 'installing SpoonInstall meta spoon installer for Hammerspoon'
  curl --fail -s --location 'https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip' -o /tmp/SpoonInstall.spoon.zip
  pushd /tmp
  unzip SpoonInstall.spoon.zip
  mkdir -p "$HOME/.hammerspoon/Spoons"
  mv SpoonInstall.spoon "$HOME/.hammerspoon/Spoons"
  popd
fi

if ! defaults read com.apple.Dock autohide &> /dev/null; then
  echo 'setting dock to auto-hide'
  defaults write com.apple.Dock autohide -bool TRUE
  killall Dock

  # i think the above works and is hotter, but just in case.
  # https://discussions.apple.com/thread/5026935
  # osascript -e "tell application \"System Events\" to set the autohide of the dock preferences to true"
fi

# reference: https://www.jamf.com/jamf-nation/discussions/10576/menu-bar-customization
# maybe no longer works in big sur
# current_menu_extras="$(defaults read com.apple.systemuiserver menuExtras)"
# if ! grep -q Volume <<< "$current_menu_extras"; then
#   echo 'adding Volume to Menu Extras'
#   if [[ -d "/System/Library/CoreServices/Menu Extras/Volume.menu" ]]; then
#     open "/System/Library/CoreServices/Menu Extras/Volume.menu"
#   fi
# fi

if [[ ! -f "$HOME/Library/Application Support/iTerm2/DynamicProfiles/awesome_iterm2.plist" ]]; then
  # https://apple.stackexchange.com/questions/92173/how-to-prevent-terminal-from-resizing-when-font-size-is-changed
  # https://apple.stackexchange.com/questions/313356/iterm2-command-line-configuration
  # https://iterm2.com/documentation-dynamic-profiles.html

  # this directory may not exist if you have not yet launched iTerm2
  mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"

  echo 'putting iterm2 plist in place'
  cp awesome_iterm2.plist "$HOME/Library/Application Support/iTerm2/DynamicProfiles/awesome_iterm2.plist"
elif ! diff awesome_iterm2.plist "$HOME/Library/Application Support/iTerm2/DynamicProfiles/awesome_iterm2.plist" > /dev/null; then
  echo 'updating iterm2 plist'
  cp awesome_iterm2.plist "$HOME/Library/Application Support/iTerm2/DynamicProfiles/awesome_iterm2.plist"
fi

current_clock_format="$(defaults read com.apple.menuextra.clock "DateFormat" 2>/dev/null || echo '')"

if [[ "$current_clock_format" != "EEE MMM d  H:mm:ss" ]]; then
  # https://superuser.com/questions/1111908/change-os-x-date-and-time-format-in-menu-bar
  echo 'setting default clock format to 24 hour time and including the month, day of week, and day of month'
  defaults write com.apple.menuextra.clock "DateFormat" "EEE MMM d  H:mm:ss"; killall SystemUIServer
fi

# crush all iterm settings (pretty safe, since everthing is re-created by this script and the dynamic profile):
# defaults delete com.googlecode.iterm2

# faster mouse. 3 is the max from the UI. reference: https://paulminors.com/blog/how-to-speed-up-mouse-tracking-on-mac/
defaults write -g com.apple.mouse.scaling  7

# faster key repeat rate. reference: https://apple.stackexchange.com/a/83923
defaults write -g InitialKeyRepeat -int 15 # normal minimum is 15 (225 ms), but you can try going down to 10
defaults write -g KeyRepeat -int 2 # normal minimum is 2 (30 ms), but you can try going down to 1

# do not ask to quit after we tell it to quit
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

# allow iterm to write and read from clipboard
defaults write com.googlecode.iterm2 AllowClipboardAccess -bool true

# automatic software updates
defaults write com.googlecode.iterm2 SUEnableAutomaticChecks -bool true

# there is a thing about how it caches prefs that might make this not work:
#   https://gitlab.com/gnachman/iterm2/-/issuessome/8029
# guid of kb-style-profile from awesome_iterm2.plist, which becomes a dynamic profile
# there is also defaults delete and defaults read
defaults write com.googlecode.iterm2 "Default Bookmark Guid" "27a2b543-1d6b-4cd9-b157-aa5af6433226"

# debug
# cp ~/Library/Preferences/com.googlecode.iterm2.plist ~
# plutil -convert xml1 ~/com.googlecode.iterm2.plist
# grep -iA1 'Prompt' ~/com.googlecode.iterm2.plist
# grep -iA1 'AllowClipboardAccess' ~/com.googlecode.iterm2.plist
# grep -iA1 'Default Bookmark Guid' ~/com.googlecode.iterm2.plist

# it seems iterm2 already has solarized dark and light built in
# curl -s --fail 'https://raw.githubusercontent.com/altercation/solarized/master/iterm2-colors-solarized/Solarized%20Dark.itermcolors -o "/tmp/Solarized Dark.itermcolors"
# open "/tmp/Solarized Dark.itermcolors"

install_brew_casks karabiner-elements google-drive
# xattr -d -r com.apple.quarantine /Applications/Karabiner-Elements.app

mkdir -p "$HOME/.config/karabiner"
if [[ ! -f "$HOME/.config/karabiner/karabiner.json" ]]; then
  cp karabiner_elements/karabiner.json "$HOME/.config/karabiner/karabiner.json"
fi

if [[ -f "$HOME/Google Drive/My Drive/dotfiles/setup" ]]; then
  custom_dotfiles_setup_script="$HOME/Google Drive/My Drive/dotfiles/setup"
elif [[ -f "$HOME/Dropbox/dotfiles/setup" ]]; then
  custom_dotfiles_setup_script="$HOME/Dropbox/dotfiles/setup"
else
  custom_dotfiles_setup_script=""
fi

if [[ -n "$custom_dotfiles_setup_script" ]]; then
  echo "running ${custom_dotfiles_setup_script}"
  chmod a+x "$custom_dotfiles_setup_script"
  "$custom_dotfiles_setup_script"
else
  echo 'NOTE: could not find custom_dotfiles_setup_script in Google Drive or Dropbox'
fi

# stuff specific to burnettk
if [[ "$USER" == "kevin" ]] || [[ "$USER" == "burnettk" ]]; then
  # handled by user-dotfiles
  # echo -e "[user]\n  name = burnettk\n  email = burnettk@users.noreply.github.com" > "$HOME/.gitconfig.user.personal"

  # for convenience, since burnettk needs to commit to github repos
  # https://serverfault.com/a/701637
  ssh-keyscan github.com | grep -E '^github.com ssh-rsa' > /tmp/githubKey
  fingerprint="$(ssh-keygen -lf /tmp/githubKey | awk '{print $2}' | awk -F: '{print $2}')"
  echo "github fingerprint: $fingerprint"
  if ! grep -q "$(cat /tmp/githubKey)" ~/.ssh/known_hosts; then
    echo "not found in known_hosts"
    github_meta_output=$(curl -si https://api.github.com/meta)
    if grep -q "$fingerprint" <<< "$github_meta_output"; then
      echo "found on api.github.com, so hopefully safe. adding to known_hosts"
      cat /tmp/githubKey >> ~/.ssh/known_hosts
    else
      echo 'could not find fingerprint at api.github.com'
    fi
  fi

  # make chrome the default browser
  if [[ "$installed_chrome" == "true" ]]; then
    /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --make-default-browser
  fi

  # this file will only exist after Google Drive/My Drive/dotfiles/setup has run
  if [[ -f "$HOME/.ssh/serval.pub" ]]; then
    if [[ ! -d "$HOME/projects/github/smartserval" ]]; then
      mkdir -p "$HOME/projects/github"
      pushd "$HOME/projects/github"
      git clone git@github.com-serval:smartserval/smartserval.git
    fi

    if [[ ! -d "$HOME/projects/github/ergo-slack" ]]; then
      mkdir -p "$HOME/projects/github"
      pushd "$HOME/projects/github"
      git clone git@github.com:burnettk/ergo-slack.git
      popd
    fi

    if [[ "$(git config --get remote.origin.url)" == "https://github.com/burnettk/computer-setup.git" ]]; then
      git remote set-url origin 'git@github.com:burnettk/computer-setup.git'
    fi
  fi

  install_brew_casks inkscape zoom
fi
