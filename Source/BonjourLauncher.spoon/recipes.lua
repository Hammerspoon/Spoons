--- === BonjourLauncher.recipes ===
---
--- Sample recipes for various service types that you can use with the BonjourLauncher spoon.
---
--- This submodule includes sample templates for a variety of advertised services which may be of interest when used with the BonjourLauncher spoon. Each template can be displayed in the Hammerspoon console for reference by typing `help.spoon.BonjourLauncher.recipes.*name*` into the console input field, or added as is to the active templates of the BonjourLauncher by doing the following either in the Hammerspoon console or in your configuration `init.ua` file:
---
---     hs.loadSpoon("BonjourLauncher")
---     spoon.BonjourLauncher:addRecipes(*name*)
---
--- where *name* is one of the variables described within this submodule.

local image    = require("hs.image")
local canvas   = require("hs.canvas")
local urlevent = require("hs.urlevent")

local module = {}

--- BonjourLauncher.recipes.SSH
--- Variable
--- Display computers and servers advertising Secure Shell services advertised with the `_ssh._tcp.` service type. This is advertised by MacOS machines with Remote Login enabled in the Sharing panel of System Preferences.
---
--- Notes:
---  * SSH connections are initiated by the URL `ssh://%hostname%:%port%`, which usually opens up a Terminal window with the SSH session, and assumes that the username matches your username on your Mac. At present there is no way to prompt for a different username at the time of connection -- you will need to modify your `~/.ssh/config` file if a different username is required for a specific host. See `man ssh_config` in a terminal window.
---  * The template can be added to your BonjourLauncer with `spoon.BonjourLauncher:addRecipes("SSH")` after the spoon has loaded, and is defined as follows:
---     {
---         image   = hs.image.imageFromAppBundle("com.apple.Terminal"),
---         label   = "SSH",
---         type    = "_ssh._tcp.",
---         text    = "%name%",
---         subText = "%hostname%:%port% (%address4%/%address6%)",
---         url     = "ssh://%hostname%:%port%",
---     }
---  * On Linux servers, you can advertise this by installing Avahi and saving the following in `/etc/avahi/services/ssh.service`:
---     ~~~
---     <?xml version="1.0" standalone='no'?>
---     <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
---     <service-group>
---       <name replace-wildcards="yes">%h</name>
---       <service>
---         <type>_ssh._tcp</type>
---         <port>22</port>
---       </service>
---     </service-group>
---     ~~~
module.SSH = {
    image   = image.imageFromAppBundle("com.apple.Terminal"),
    label   = "SSH",
    type    = "_ssh._tcp.",
    text    = "%name%",
    subText = "%hostname%:%port% (%address4%/%address6%)",
    url     = "ssh://%hostname%:%port%",
}

--- BonjourLauncher.recipes.SMB
--- Variable
--- Display computers and servers advertising Windows or Samba file server services advertised with the `_smb._tcp.` service type. Most Apple Macintosh computers and Laptops will also advertise file sharing with this service type.
---
--- Notes:
---  * SMB connections are initiated by the URL `smb://%hostname%:%port%`, which usually opens up a dialog in the Finder which may prompt you for login credentials.
---  * The template can be added to your BonjourLauncer with `spoon.BonjourLauncher:addRecipes("SMB")` after the spoon has loaded, and is defined as follows:
---     {
---         image   = hs.image.imageFromName("NSNetwork"),
---         label   = "SMB",
---         type    = "_smb._tcp.",
---         text    = "%name%",
---         subText = "smb://%hostname%:%port%",
---         url     = "smb://%hostname%:%port%",
---     }
---  * On Linux servers, Samba advertises this by default if Avahi is installed.
module.SMB = {
    image   = image.imageFromName("NSNetwork"),
    label   = "SMB",
    type    = "_smb._tcp.",
    text    = "%name%",
    subText = "smb://%hostname%:%port%",
    url     = "smb://%hostname%:%port%",
}

--- BonjourLauncher.recipes.AFP
--- Variable
--- Display computers and servers advertising AppleShare file server services advertised with the `_afpovertcp._tcp.` service type. This was the default with earlier versions of MacOS and is still used by Apple AirPort and Time Machine file servers.
---
--- Notes:
---  * AppleShare connections are initiated by the URL `afp://%hostname%:%port%`, which usually opens up a dialog in the Finder which may prompt you for login credentials.
---  * The template can be added to your BonjourLauncer with `spoon.BonjourLauncher:addRecipes("AFP")` after the spoon has loaded, and is defined as follows:
---     {
---         image   = hs.canvas.new{ h = 128, w = 128 }:appendElements(
---                       { type="image", image = hs.image.imageFromName("NSNetwork"), imageAlpha = 0.5 },
---                       { type="image", image = hs.image.imageFromName("NSTouchBarColorPickerFont") }
---                   ):imageFromCanvas(),
---         label   = "AFP",
---         type    = "_afpovertcp._tcp.",
---         text    = "%name%",
---         subText = "afp://%hostname%:%port%",
---         url     = "afp://%hostname%:%port%",
---     }
module.AFP = {
    image   = canvas.new{ h = 128, w = 128 }:appendElements(
                              { type="image", image = image.imageFromName("NSNetwork"), imageAlpha = 0.5 },
                              { type="image", image = image.imageFromName("NSTouchBarColorPickerFont") }
              ):imageFromCanvas(),
    label   = "AFP",
    type    = "_afpovertcp._tcp.",
    text    = "%name%",
    subText = "afp://%hostname%:%port%",
    url     = "afp://%hostname%:%port%",
}

--- BonjourLauncher.recipes.VNC
--- Variable
--- Display computers and servers advertising screen sharing or VNC services advertised with the `_rfb._tcp.` service type. This is advertised by MacOS machines with Screen Sharing enabled in the Sharing panel of System Preferences.
---
--- Notes:
---  * Screen Sharing connections are initiated by the URL `vnc://%hostname%:%port%`, which usually opens up Screen Sharing which will prompt you for login credentials.
---  * The template can be added to your BonjourLauncer with `spoon.BonjourLauncher:addRecipes("VNC")` after the spoon has loaded, and is defined as follows:
---     {
---         image   = hs.image.imageFromAppBundle("com.apple.ScreenSharing"),
---         label   = "VNC",
---         type    = "_rfb._tcp.",
---         text    = "%name%",
---         subText = "vnc://%hostname%:%port%",
---         url     = "vnc://%hostname%:%port%",
---     }
---  * The built in MacOS Screen Sharing application works with MacOS Screen Sharing clients as well as more traditional VNC implementations that do not implement encryption. This does *not* include the RealVNC implementation that is commonly included with Raspberry Pi's Raspbian installations.
---  * See also [BonjourLauncher.recipes.VNC_RealVNC_Alternate](#VNC_RealVNC_Alternate) for an example that can use an alternate launcher for RealVNC clients. Note that you sould use only one of these recipes, as they share the same label.
---  * On Linux servers, some X Windows installations provide built in VNC support while others require you to configure your own with third party software (e.g. RealVNC or TigerVNC to name just a couple). Determining how to set this up is beyond the scope of these instructions, but if you find that whatever solution you have available does *not* provide ZeroConf or Bonjour advertisements, you can do so yourself by installing Avahi and saving the following in `/etc/avahi/services/vnc.service` (change 5900 to match the port number your windowing environment uses for VNC, commonly a number between 5900 and 5910 inclusive, but theoretically any available port on the machine):
---     ~~~
---     <?xml version="1.0" standalone='no'?>
---     <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
---     <service-group>
---       <name replace-wildcards="yes">%h</name>
---       <service>
---         <type>_rfb._tcp</type>
---         <port>5900</port>
---       </service>
---     </service-group>
---     ~~~
module.VNC = {
    image   = image.imageFromAppBundle("com.apple.ScreenSharing"),
    label   = "VNC",
    type    = "_rfb._tcp.",
    text    = "%name%",
    subText = "vnc://%hostname%:%port%",
    url     = "vnc://%hostname%:%port%",
}

--- BonjourLauncher.recipes.VNC_RealVNC_Alternate
--- Variable
--- Display computers and servers advertising screen sharing or VNC services advertised with the `_rfb._tcp.` service type. This is advertised by MacOS machines with Screen Sharing enabled in the Sharing panel of System Preferences.
---
--- Notes:
---  * This version of a template for `_rfb._tcp.` differs from [BonjourLauncher.recipes.VNC](#VNC) in that it uses a function which examines the text records for the service to determine which launcher to use for the chosen server: because RealVNC uses an encryption scheme that is not recognized by the macOS Screen Sharing application, if a text record indicating that RealVNC is in use is detected, an alternate launcher is used.
---  * The template can be added to your BonjourLauncer with `spoon.BonjourLauncher:addRecipes("VNC_RealVNC_Alternate")` after the spoon has loaded, and is defined as follows:
---     {
---         image   = hs.image.imageFromAppBundle("com.apple.ScreenSharing"),
---         label   = "VNC",
---         type    = "_rfb._tcp.",
---         text    = "%name%",
---         subText = "vnc://%hostname%:%port%",
---         url     = "vnc://%hostname%:%port%", -- used in fn when RealVNC not set ; see below
---         cmd     = "open -a \"VNC Viewer\" --args %hostname%:%port%", -- used in fn when RealVNC set; see below
---         fn      = function(svc, choice)
---             local tr = svc:txtRecord()
---             if tr and tr.RealVNC then
---                 hs.execute(choice.cmd)
---             else
---                 hs.urlevent.openURL(choice.url)
---             end
---         end,
---     }
---  * Note that `fn` is defined, so it will be invoked in favor of `url` or `cmd` by the BonjourLauncer spoon when a VNC service is selected; however, the second argument to the function invoked will include all key-value pairs with string values from the template, so the function can utilizes the `url` and `cmd` keys based on its own logic to determine which applies.
---  * This variant was developed to address the fact that the macOS Screen Sharing application does not recognize the encryption used by the RealVNC implemntataion found in the Raspbian distribution installed on most Raspberry Pi computers. By adding text record to the Avahi advertisement from the Raspberry Pi, we can determine whether or not to utilize the built in screen sharing app or launch the RealVNC client to view the specified service.
---  * See also [BonjourLauncher.recipes.VNC](#VNC) for a simpler implementation if you are only connecting to other Mac computers or if none of your servers require RealVNC's specific viewer application.
---  * To create the advertisement on the Raspbian installation which includes the text record entry we need to make this template work, install Avahi on your Raspbian machine and save the following as `/etc/avahi/services/vnc.service`:
---     ~~~
---     <?xml version="1.0" standalone='no'?>
---     <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
---     <service-group>
---       <name replace-wildcards="yes">%h</name>
---       <service>
---         <type>_rfb._tcp</type>
---         <port>5900</port>
---         <txt-record>RealVNC=True</txt-record>
---       </service>
---     </service-group>
---     ~~~
module.VNC_RealVNC_Alternate = {
    image   = image.imageFromAppBundle("com.apple.ScreenSharing"),
    label   = "VNC",
    type    = "_rfb._tcp.",
    text    = "%name%",
    subText = "vnc://%hostname%:%port%",
    url     = "vnc://%hostname%:%port%", -- used in fn when RealVNC not set ; see below
    cmd     = "open -a \"VNC Viewer\" --args %hostname%:%port%", -- used in fn when RealVNC set; see below
    fn      = function(svc, choice)
        local tr = svc:txtRecord()
        if tr and tr.RealVNC then
            hs.execute(choice.cmd)
        else
            urlevent.openURL(choice.url)
        end
    end,
}

return module
