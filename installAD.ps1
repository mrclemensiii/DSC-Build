Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name xActiveDirectory -Force
Install-Module -Name NetworkingDsc -Force

configuration DomainInit {
    Param(
      [Parameter(Position=0)]
      [String]$DomainMode='WinThreshold',
  
      [Parameter(Position=1)]
      [String]$ForestMode='WinThreshold',
  
      [Parameter(Position=2,Mandatory=$true)]
      [PSCredential]$DomainCredential,
  
      [Parameter(Position=3,Mandatory=$true)]
      [PSCredential]$SafemodePassword,
  
      [Parameter(Position=4)]
      [String]$NetAdapterName='Ethernet0'
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName NetworkingDsc
    
  
    Node $ENV:COMPUTERNAME {
      WindowsFeature ADDSFeatureInstall {
        Ensure = 'Present';
        Name = 'AD-Domain-Services';
        DependsOn = '[NetAdapterName]InterfaceRename';
      }
      $domainContainer="DC=$($Node.DomainName.Split('.') -join ',DC=')"
  
      xADDomain 'ADDomainInstall' {
        DomainName = $Node.DomainName;
        DomainNetbiosName = $Node.DomainName.Split('.')[0];
        ForestMode = $ForestMode;
        DomainMode = $DomainMode;
        DomainAdministratorCredential = $DomainCredential;
        SafemodeAdministratorPassword = $SafemodePassword;
        DependsOn = '[WindowsFeature]ADDSFeatureInstall';
      }
  
      xWaitForADDomain 'WaitForDomainInstall' {
        DomainName = $Node.DomainName;
        DomainUserCredential = $DomainCredential;
        RebootRetryCount = 2;
        RetryCount = 10;
        RetryIntervalSec = 60;
        DependsOn = '[xADDomain]ADDomainInstall';
      }
  
      xADOrganizationalUnit 'CreateAccountsOU' {
        Name = 'Accounts';
        Path = $DomainContainer;
        Ensure = 'Present';
        Credential = $DomainCredential;
        DependsOn = '[xWaitForADDomain]WaitForDomainInstall';
      }
  
      xADOrganizationalUnit 'AdminOU' {
        Name = 'Admin';
        Path = "OU=Accounts,$DomainContainer";
        Ensure = 'Present';
        Credential = $DomainCredential;
        DependsOn = '[xADOrganizationalUnit]CreateAccountsOU';
      }
      
      xADOrganizationalUnit 'BusinessOU' {
        Name = 'Business';
        Path = "OU=Accounts,$DomainContainer";
        Ensure = 'Present';
        Credential = $DomainCredential;
        DependsOn = '[xADOrganizationalUnit]CreateAccountsOU';
      }
  
      xADOrganizationalUnit 'ServiceOU' {
        Name = 'Service';
        Path = "OU=Accounts,$DomainContainer";
        Ensure = 'Present';
        Credential = $DomainCredential;
        DependsOn = '[xADOrganizationalUnit]CreateAccountsOU';
      }
  
      NetAdapterName InterfaceRename {
        NewName = $NetAdapterName;
      }
  
      IPAddress StaticIP {
        InterfaceAlias = $NetAdapterName;
        AddressFamily = 'IPv4';
        IPAddress = $Node.IPv4Address;
        DependsOn = '[NetAdapterName]InterfaceRename';
      }
  
      DnsServerAddress SetDnsServer {
        InterfaceAlias = $NetAdapterName;
        AddressFamily = 'IPv4';
        Address = '127.0.0.1';
        DependsOn = '[NetAdapterName]InterfaceRename';
      }
  
      FirewallProfile DomainFirewallOff {
        Name = 'Domain';
        Enabled = 'False';
      }
  
      FirewallProfile PublicFirewallOff {
        Name = 'Public';
        Enabled = 'False';
      }
  
      FirewallProfile PrivateFirewallOff {
        Name = 'Private';
        Enabled = 'False';
      }
  
      LocalConfigurationManager {
        CertificateId = $Node.Thumbprint;
        RebootNodeIfNeeded = $true;
      }
    }
  }

  # Self signed certificate in the local computer certificate store
$cert=Get-Item -Path 'Cert:\LocalMachine\My\FF5A2FA9B4CF43B0CB0F9140402CDE0B5C3DAD7B'

# The certificate has been exported to this path
$certFilePath='C:\dsc\cert\DscPubKey.cer'

# The certificate has been exported to this path
$certFilePath='C:\dsc\cert\DscPubKey.cer'

  # Customize this with your details
$config=@{
    AllNodes=@(
      @{
        NodeName=$ENV:COMPUTERNAME;
        DomainName='rc.com';
        IPV4Address='10.0.0.5/24';
        Thumbprint=$cert.Thumbprint;
        CertificateFile=$certFilePath;
      }
    )
  }
  
  $domainCred=Get-Credential
  
  # Generate configuration MOF files
  DomainInit -ConfigurationData $config `
    -OutputPath C:\dsc\AD `
    -DomainCredential $domainCred `
    -SafemodePassword $domainCred


# Configure the LCM
Set-DscLocalConfigurationManager -Path C:\dsc\AD -Force -Verbose

# Apply the Dsc Configuration 
Start-DscConfiguration -Path C:\dsc\AD -Force -Wait -Verbose