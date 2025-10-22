#invoke-Command -VMName "SRV-HYP-2" -Credential $Creds {
$server = "SRV-HYP-2"
$folder = "C:\CRL"
$url = "http://$server/crl/crl.crl"
$inf = "$folder\cert.inf"
$req = "$folder\cert.req"
$cer = "$folder\$server.cer"
New-Item -Path $folder -ItemType Directory -Force | Out-Null
@'
[Version]
Signature=$Windows NT$

[NewRequest]
Subject = CN=SRV-HYP-2
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
RequestType = Cert
ProviderName = Microsoft RSA SChannel Cryptographic Provider
ProviderType = 12
KeyUsage = 0xa0

[Extensions]
2.5.29.19 = {text}
    BasicConstraints=CA=FALSE
2.5.29.31 = {text}
    http://SRV-HYP-2/crl/crl.crl
'@ | Set-Content -Path $inf -Encoding ASCII

#certutil -crl
#Copy-Item -Path "$env:SystemRoot\System32\CertSrv\CertEnroll\SRV-HYP-2.crl" "$folder\srv-hyp-2.crl" -Force