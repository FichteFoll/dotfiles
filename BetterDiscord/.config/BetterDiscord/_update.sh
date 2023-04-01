#!/usr/bin/env zsh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$DIR/plugins"
wget -N https://github.com/BetterDiscordPlugins/userscripts/raw/master/NRM.plugin.js
wget -N https://github.com/jaimeadf/BetterDiscordPlugins/raw/build/BiggerStreamPreview/dist/BiggerStreamPreview.plugin.js
wget -N https://github.com/jaimeadf/BetterDiscordPlugins/raw/build/WhoReacted/dist/WhoReacted.plugin.js
wget -N https://github.com/l0c4lh057/BetterDiscordStuff/raw/master/Plugins/TypingIndicator/TypingIndicator.plugin.js
wget -N https://github.com/Metalloriff/BetterDiscordPlugins/raw/master/DoubleClickVoiceChannels.plugin.js
wget -N https://github.com/mwittrien/BetterDiscordAddons/raw/master/Library/0BDFDB.plugin.js
wget -N https://github.com/mwittrien/BetterDiscordAddons/raw/master/Plugins/EditUsers/EditUsers.plugin.js
wget -N https://github.com/mwittrien/BetterDiscordAddons/raw/master/Plugins/RemoveBlockedUsers/RemoveBlockedUsers.plugin.js
wget -N https://github.com/rauenzi/BDPluginLibrary/raw/master/release/0PluginLibrary.plugin.js
wget -N https://github.com/rauenzi/BetterDiscordAddons/raw/master/Plugins/AccountDetailsPlus/AccountDetailsPlus.plugin.js
wget -N https://github.com/rauenzi/BetterDiscordAddons/raw/master/Plugins/BetterRoleColors/BetterRoleColors.plugin.js
wget -N https://github.com/rauenzi/BetterDiscordAddons/raw/master/Plugins/DoNotTrack/DoNotTrack.plugin.js
wget -N https://github.com/rauenzi/BetterDiscordAddons/raw/master/Plugins/HideDisabledEmojis/HideDisabledEmojis.plugin.js
wget -N https://github.com/Strencher/BetterDiscordStuff/raw/master/PlatformIndicators/APlatformIndicators.plugin.js
wget -N https://github.com/Strencher/BetterDiscordStuff/raw/master/SuppressReplyMentions/SuppressReplyMentions.plugin.js

# the following have been broken by a discord update and have not yet been fixed
#wget -N https://github.com/Arashiryuu/crap/raw/master/greenText.plugin.js
#wget -N https://github.com/jaimeadf/BetterDiscordPlugins/raw/release/dist/GuildProfile/GuildProfile.plugin.js
#wget -N https://github.com/jaimeadf/BetterDiscordPlugins/raw/release/dist/WhoReacted/WhoReacted.plugin.js
#wget -N https://github.com/l0c4lh057/BetterDiscordStuff/raw/master/Plugins/ChannelTabs/ChannelTabs.plugin.js

# never worked or not using anymore
#wget -N https://github.com/Finicalmist/CopyCode/raw/master/copyCode.plugin.js
#wget -N https://github.com/Inve1951/BetterDiscordStuff/raw/master/plugins/linkProfilePicture.plugin.js
#wget -N https://github.com/Jiiks/BetterDiscordApp/raw/master/Plugins/dblClickEdit.plugin.js
wget -N https://github.com/mwittrien/BetterDiscordAddons/raw/master/Plugins/DisplayServersAsChannels/DisplayServersAsChannels.plugin.js
wget -N https://github.com/mwittrien/BetterDiscordAddons/raw/master/Plugins/MessageUtilities/MessageUtilities.plugin.js
wget -N https://github.com/rauenzi/BetterDiscordAddons/raw/master/Plugins/PermissionsViewer/PermissionsViewer.plugin.js
wget -N https://github.com/rauenzi/BetterDiscordAddons/raw/master/Plugins/RoleMembers/RoleMembers.plugin.js

cd "$DIR/themes"
# wget -N https://github.com/Inve1951/BetterDiscordStuff/raw/master/themes/showURLs.theme.css
# wget -N https://github.com/rauenzi/BetterDiscordAddons/raw/master/Themes/RadialStatus/RadialStatus.theme.css
# wget -N https://github.com/rauenzi/Nox/raw/master/release/Nox.theme.css
