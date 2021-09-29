param (
    [string] $siteName = 'Default Web Site'
)

$pspath = "MACHINE/WEBROOT/APPHOST/$siteName"

Add-WebConfigurationProperty -pspath $pspath -filter "system.webServer/staticContent" -name "." -value `
@{
    fileExtension = '.'
    mimeType      = 'application/json' 
}


Add-WebConfigurationProperty -pspath $pspath -filter "system.webServer/rewrite/rules" -name "." -value `
@{name             = 'lets-encrypt-challenge'
    stopProcessing = 'True'
    match          = @{ url = ".well-known/acme-challenge/(.*)" }
    action         = @{ type = 'None' }
}

Add-WebConfigurationProperty -pspath $pspath -filter "system.webServer/rewrite/rules" -name "." -value `
@{
    name           = 'https-only'
    stopProcessing = 'True'
    match          = @{ url = '(.*)' }
    conditions     = @{
        input   = '{HTTPS}'
        pattern = '^OFF$'
    };
    action         = @{
        type              = 'Redirect'
        url               = "https://{HTTP_HOST}{REQUEST_URI}"
        redirectType      = "Found"
        appendQueryString = "false"
    }
}
