
param(
    [Parameter(Mandatory=$true)][string]   $iSCSIlist
); 

Class CiSCSIDict {
	[String] $ServerName;
	[String] $DriveName;
	[String] $ISCSiName;
	[String] $ISCSiTarget;

	CiSCSIDict([String] $_ServerName, [String] $_DriveName, [String] $_ISCSiName, [String] $_ISCSiTarget){
		$this.ServerName  = $_ServerName;
		$this.DriveName   = $_DriveName;
		$this.ISCSiName   = $_ISCSiName;
		$this.ISCSiTarget = $_ISCSiTarget;
	}
}

Class COutInfo {
	[String] $DfsnFolderPath;
	[String] $DfsnFolderDescription;
	[String] $DfsReplicatedFolderGroupName;
	[String] $DfsnFolderTargetTargetPath;
	[String] $SMBSharePSComputerName;
	[String] $SMBShareDescription;
	[String] $SMBSharePath;
	[String] $ISCSiHostName;
	[String] $ISCSiTarget;
	[String] $FSVolumeDescription;

	COutInfo([String] $_DfsnFolderPath, [String] $_DfsnFolderDescription, [String] $_DfsReplicatedFolderGroupName, [String] $_DfsnFolderTargetTargetPath, [String] $_SMBSharePSComputerName, [String] $_SMBShareDescription, [String] $_SMBSharePath, [String] $_FSVolumeDescription, [CiSCSIDict] $_iSQSIinfo){
		$this.DfsnFolderPath = $_DfsnFolderPath;
		$this.DfsnFolderDescription = $_DfsnFolderDescription;
		$this.DfsReplicatedFolderGroupName = $_DfsReplicatedFolderGroupName;
		$this.DfsnFolderTargetTargetPath = $_DfsnFolderTargetTargetPath;
		$this.SMBSharePSComputerName = $_SMBSharePSComputerName;
		$this.SMBShareDescription = $_SMBShareDescription;
		$this.SMBSharePath = $_SMBSharePath;
		$this.FSVolumeDescription = $_FSVolumeDescription;
		if($null -ne $_iSQSIinfo) {
			$this.ISCSiHostName = $_iSQSIinfo.ISCSiName;
			$this.ISCSiTarget = $_iSQSIinfo.ISCSiTarget;
		}
	}
}

[System.Collections.ArrayList]$iSCSIDict = New-Object System.Collections.ArrayList($null);
Import-Csv -Delimiter ';' -Encoding Default -Path $iSCSIlist |  %{
	$iSCSIDict.Add([CiSCSIDict]::new($_.computername, $_.DriveName, $_.iSCSI, $_.target)) | Out-Null;

}

<#
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K30-DC01', 'R', 'qnap-iscsi-2', 'iscsi.nas2.000000')) | Out-Null;
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K30-DC01', 'E', 'qnap-iscsi-3', 'iscsi.nas3.211c9d')) | Out-Null;
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K30-DC01', 'P', 'qnap-iscsi-5', 'iscsi.16tb01.3a391f')) | Out-Null;
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K30-DC01', 'Q', 'qnap-iscsi-5', 'iscsi.16tb01.3a391f')) | Out-Null;
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K30-DC01', 'S', 'qnap-iscsi-5', 'iscsi.tb16r1n1.3a391f')) | Out-Null;
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K30-DC02', 'P', 'qnap-iscsi-5', 'iscsi.16tb02.3a391f')) | Out-Null;
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K30-DC02', 'E', 'qnap-iscsi-1', 'ts-859uplus:iscsi.nas1.cb9d4c')) | Out-Null;
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K10-DC01', 'S', 'qnap-iscsi-4', 'iscsi.16tb01.3c8195')) | Out-Null;
$iSCSIDict.Add([CiSCSIDict]::new('V-BRN-K10-DC01', 'E', 'qnap-iscsi-4', 'iscsi.tb16r1n41.3c8195')) | Out-Null;
#> 

Get-DfsnRoot -ErrorAction SilentlyContinue |
    Where-Object -Property type -like 'Domain v2'|
    % {
        Get-DfsnFolder -Path "$($_.Path)\*" |
        Where-Object -Property state -eq Online |
        %{
            $curDfsnFolder = $_;
            $curDfsReplicatedFolder = Get-DfsReplicatedFolder | Where-Object -Property DfsnPath -like ('*\'+ (($curDfsnFolder.Path.split('\') | Select-Object -Skip 3) -join '\'));
            $curDfsnFolder | Get-DfsnFolderTarget | Where-Object -Property State -EQ Online |
            %{
                $curDfsnFolderTarget = $_;
                ($curSMBServer,$curSMBShare) = $curDfsnFolderTarget.TargetPath.split('\')[2..3];
                ($curSMBShare, $VolDescription) = Invoke-Command -ComputerName ($curSMBServer  -split '\.')[0] -ScriptBlock {param($ShareName) ; $SMBShare = get-smbshare -Name $ShareName; ($SMBShare,(Get-PSDrive -Name $SMBShare.Path.Substring(0,1)).Description) } -ArgumentList $curSMBShare ;
                [COutInfo]::new($curDfsnFolder.Path,
                                $curDfsnFolder.Description,
                                $curDfsReplicatedFolder.GroupName,
                                $curDfsnFolderTarget.TargetPath,
                                $curSMBShare.PSComputerName,
                                $curSMBShare.Description,
                                $curSMBShare.Path,
                                $VolDescription,
                                $iSCSIDict.Where({ $_.ServerName -like $curSMBShare.PSComputerName -and $_.DriveName -like $curSMBShare.Path.Substring(0,1)})[0]
                );
            }
        }
    }