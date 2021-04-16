
resource_manifest_version "44febabe-d386-4d18-afbe-5e627f4af937"

dependencies {
    "np-toolbox",
    "np-tooltips",
    'mysql-async',
}
server_script '@mysql-async/lib/MySQL.lua'

client_script	"flayers-client.lua"
server_script	"flayers-server.lua"

ui_page ("html/index.html")
files ({
    'html/index.html',
    'html/index.js',
    'html/css.js',
    'html/index.css',
    'html/reset.css'
})