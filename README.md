# CertificateInventoryWithTemplateNames
This script will gather a list of current Active Directory domain servers, go to each server and get the certificates
from the LocalMachine\My (Personal) certificate store. It will try to pull the names of the templates for certificates
issued from an enterprise CA, but for other types of certs a simple name substitution is done.

It needs to be run by as user with admin rights on all targetted servers. Just extract the script file 
Get-ActiveDirectoryDomainServerCertificateInventory.ps1 to a folder on your machine, then 
.\Get-ActiveDirectoryDomainServerCertificateInventory.ps1 to run it. Depending on your execution policy,
you may need to right click it and "Unblock", or Set-ExecutionPolicy <appropriate_value> to allow scripts to run.

The default output file is C:\temp\cert-report-out.csv. I used semicolons as the delimiter because the distinguished
names have commas. Here is a sample output.

Computer;IP;Subject;SAN;Thumbprint;Issuer Name;Template;Valid Until;Days to Expiration
server01;10.1.1.2;;server01.your.domain;E9xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx8D;CN=Issuing CA, DC=your, DC=domain;ConfigMgr Client Agent Certificate;11/01/2018 15:45:26;219
server02;10.2.2.2;CN=server02.your.domain;server02.your.domain;FFxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx42;CN=server02.your.domain;## Self Signed ##;09/21/2017 08:46:11;Expired
server03;10.1.1.10;CN=server03.lsi.local;server03.your.domain server03;52xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx2F;CN=Issuing CA, DC=your, DC=domain;WebServer;10/16/2019 15:39:30;568
server03;10.1.1.10;CN=server03.your.domain;server03.your.domain;89xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx60;CN=Issuing CA, DC=your, DC=domain;Machine;09/20/2018 16:42:48;177
