# BIDSify
Transform DICOM data to BIDS-Standard with minimal user interaction

## Usage

It is necessary to download dcm2niix ([dcm2niix releases](https://github.com/rordenlab/dcm2niix/releases)) and put it alongside the here provided bash script in a folder recognized by your shell.

Calling the script without any flag enlists the options
`$ BIDSify.sh`

* -p path to .dcm data
* -s session number
* -o output path
  
The given output path will be scanned and missing or consecutive sessions will be added. If no output path was specified, the BIDS-structure will be created in /datasets within your input folder.

An example command transforming the dicom data of all subjects in /Users/JohnDoe/Work/dcm_data to BIDS-Standard in a folder called /Users/JohnDoe/Work/BIDS_project would be:

`BIDSify.sh -p /Users/JohnDoe/Work/dcm_data -s 1 -o /Users/JohnDoe/Work/BIDS_project`

Note that not permitted characters will be deleted:
``` 
$ ls /Users/JohnDoe/Work/dcm_data
$ s1_001 s1_002 s1_003
$ ls /Users/JohnDoe/Work/BIDS_project
$ sub-s1001 sub-s1002 sub-s1003
``` 

The interaction with the user was kept to a minimum, which results in compromisses in recognzing the sequences used and naming them in the corresponding .json side cars. Substrings recognized for processing so far are (upper case as well as lower case):

* T1
* T2
* fMRI
* EPI
* BOLD
* dMRI
* DTI
* DWI
* spin (for spin echo fieldmaps)

Certain substrings marking sequences that don't need to be processed are the following:

* localizer
* scout
* setter
* distortion

Therefore, all seqences, except Resting State, will be named according their DICOM folder name. Futur updates will improve this concept.
BIDSify will promt the given options and provide a summary on Spin-Echo Fieldmaps measured in AP/PA were found in the correct configuration and SBref sequences if there are any. Further it lists the sequences, not recognized by the script. Futur updates will treat them as well.

## Approach and acknowlegdements
    
Dear community, I hope this little script is in some way helpful. Still it is in a piloting period and I encourage everyone to report bugs you find along your way of using it. I will keep it updated.

This work was created at Charité - Universitätsmedizin Berlin, Institut für Medizinische Psychologie.
