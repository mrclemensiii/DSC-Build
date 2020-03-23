@{
    AllNodes = @(
      @{
        NodeName = $env:COMPUTERNAME
        WindowsFeatures = @(
          @{
            Name = "Web-Server"
            Ensure = "Present"
          },
          @{
            Name = "Web-Mgmt-Tools"
            Ensure = "Present"
          },
          @{
            Name = "Web-Default-Doc"
            Ensure = "Present"
          }
        )
      }
    )
  }