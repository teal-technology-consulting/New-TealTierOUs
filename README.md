
- [1. New-TealTierOU](#1-new-tealtierou)
  - [1.1. Script Parameters](#11-script-parameters)
- [2. Create Tiering OUs](#2-create-tiering-ous)
  - [2.1. Create All level of tiers](#21-create-all-level-of-tiers)
  - [2.2. Create Tier0 level](#22-create-tier0-level)
  - [2.3. Create Tier1 level](#23-create-tier1-level)
  - [2.4. Create Tier0 level](#24-create-tier0-level)
- [3. Create or change the xml structure](#3-create-or-change-the-xml-structure)
  - [3.1. Structure of the xml files](#31-structure-of-the-xml-files)
  - [3.2. Define OU](#32-define-ou)
    - [3.2.1. Define OU level](#321-define-ou-level)
    - [3.2.2. Define OU](#322-define-ou)


# 1. New-TealTierOU
Powershell script **New-TealTierOUs.ps1** to create a OU structure which is defined in XML configuration files.
The script creates as of now the OUs which are documented in the XML files.
Further the script creates Groups which are defined for each OU seperatly. If a Group is defined inside a OU section, this group get created in this OU.

During the execution the scripts checks for every object which was created that this object is actual created on all Domain Controllers.
There for the script queries the Domain to get a list of all DCs and then queries each DC for the object.
This could lead in a long run time of the script if there are a lot of domain controller.

## 1.1. Script Parameters
**PARAMETER $Path**: $Path describes the path to the folder in which the xml files reside. Default value is ".\"

**PARAMETER $Tier**: $Tier tells the script, which tier to create. Valid values are "0","1","2","all","01","02" and "12". The script will create the specified tiers or all three of them.

**Verbose**: Defines that the script will run in verbose mode. This will show further output on the console.

# 2. Create Tiering OUs
## 2.1. Create All level of tiers
This requires that the following files are created and in the same folder as the script:
  - T0OU.xml
  - T1OU.xml
  - T2OU.xml

        .\New-TealTierOUs.ps1 -Tier All

## 2.2. Create Tier0 level
To create only the Tier 0 run the following command:
This will use the following file:
  - T0OU.xml


        .\New-TealTierOUs.ps1 -Tier 0

## 2.3. Create Tier1 level
To create only the Tier 1 run the following command:
To create only the Tier 0 run the following command:
This will use the following file:
  - T1OU.xml


        .\New-TealTierOUs.ps1 -Tier 1

## 2.4. Create Tier0 level
To create only the Tier 2 run the following command:
To create only the Tier 0 run the following command:
This will use the following file:
  - T2OU.xml


        .\New-TealTierOUs.ps1 -Tier 2

# 3. Create or change the xml structure
To create a new OU structur in the xml file do the following.
All xml files have the same structure inside.
 ## 3.1. Structure of the xml files
The XML need to have the following base structure:

```
<Tiering>

</Tiering>
```

All information about the OUs have to be inside of this elements.

## 3.2. Define OU
### 3.2.1. Define OU level
Each level of the OU have to be inside the following elements.
A level of the OU is for example the root OU, the further sub OU.
All OUs on the same level have to be in the same element:

```
<OUDefinition level="0" OUPath="">

</OUDefinition>
```

As you see in this example the level is 0 and the OUPath is empty.
This means that the OU or OUs which are defined here will be created on the root level directly under the domain.

For a OU which is created inside another OU the OUDefinition will look like the following:

```
<OUDefinition level="2" OUPath="OU=Tier 1,OU=Teal - ESAE">
    <OU>
        <OUName>Devices</OUName>
    </OU>
    <OU>
        <OUName>Groups</OUName>
    </OU>
    <OU>
        <OUName>ServiceUsers</OUName>
    </OU>
    <OU>
        <OUName>Users</OUName>
    </OU>
</OUDefinition>
```


### 3.2.2. Define OU
Each OU will be defined with the following structure:

```
<OU>
    <OUName>Tier 0</OUName>
</OU>
```

The structure of the OU have to be defined like the following

#### 3.2.2.1. OUName

Name of the OU which should be created. The OU will be created in the OUPath, which is defined in the OUDefiniton.


**n** is just an numbering element should start at 1 and be increased with every group documentend in this OU.
