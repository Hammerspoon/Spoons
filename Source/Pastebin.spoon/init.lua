--- === Pastebin ===
---
--- Send clipboard contents to Pastebin
---
--- Conversion of tldm's pastebin gist to a Spoon https://gist.github.com/tdlm/5eba0299f2924a8aaf46
--- Code by @tdlm, spoon by Tyler Thrailkill <tyler.b.thrailkill@gmail.com>
---
--- https://github.com/snowe2010

local obj = {}
obj.__index = obj

-- Metadata
obj.name = 'Pastebin'
obj.version = '1.0'
obj.author = 'Tyler Thrailkill <tyler.b.thrailkill@gmail.com>'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

--- Pastebin.api_dev_key
--- Variable
--- String api developer key. Can be found [here](http://pastebin.com/api)
obj.api_dev_key = nil

--- Pastebin.api_user_key
--- Variable
--- String api user key. Can be generated [here](http://pastebin.com/api/api_user_key.html)
obj.api_user_key = nil

--- Pastebin.private
--- Variable
--- Integer indicating whether a paste should be public, unlisted, or private. Default is 0 (public). (0=public, 1=unlisted, 2=private)
obj.private = 0

--- Pastebin.expire
--- Variable
--- String indicating how long until the paste expires. Default is 'N' (Never)
obj.expire = 'N'
expire_times = {'N', '10M', '1H', '1D', '1W', '2W', '1M', '6M', '1Y'}

--- Pastebin.format
--- Variable
--- String indicating the format of the paste. Default is 'text' (plain text). 
--- Valid formats at this time are (current list can be found [here](https://pastebin.com/api#5)): 
--- '4cs'
--- '6502acme'
--- '6502kickass'
--- '6502tasm'
--- 'abap'
--- 'actionscript'
--- 'actionscript3'
--- 'ada'
--- 'aimms'
--- 'algol68'
--- 'apache'
--- 'applescript'
--- 'apt_sources'
--- 'arm'
--- 'asm'
--- 'asp'
--- 'asymptote'
--- 'autoconf'
--- 'autohotkey'
--- 'autoit'
--- 'avisynth'
--- 'awk'
--- 'bascomavr'
--- 'bash'
--- 'basic4gl'
--- 'dos'
--- 'bibtex'
--- 'blitzbasic'
--- 'b3d'
--- 'bmx'
--- 'bnf'
--- 'boo'
--- 'bf'
--- 'c'
--- 'c_winapi'
--- 'c_mac'
--- 'cil'
--- 'csharp'
--- 'cpp'
--- 'cpp-winapi'
--- 'cpp-qt'
--- 'c_loadrunner'
--- 'caddcl'
--- 'cadlisp'
--- 'ceylon'
--- 'cfdg'
--- 'chaiscript'
--- 'chapel'
--- 'clojure'
--- 'klonec'
--- 'klonecpp'
--- 'cmake'
--- 'cobol'
--- 'coffeescript'
--- 'cfm'
--- 'css'
--- 'cuesheet'
--- 'd'
--- 'dart'
--- 'dcl'
--- 'dcpu16'
--- 'dcs'
--- 'delphi'
--- 'oxygene'
--- 'diff'
--- 'div'
--- 'dot'
--- 'e'
--- 'ezt'
--- 'ecmascript'
--- 'eiffel'
--- 'email'
--- 'epc'
--- 'erlang'
--- 'euphoria'
--- 'fsharp'
--- 'falcon'
--- 'filemaker'
--- 'fo'
--- 'f1'
--- 'fortran'
--- 'freebasic'
--- 'freeswitch'
--- 'gambas'
--- 'gml'
--- 'gdb'
--- 'genero'
--- 'genie'
--- 'gettext'
--- 'go'
--- 'groovy'
--- 'gwbasic'
--- 'haskell'
--- 'haxe'
--- 'hicest'
--- 'hq9plus'
--- 'html4strict'
--- 'html5'
--- 'icon'
--- 'idl'
--- 'ini'
--- 'inno'
--- 'intercal'
--- 'io'
--- 'ispfpanel'
--- 'j'
--- 'java'
--- 'java5'
--- 'javascript'
--- 'jcl'
--- 'jquery'
--- 'json'
--- 'julia'
--- 'kixtart'
--- 'kotlin'
--- 'latex'
--- 'ldif'
--- 'lb'
--- 'lsl2'
--- 'lisp'
--- 'llvm'
--- 'locobasic'
--- 'logtalk'
--- 'lolcode'
--- 'lotusformulas'
--- 'lotusscript'
--- 'lscript'
--- 'lua'
--- 'm68k'
--- 'magiksf'
--- 'make'
--- 'mapbasic'
--- 'markdown'
--- 'matlab'
--- 'mirc'
--- 'mmix'
--- 'modula2'
--- 'modula3'
--- '68000devpac'
--- 'mpasm'
--- 'mxml'
--- 'mysql'
--- 'nagios'
--- 'netrexx'
--- 'newlisp'
--- 'nginx'
--- 'nim'
--- 'text'
--- 'nsis'
--- 'oberon2'
--- 'objeck'
--- 'objc'
--- 'ocaml-brief'
--- 'ocaml'
--- 'octave'
--- 'oorexx'
--- 'pf'
--- 'glsl'
--- 'oobas'
--- 'oracle11'
--- 'oracle8'
--- 'oz'
--- 'parasail'
--- 'parigp'
--- 'pascal'
--- 'pawn'
--- 'pcre'
--- 'per'
--- 'perl'
--- 'perl6'
--- 'php'
--- 'php-brief'
--- 'pic16'
--- 'pike'
--- 'pixelbender'
--- 'pli'
--- 'plsql'
--- 'postgresql'
--- 'postscript'
--- 'povray'
--- 'powerbuilder'
--- 'powershell'
--- 'proftpd'
--- 'progress'
--- 'prolog'
--- 'properties'
--- 'providex'
--- 'puppet'
--- 'purebasic'
--- 'pycon'
--- 'python'
--- 'pys60'
--- 'q'
--- 'qbasic'
--- 'qml'
--- 'rsplus'
--- 'racket'
--- 'rails'
--- 'rbs'
--- 'rebol'
--- 'reg'
--- 'rexx'
--- 'robots'
--- 'rpmspec'
--- 'ruby'
--- 'gnuplot'
--- 'rust'
--- 'sas'
--- 'scala'
--- 'scheme'
--- 'scilab'
--- 'scl'
--- 'sdlbasic'
--- 'smalltalk'
--- 'smarty'
--- 'spark'
--- 'sparql'
--- 'sqf'
--- 'sql'
--- 'standardml'
--- 'stonescript'
--- 'sclang'
--- 'swift'
--- 'systemverilog'
--- 'tsql'
--- 'tcl'
--- 'teraterm'
--- 'thinbasic'
--- 'typoscript'
--- 'unicon'
--- 'uscript'
--- 'upc'
--- 'urbi'
--- 'vala'
--- 'vbnet'
--- 'vbscript'
--- 'vedit'
--- 'verilog'
--- 'vhdl'
--- 'vim'
--- 'visualprolog'
--- 'vb'
--- 'visualfoxpro'
--- 'whitespace'
--- 'whois'
--- 'winbatch'
--- 'xbasic'
--- 'xml'
--- 'xorg_conf'
--- 'xpp'
--- 'yaml'
--- 'z80'
--- 'zxbasic'
obj.format = 'text'

--- Pastebin.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Pastebin')

--- Pastebin:paste(private, expire, format)
--- Method
--- Pastes an item to Pastebin using the Pastebin api
---
--- Parameters:
---  * private - Integer specifying whether the paste should be public, private, or unlisted. Defaults to obj.private (0=public)
---  * expire - String specifying the TTL for the paste. Defaults to obj.expire ('N'=never). Valid values are listed on obj.expire
---  * format - String specifying the appropriate Pastebin format enum. Default is obj.format ('text'). Valid values are listed on obj.format
function obj:paste(private, expire, format)
    private = private or obj.private
    expire = expire or obj.expire
    format = format or obj.format

    assert(obj.api_dev_key, 'API Dev key must be provided')
    assert(obj.api_user_key, 'API User key must be provided')

    local board = hs.pasteboard.getContents()
    obj.logger.df("clipboard contents %s", board)
    obj.logger.df("obj.api_dev_key %s", obj.api_dev_key)
    obj.logger.df("obj.api_user_key %s", obj.api_user_key)
    obj.logger.df("private %s", private)
    obj.logger.df("expire %s", expire)
    obj.logger.df("format %s", format)

    local response =
        hs.http.asyncPost(
        'http://pastebin.com/api/api_post.php',
        string.format(
            'api_option=paste&api_dev_key=%s&api_user_key=%s&api_paste_private=%s&api_paste_expire_date=%s&api_paste_format=%s&api_paste_code=%s',
            obj.api_dev_key,
            obj.api_user_key,
            private,
            expire,
            format,
            hs.http.encodeForQuery(board)
        ),
        {},
        function(http_code, response)
            if http_code == 200 then
                hs.pasteboard.setContents(response)
                hs.notify.new({title = 'Pastebin Paste Successful', informativeText = response}):send()
                obj.logger.df("pastebin response: %s", response)
            else
                hs.notify.new({title = 'Pastebin Paste Failed!', informativeText = response}):send()
                obj.logger.df("pastebin response: %s", response)
            end
        end
    )
end

--- Pastebin:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for Pastebin
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * paste - paste to Pastebin
function obj:bindHotkeys(keys)
    assert(keys['paste'], "Hotkey variable is 'paste'")

    hs.hotkey.bindSpec(
        keys['paste'],
        'Paste an item to Pastebin.',
        function()
            self:paste()
        end
    )
end

return obj
