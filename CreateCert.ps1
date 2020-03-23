$certFolder='C:\dsc\cert'
$certStore='Cert:\LocalMachine\My'
$pubCertPath=Join-Path -Path $certFolder -ChildPath DscPubKey.cer
$expiryDate=(Get-Date).AddYears(2)

# You may want to delete this file after completing
$privateKeyPath=Join-Path -Path $ENV:TEMP -ChildPath DscPrivKey.pfx

$privateKeyPass=Read-Host -AsSecureString -Prompt "Private Key Password"

if(!(Test-Path -Path $certFolder)){
  New-Item -Path $certFolder -Type Directory | Out-Null
}

$cert=New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp `
  -DnsName 'DscEncryption' `
  -HashAlgorithm SHA512 `
  -NotAfter $expiryDate `
  -KeyLength 4096 `
  -CertStoreLocation $certStore

$cert | Export-PfxCertificate -FilePath $privateKeyPath `
  -Password $privateKeyPass `
  -Force

$cert | Export-Certificate -FilePath $pubCertPath 

Import-Certificate -FilePath $pubCertPath `
  -CertStoreLocation $certStore

Import-PfxCertificate -FilePath $privateKeyPath `
  -CertStoreLocation $certStore `
  -Password $privateKeyPass | Out-Null