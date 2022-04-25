# Installing a SSL certificate from Let's encrypt

We recommend that you configure your DocuWare installation
so that all HTTP traffic is encrypted.
While HTTP encryption is optional for DocuWare 7.5, it
becomes mandatory for DocuWare 7.6.
You should configure your DocuWare
installation already today so that all HTTP traffic is protected with
TLS encryption.

One of the challenges is getting an SSL certificate from a certificate provider.
For DocuWare you can choose any provider you trust. If you are not familiar
with certificate request, you should consider getting a certificate from
[Let's Encrypt](https://letsencrypt.org/), which is described here.

This article describes necessary steps to install and maintain SSL
certificates in a Windows-based environment which uses the IIS
to host DocuWare or which uses the IIS and the ARR module to host
DocuWare behind a reversed proxy.

If you are not using IIS, or if you have a more complex setup, or if you use
appliances for SSL offloading, you should check the documentation of
[certbot](https://certbot.eff.org/), how your configuration is supported.

Your IIS must be reachable from the public, either directly or behind a firewall.
If the server is not public facing, there are other
[options](https://blog.heckel.io/2018/08/05/issuing-lets-encrypt-certificates-for-65000-internal-servers/)
which are not covered here. Another approach is to generate a self-signed
certificat and roll it out using group policies, as described in
our [Knowledge Base](https://support.docuware.com/en-US/knowledgebase/article/KBA-35780).
But future versions of web browsers may not support this solution.

For this article, we assume you run a corporation which owns the
domain ```peters-engineering.biz```. and want to host your own DocuWare at
```docuware.peters-engineering.biz```.

## Prerequisites

You should have a host with IIS installed and running, and you should have enough
privileges to configure the IIS and the host machine. The IIS must be reachable from
the public and must listen to the domain `docuware.peters-engineering.biz`.

To obtain a certificate from [Let's encrypt](https://letsencrypt.org/) you can use a bot,
which does the [necessary steps](https://letsencrypt.org/how-it-works/) for you. There
is [a variety of bots](https://letsencrypt.org/docs/client-options/) available. In this
article, we use [win-acme](https://www.win-acme.com/), which is easy to use, while providing
all the necessary features.

## Preparing the IIS

The IIS must be prepared to run the certificate installation automatically, and to enforce all
not encrypted requests to get redirected to encrypted requests. This requires the [URL Rewrite module](https://www.iis.net/downloads/microsoft/url-rewrite) installed in the IIS:

* If the URL Rewrite module is not yet installed, then install it. (If you have the ARR module is already installed on the IIS, you can skip this step.)

* Configure the IIS default web site: Run the following script in an elevated Powershell, or
  download and run [configure-iis.ps1](./configure-iis.ps1).
  If you have more than one sites in your IIS, you must
  change the `$pspath` variable.
  
    ```powershell
    $pspath = 'MACHINE/WEBROOT/APPHOST/Default Web Site'

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
    ```

  When this is done, you should have a `web.config` file in the folder `c:\inetpub\wwwroot`
  which looks similar to [this file](./web.config).

## Installing the bot

Download the [win-acme installer](https://github.com/win-acme/win-acme/releases/)
(_win-acme.\*.x64.trimmed.zip_ or _win-acme.\*.x64.pluggable.zip_)
and extract the
archive to a location of your choice. You should consider renaming the extraction folder to
a self-speaking name.

## Running the bot

Change into the extraction directory and run `.\wacs.exe`.

In the first screen, you get asked if you want to create the certificate using _default settings_ or _full options_. You can use the _default settings_ only in case an SSL binding is configured already - which is most likely not the case. So choose `M`. Then choose `2` to continue with _manual input_.

You get asked for the host name. Enter `docuware.peters-engineering.biz`.
In the next screen you can give the
certificate a proper name. If you are fine with the default, just go ahead.

In the next screen you must choose how the certificate authority
validates the ownership of the domain. You should read the text and check
which challenge fits best to your needs.
In our example, we are fine with a HTTP-based challenge and go ahead with `2`.

Then you must choose the kind of the key. The default choice requests a certificate
which uses the RSA algorithm with a long key. The modern ecliptic curve algorithm (ECC)
should be considered already today, because it provides the same security with shorter keys.
The trend is, that RSA is more and more replaced by ECC. Therefore, we choose ECC and select `1`.

In the next step you decide where the certificate's private key is stored. If you have
a single-machine installation, you should choose the _Windows Certificate Store_.
If you have a cluster with more than one IIS server, you should choose the _IIS Central Certifact Store_. In this case you must ensure that your IIS cluster is
[properly prepared](https://www.virtualizationhowto.com/2019/08/share-ssl-certificates-between-multiple-iis-servers-with-centralized-certificates/)
to support centralized certificates.

In our example, we use a single-host and pick `4`. In the next screen we choose the _Default_ location for the certificate.

In the following screen, you can configure another store, but we do not need this and
go ahead with `5`.

The next screen is about configuring the SSL binding in IIS. If there is no SSL binding configured,
we should let the bot do it. We choose the default `1`. The next question lists the sites of the
IIS. We take the _Default Web Site_. The next question about further steps should be answered
with _No_.

Then the certificate challenge starts. If everything succeeds, then you have a fully working HTTPS
binding in th IIS.

Because the SSL certificates expirer after 3 months, the bot offers you to install a scheduled
tasks which periodically checks if a the certificate should be renewed.
You should accept this offer, and then you do not need to care about certificate renewal anymore.

## Final steps

After the certificate and the renewal tasks are installed,
you should change the DocuWare web connections so that they use URLs
starting with `https://`. Otherwise you still find `http://` URLs in
emails. Remove also any standard ports in the URLs, like `:80` or `:443`.

If you executed the few lines of Powershell code above, your IIS will redirect all requests
starting with `http://` to `https://`. This ensures, that users still using `http://` URLs
(e.g. when using bookmarks) are redirected.

If you did not execute the Powershell snippet, you should configure your IIS yourself, see
[DocuWare Knowledge Base](https://support.docuware.com/en-us/knowledgebase/article/KBA-35272).

It could be tempting to remove the HTTP binding from your IIS now. But we do not recommend this,
because then old bookmarks will not be served anymore.
