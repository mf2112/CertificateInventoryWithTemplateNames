# This script will gather a list of domain servers and put together a certificate inventory.
# It attempts identify the template used where possible from AD domain issued certificates
# or just sets a name for external certificates.

[CmdletBinding()]
param()
# Get all "active" domain servers, test them, sort
$staledate = (Get-Date).AddDays(-90)
$computers = Get-ADComputer -Filter {(OperatingSystem -Like "*Server*") -and (Enabled -eq $True) -and (LastLogonDate -ge $staledate) -and (Modified -ge $staledate) -and (PasswordLastSet -ge $staledate) -and (whenChanged -ge $staledate)} | 
Select name -expandproperty name | Where {(Resolve-DNSName $_.name -ea 0) -and (Test-Connection -ComputerName $_.Name -Count 1 -ea 0)} | Sort

# Progress Bar
$Id = 101
$Total = $computers.count
$Step = 1
$Activity = "Activity"
$StatusText = "Server Certificate Inventory"
$StatusBlock = [ScriptBlock]::Create($StatusText)

# Prep output array and header for csv
$inv = @()
$inv += "Computer" + ";" + "IP" + ";" + "Subject" + ";" + "SAN" + ";" + "Thumbprint" + ";" + "Issuer Name" + ";" + "Template" + ";" + "Valid Until" + ";" + "Days to Expiration"

foreach ($computer in $computers){
    $Task = "Checking: $computer"
    # Get the certs from the server
    try {
    $certs = Invoke-Command -ComputerName $computer -ScriptBlock {
    get-childitem cert:\localmachine\my
    }
    }
    catch{
    Write-Verbose "Could not connect to $computer"
    Break
    }

    # Process the certs for values to add to report
    foreach ($cert in $certs){
        # Calculate expiration date
        $today = Get-Date
        $daystoexpire = New-TimeSpan -Start $today -End $cert.NotAfter
        If ($daystoexpire.Days -lt 0){$nodaystoexpire = "Expired"}
        Else {$nodaystoexpire = $daystoexpire.Days}

        # Get any Subject Alternative Names
        $san = $cert.DnsNameList -replace "{,}",""

        # Get the IP address 
        $IP = (Test-Connection $computer -count 1 -ErrorAction SilentlyContinue).IPV4Address
        $IP = $IP.IPAddressToString

        # Find the template name. Try different methods to weed out all unknown cases
        # First are the remote certificates that don't have template names
        # If the names are parsable from certificates, the second section will extract them
        # $template = ($Cert.extensions | where-object{$_.oid.FriendlyName -match "Certificate Template Information"}).format(0)
        # $template = $cert.extensions.Format(1)[0].split('(')[0] -replace "template="
        # $template = ($cert.extensions.Format(0) -replace "(.+)?=(.+)\((.+)?", '$2')[0]
        If ($cert.subject -like "*Azure*"){
        $template = "Azure"
        }
        ElseIf (($cert.subject -like "CN=CB_*") -and ($cert.issuer -eq $cert.subject)){
        $template = "Azure Backups"
        }
        ElseIf ($cert.subject -like "*NPS*"){
        $template = "Microsoft NPS Extension"
        }
        ElseIf ($cert.subject -like "OU=ST*"){
        $template = "Unknown"
        }
        ElseIf ($cert.subject -like "CN=DC1UTIL*"){
        $template = "WebServer"
        }
        ElseIf ($cert.subject -like "CN=SolarWinds*"){
        $template = "SolarWinds"
        }
        ElseIf ($cert.issuer -like "*DigiCert*"){
        $template = "DigiCert"
        }
        ElseIf ($cert.issuer -like "OU=www.verisign.com*"){
        $template = "Verisign"
        }
        ElseIf ($cert.issuer -like "*Dell*"){
        $template = "Dell Equallogic Self-Signed"
        }
        ElseIf ($cert.issuer -like "CN=SC_Online_Issuing"){
        $template = "SCCM"
        }
        ElseIf ($cert.issuer -like "CN=Xerox*"){
        $template = "Xerox"
        }
        ElseIf ($cert.issuer -eq $cert.subject){
        $template = "## Self Signed ##"
        }
        Else {
            try {
            $template = ($cert.extensions | Where-Object {$_.oid.FriendlyName -match "Certificate Template Information"}).format(0)
            If ($template -like "Domain Controller Authentication"){
                $template = "Domain Controller Authentication"
                $template.Trim() | Out-Null
                }
            # Clean up to get just the name
            $template = $template -replace '\([^\)]+\)'
            $template = $template -replace "Template=",""
            $template = $template -replace '(.+?),.+','$1'
            }
            catch {
                try {
                $template = $cert.extensions.Format(1)[0].split('(')[0] -replace "template="
                $template.Trim() | Out-Null
                    If ($template -like "DomainController*"){
                    $template = "Domain Controller"
                    $template.Trim() | Out-Null
                    }
                    If ($template -like "WebServer*"){
                    $template = "WebServer"
                    $template.Trim() | Out-Null
                    }
                    If ($template -like "Certificate Signing"){
                    $template = "Certificate Signing"
                    $template.Trim() | Out-Null
                    }
                    If ($template -like "Machine*"){
                    $template = "Machine"
                    $template.Trim() | Out-Null
                    }
                    }
                    catch {
                    $template = "Unknown"
                    }
            }
        }
        # Construct csv entry and add to master inv list
        $entry = $computer + ";" + $IP + ";" + $cert.subject + ";" + $san + ";" + $cert.thumbprint + ";" + $cert.Issuer + ";" + $template + ";" + $cert.NotAfter + ";" + $nodaystoexpire
        $inv += $entry
        }
    # Display progress bar and increment before end of computers loop
    Write-Progress -Id $Id -Activity $Activity -Status ($StatusBlock) -CurrentOperation $Task -PercentComplete (($Step / $Total) * 100)
    $Step ++
    }
# Write final output
$inv | Set-Content "C:\Temp\cert-report-out.csv"

