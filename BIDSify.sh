#!/bin/sh

#  BIDSify.sh
#  
#
# Created by Martin Bauer on 11.02.20.
# Institut für Medizinische Psychologie
# Charité - Universitätsmedizin Berlin

# Version History:
# 0.1 - script transforms specific K2H PRISMA scanner Output. Works only within the same directory and puts the output within dataset/ in that directory
# 0.2 - vNav Sequences are now used, script is adapted to handle setter sequences
# 0.3 - fixed a problem with various underscores in the file names
# 0.4 - script can now be called from /bin and does not need to be in the specific folder
# 0.5 - MAJOR UPDATE
# - short flags working now, setting path, output and sessionID
# - redirect to output path as now it is a possible option
# - check when json file for description is needed then
# - Check if dataset was already done
# - get the output in the right folder when there is ses-2 and ongoing
# - internal check wether data is stored in a timewise order, otherwise a warning appears
# - if last char of given path not / put a /
# - get interaction if session ID is wrong or not provided
# 0.6 - SBref and AP/PA get checked and warnings are displayed if there is a mismatch. SBref get recognized during processing.
# 0.7 - dicoms will be transformed and related to the BIDS structure according their namings and json side cars will be manipulated

echo "Welcome to your BIDS-Structure helper"

######### usage info if no flags given #########

if [ $# -eq 0 ]
then
echo "BIDSify usage: \n -p <path to .dcm data> \n -s <session number> \n -o <output path>; output path will be checked and missing or consecutive sessions will be added. \n If no output path is specified, the BIDS-structure will be created in /datasets within your input folder"
else

###############################################
echo "--------------- overview ----------------"
######### getting data from flags ##############

out_flag=0
ses_flag=0

declare -a seqLib # should moved out of all for loops
seqLib[0]=t1
seqLib[1]=t2
seqLib[2]=fmri
seqLib[3]=rest
seqLib[4]=dwi
seqLib[5]=dti
seqLib[6]=dmri
seqLib[7]=spin
seqLib[8]=localizer
seqLib[9]=scout
seqLib[10]=sbref
seqLib[11]=setter
seqLib[12]=distortion
seqLib[13]=epi
seqLib[14]=bold

while getopts ":p:s:o:" opt; do
case $opt in
p)
echo "-path was triggered, Parameter: $OPTARG" >&2
path_data=$OPTARG
;;
s)
echo "-ses was triggered, Parameter: $OPTARG" >&2
sessionID=$OPTARG
ses_flag=1
;;
o)
echo "-out was triggered, Parameter: $OPTARG" >&2
outpath=$OPTARG
out_flag=1
;;
\?)
echo "Invalid option: -$OPTARG" >&2
exit 1
;;
:)
echo "Option -$OPTARG requires an argument." >&2
exit 1
;;
esac
done

########################################################


######## configure according to the flags and check previously data ######

# ensure "/" at the end of paths
lCharPath=${path_data: -1}
if [ $lCharPath != / ]; then path_data=$path_data/; fi

# if no output specified, put data into input path and create a dataset folder
if [[ out_flag -lt 1 ]]; then
    outpath=$path_data
    echo "no output was given - creating parent directory in "$outpath"datasets"
    mkdir $outpath"datasets"
    outpath=$outpath"datasets/"
else

    lCharOutpath=${outpath: -1}
    if [ $lCharOutpath != / ]; then outpath=$outpath/; fi
fi

# get path length
path_len=${#path_data}
path_lenOut=${#outpath}

# if no session provided, get interaction
if [[ ses_flag -lt 1 ]]; then
    echo "session was not provided - please enter scan session"
    read sessionID
fi

# if no number was given, get interaction
re='^[0-9]+$'
if ! [[ $sessionID =~ $re ]]; then
    echo "error: Not a number - please enter scan session"
    read sessionID
fi

# create array listing all previousley processed data sets in given output
declare -a proc_sub
counter_procSub=0
for i in $outpath*; do proc_sub[$counter_procSub]=${i:$path_lenOut:110}; counter_procSub=$((counter_procSub + 1)); done


# create dataset_description if not already there
if [ ! -f $outpath"dataset_description.json" ]; then
    touch $outpath"dataset_description.json"
    echo "{\n\"Name\": \"Kids2Health\",\n\"BIDSVersion\": \"1.0.1\",\n\"License\": \"CC0\",\n\"Authors\": [\"Martin Bauer\"]\n}" >> $outpath"dataset_description.json"
fi



# that needs to be corrected ... later -.-
cd $path_data

# getting rid of the underscore if there is one (can be moved into next loop!!!!!)
for f in * ; do mv "$f" `echo "$f" | sed 's/_//g'` ; done

##################################################################################

################################ start processing ################################

for d in */ ; do # Loop over Subjects
    subjects[$counter]=${d%?};
    runIDRS=1;
    runIDDTIAP=1;
    runIDDTIPA=1;
    runIDT1w=1;
    runIDT2w=1;
    runIDFear=1;
    runIDFood=1;
    runIDfmapAP=1;
    runIDfmapPA=1;

    foundPrevData_flag=0;
    corr_sbref_FLAG=0;
    noFieldMapFlag=0
    nofMRISBref=0
    nodMRISBref=0

# skip dataset, if already found processed in the output path and set flag to one if prev processed data found in general

    for i in "${!proc_sub[@]}"; do
        if [[ "${proc_sub[$i]}" =~ "${subjects[$counter]}" ]]; then
            for ii in $outpath"sub-"${subjects[$counter]}/*; do
                if [[ ${ii: -1} == $sessionID ]]; then #$sessionID
                    foundPrevData_flag=1
                fi
            done
        fi
    done

    if [[ $foundPrevData_flag -eq 1 ]]; then
        echo $d " was already found processed in given output path\n data set is skipped"
        continue
    fi

    echo $d # ID/ saved
    if [ $d == "datasets/" ]
    then
        echo "skip parent directory"
    else
        mkdir -p $outpath"sub-"${subjects[$counter]}
        mkdir $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID
        mkdir $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID/anat
        mkdir $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID/func
        mkdir $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID/dwi
        mkdir $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID/fmap
    fi

###### check alphanumeric storage ##################################################################
    dlen=${#d}
    declare -a checkNumOrder
    indNum=0
    for seq in $d*/ ; do
        ind=$dlen
        num=""
        while [[ ${seq:ind:1} =~ $re ]]; do num+=${seq:ind:1}; let ind=ind+1; done
        checkNumOrder[$indNum]=$(echo $num | sed 's/^0*//')
        let indNum=indNum+1
    done

    if [ ! -z "$checkNumOrder" ]
    then
        lenArray=${#checkNumOrder[@]}
        ind=0
        test=1
        while [[ checkNumOrder[$ind] -eq $test ]]; do let ind=ind+1; let test=test+1; done
        if [[ $ind -lt $lenArray ]]
        then
        echo "WARNING! Timestamp was not found in all sequence folders - spin echo might not be related to correct EPI"
        fi
    else
        echo "WARNING! No timestamp was found in sequence folders - spin echo might not be related to correct EPI. Ensure propper order to be processed"
    fi
    unset checkNumOrder
######################################################################################################

######################### check datasets sequences used and match them to struc/func/dwi/unknown/ ####
    declare -a seqUse
    seqUseInd=0
    declare -a t1seq
    t1seqInd=0
    declare -a t2seq
    t2seqInd=0
    declare -a fMRIseq
    fMRIseqInd=0
    declare -a dMRIseq
    dMRIseqInd=0
    declare -a SEFMseq
    SEFMseqInd=0
    declare -a MISCseq
    MISCseqInd=0
    declare -a unknown
    declare -a allSeq
    declare -a seqIndFunc
    indseqfunc=0
    declare -a seqIndFM
    indseqFM=0

    FM=0

    for seq in $d*/ ; do
        allSeq[$seqUseInd]="${seq:$dlen:110}"
        seqUse[$seqUseInd]=$(echo "$seq" | tr '[:upper:]' '[:lower:]') # converting it to lower case
        seqUse[$seqUseInd]="${seqUse[$seqUseInd]:$dlen:110}"
        # avoid double naming...and skipping setter of vNav
        if [[ "${seqUse[$seqUseInd]}" =~ "t1" ]] && [[ "${seqUse[$seqUseInd]}" =~ "setter" ]]; then
            seqUse[$seqUseInd]=$(echo "${seqUse[$seqUseInd]}" | sed 's/t1//g')
        fi
        if [[ "${seqUse[$seqUseInd]}" =~ "t2" ]] && [[ "${seqUse[$seqUseInd]}" =~ "setter" ]]; then
            seqUse[$seqUseInd]=$(echo "${seqUse[$seqUseInd]}" | sed 's/t2//g')
        fi
        if [[ "${seqUse[$seqUseInd]}" =~ "epi" ]] && [[ "${seqUse[$seqUseInd]}" =~ "fmri" ]]; then
            seqUse[$seqUseInd]=$(echo "${seqUse[$seqUseInd]}" | sed 's/epi//g')
        fi
        if [[ "${seqUse[$seqUseInd]}" =~ "epi" ]] && [[ "${seqUse[$seqUseInd]}" =~ "spin" ]]; then
            seqUse[$seqUseInd]=$(echo "${seqUse[$seqUseInd]}" | sed 's/epi//g')
        fi
        if [[ "${seqUse[$seqUseInd]}" =~ "epi" ]] && [[ "${seqUse[$seqUseInd]}" =~ "bold" ]]; then
            seqUse[$seqUseInd]=$(echo "${seqUse[$seqUseInd]}" | sed 's/epi//g')
        fi
        if [[ "${seqUse[$seqUseInd]}" =~ "fmri" ]] && [[ "${seqUse[$seqUseInd]}" =~ "bold" ]]; then
            seqUse[$seqUseInd]=$(echo "${seqUse[$seqUseInd]}" | sed 's/bold//g')
        fi
        for r in "${seqLib[@]}"; do
            if [[ "${seqUse[$seqUseInd]}" =~ "${r}" ]]; then
                seqMatch=$r
                case "$seqMatch" in
                t1) t1seq[$t1seqInd]="${seq:$dlen:110}" # has still / tailed
                    let t1seqInd=t1seqInd+1
                    ;;
                t2) t2seq[$t2seqInd]="${seq:$dlen:110}" # has still / tailed
                    let t2seqInd=t2seqInd+1
                    ;;
                fmri) fMRIseq[$fMRIseqInd]="${seq:$dlen:110}" # has still / tailed
                      seqIndFunc[$indseqfunc]=$seqUseInd
                      usedFM[indseqfunc]=$FM
                      let indseqfunc=indseqfunc+1
                      let fMRIseqInd=fMRIseqInd+1
                      ;;
                epi) fMRIseq[$fMRIseqInd]="${seq:$dlen:110}" # has still / tailed
                    seqIndFunc[$indseqfunc]=$seqUseInd
                    usedFM[indseqfunc]=$FM
                    let indseqfunc=indseqfunc+1
                    let fMRIseqInd=fMRIseqInd+1
                    ;;
                bold) fMRIseq[$fMRIseqInd]="${seq:$dlen:110}" # has still / tailed
                    seqIndFunc[$indseqfunc]=$seqUseInd
                    usedFM[indseqfunc]=$FM
                    let indseqfunc=indseqfunc+1
                    let fMRIseqInd=fMRIseqInd+1
                    ;;
                dmri) dMRIseq[$dMRIseqInd]="${seq:$dlen:110}" # has still / tailed
                      let dMRIseqInd=dMRIseqInd+1
                      ;;
                dti) dMRIseq[$dMRIseqInd]="${seq:$dlen:110}" # has still / tailed
                     let dMRIseqInd=dMRIseqInd+1
                     ;;
                dwi) dMRIseq[$dMRIseqInd]="${seq:$dlen:110}" # has still / tailed
                     let dMRIseqInd=dMRIseqInd+1
                     ;;
                spin) SEFMseq[$SEFMseqInd]="${seq:$dlen:110}" # has still / tailed
                      seqIndFM[$indseqFM]=$seqUseInd
                      let FM=FM+1
                      let indseqFM=indseqFM+1
                      let SEFMseqInd=SEFMseqInd+1
                      ;;
                localizer) MISCseq[$MISCseqInd]="${seq:$dlen:110}" # has still / tailed
                    let MISCseqInd=MISCseqInd+1
                    ;;
                scout) MISCseq[$MISCseqInd]="${seq:$dlen:110}" # has still / tailed
                    let MISCseqInd=MISCseqInd+1
                    ;;
                setter) MISCseq[$MISCseqInd]="${seq:$dlen:110}" # has still / tailed
                    let MISCseqInd=MISCseqInd+1
                    ;;
                distortion) MISCseq[$MISCseqInd]="${seq:$dlen:110}" # has still / tailed
                    let MISCseqInd=MISCseqInd+1
                    ;;
esac # do no case fullfilled *) and save not recognised
            fi
        done
        let seqUseInd=seqUseInd+1
    done

    t1seq=($(echo "${t1seq[@]}" | tr ' ' '\n' | uniq | tr '\n' ' '))
    t2seq=($(echo "${t2seq[@]}" | tr ' ' '\n' | uniq | tr '\n' ' '))
    fMRIseq=($(echo "${fMRIseq[@]}" | tr ' ' '\n' | uniq | tr '\n' ' '))
    dMRIseq=($(echo "${dMRIseq[@]}" | tr ' ' '\n' | uniq | tr '\n' ' '))
    SEFMseq=($(echo "${SEFMseq[@]}" | tr ' ' '\n' | uniq | tr '\n' ' '))
    MISCseq=($(echo "${MISCseq[@]}" | tr ' ' '\n' | uniq | tr '\n' ' '))

    seqRecog=( ${t1seq[*]} ${t2seq[*]} ${fMRIseq[*]} ${dMRIseq[*]} ${SEFMseq[*]} ${MISCseq[*]} )
    allSeqNo=${#seqUse[@]}
    seqRecogNo=${#seqRecog[@]}
    notRecog=$(( allSeqNo-seqRecogNo ))

    unknown=$(echo ${seqRecog[@]} ${allSeq[@]} | tr ' ' '\n' | sort | uniq -u)

    if [[ $notRecog -eq 0 ]]; then
        echo "All sequences were recognized"
    else
        echo $notRecog " sequences were not recognized"
        for r in "${!unknown[@]}"; do
            echo "${unknown[$r]}"
            # interaction to get lost sequences into T1/T2, fMRI, DTI, MISC
        done
    fi
    if  [ -z "$t1seq" ]; then
        echo "no T1w data was found"
    fi

    if  [ -z "$t2seq" ]; then
        echo "no T2w data was found"
    fi

    if [ -z "$fMRIseq" ]; then
        echo "no fMRI data was found"
    fi

    if [ -z "$dMRIseq" ]; then
        echo "no dMRI data was found"
    fi

    if [ -z "$SEFMseq" ]; then
        echo "no spin-echo fieldmap was found"
        noFieldMapFlag=1
    fi

    #### check sbref fMRI/DTI ####

    declare -a fMRIseqClean
    declare -a fMRIseqSbref
    fMRIseqInd=0
    fMRISBrefInd=0
    gind=0
    for r in "${fMRIseq[@]}"; do
        if [[ $(find $d$r -type f | wc -l) -gt 1 ]]; then
            fMRIseqClean[$fMRIseqInd]=$r
            let fMRIseqInd=fMRIseqInd+1
        else
            fMRIseqSbref[$fMRISBrefInd]=$r
            unset -v 'seqIndFunc[$gind]'
            unset -v 'usedFM[$gind]'
            let fMRISBrefInd=fMRISBrefInd+1
        fi
        let gind=gind+1
    done

    declare -a usedFMclean
    indclean=0
    for r in "${usedFM[@]}"; do
        if [ ! -z $r ] && [[ r -gt 0 ]]; then
            usedFMclean[$indclean]=$r
            let indclean=indclean+1
        fi
    done

    declare -a seqIndFuncclean
    indclean=0
    for r in "${seqIndFunc[@]}"; do
        if [ ! -z $r ]; then
            seqIndFuncclean[$indclean]=$r
            let indclean=indclean+1
        fi
    done

    if [ -z "$fMRIseqSbref" ]; then
        echo "no fMRI SBref data was found"
        nofMRISBref=1
    fi

# check SBref has same noe as EPI
if [ ! -z "$fMRIseq" ]; then
        if [[ $nofMRISBref -eq 0 ]] && [[ ${#fMRIseqClean[@]} -eq ${#fMRIseqSbref[@]} ]]; then
            echo "SBref config found for every EPI sequence"
        else
            echo "WARNING! Not all EPI sequences have SBref - check if not intended"
            # find SBrefs
        fi
    fi
    declare -a dMRIseqClean
    declare -a dMRIseqSbref
    dMRIseqInd=0
    dMRISBrefInd=0
    for r in "${dMRIseq[@]}"; do
        if [[ $(find $d$r -type f | wc -l) -gt 1 ]]; then
            dMRIseqClean[$dMRIseqInd]=$r
            let dMRIseqInd=dMRIseqInd+1
        else
            dMRIseqSbref[$dMRISBrefInd]=$r
            let dMRISBrefInd=dMRISBrefInd+1
        fi
    done

    if [ -z "$dMRIseqSbref" ]; then
        echo "no dMRI SBref data was found"
        nodMRISBref=1
    fi

# check SBref has same noe as EPI
if [ ! -z "$dMRIseq" ]; then
        if [[ $nodMRISBref -eq 0 ]] && [[ ${#dMRIseqClean[@]} -eq ${#dMRIseqSbref[@]} ]]; then
            echo "SBref config found for every DWI sequence"
        else
            echo "WARNING! Not all DWI sequences have SBref - check if not intended"
            # find SBrefs
        fi
    fi
#### check AP/PA correct ####

    APcount=0
    PAcount=0
    gind=0
    for r in "${SEFMseq[@]}"; do
        if [[ $r == *AP* ]]; then
            unset -v 'seqIndFM[$gind]'
            let APcount=APcount+1
        elif [[ $r == *PA* ]]; then
            let PAcount=PAcount+1
        fi
        let gind=gind+1
    done

    declare -a seqIndFMclean
    indclean=0
    for r in "${seqIndFM[@]}"; do
        if [ ! -z $r ]; then
            seqIndFMclean[$indclean]=$r
            let indclean=indclean+1
        fi
    done

    if [[ $APcount -eq $PAcount ]] && [[ $APcount -gt 0 ]] && [[ $noFieldMapFlag -lt 1 ]]; then
        echo "correct AP/PA fieldmap configuration found"
    else
        echo "WARNING! Wrong AP/PA fieldmap configuration found, consider a check of your spin-echo sequences"
    fi


    seqTransStruc=( ${t1seq[*]} ${t2seq[*]} )

echo "--------------- end of overview ----------------"
######################################################################################################


    echo "---------------- converting anatomical scans ----------------"
    for c in "${seqTransStruc[@]}"; do
        if [[ $c == *"T1w"* ]] && [[ $c != *"setter"* ]]; then # anat
            dcm2niix -v n -b y -z y y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/anat/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_run-"$runIDT1w"_T1w" $d$c
            let runIDT1w=runIDT1w+1
        elif [[ $c == *"T2w"* ]] && [[ $c != *"setter"* ]]; then # anat
            dcm2niix -v n -b y -z y y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/anat/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_run-"$runIDT2w"_T2w" $d$c
            let runIDT2w=runIDT2w+1
        # else for other like high res sequences
        fi
    done

    if [ ! -z "$dMRIseqClean" ]; then
        echo "---------------- converting dwi scans ----------------------"
        for c in "${dMRIseqClean[@]}"; do
            if [[ $c == *"AP"* ]]; then
                dcm2niix -v n -b y -z y y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/dwi/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_acq-AP_run-"$runIDDTIAP"_dwi"  $d$c
                let runIDDTIAP=runIDDTIAP+1
            elif [[ $c == *"PA"* ]]; then
                dcm2niix -v n -b y -z y y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/dwi/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_acq-PA_run-"$runIDDTIPA"_dwi" $d$c
                let runIDDTIPA=runIDDTIPA+1
            fi
        done
    fi
    if [ ! -z "$fMRIseqClean" ]; then
        echo "---------------- converting functional scans ---------------------"
        declare -a cleanEPIseqName
        indcleanEPIseqName=0
        declare -a taskTagArr
        indtaskTagArr=0
        for c in "${fMRIseqClean[@]}"; do
            clow=$(echo "$c" | tr '[:upper:]' '[:lower:]')
            if [[ $clow == *"rest"* ]]; then
                taskTag="RestingState"
            else
                taskTag=$(printf '%s' "$c" | tr -d '0123456789_/%')
            fi
            taskTagArr[$indtaskTagArr]=$taskTag
            runIDRS=$(grep -o $taskTag <<< ${taskTagArr[*]} | wc -l)
            runlen=${#runIDRS}
            let runlen=runlen-1
            runIDRS=${runIDRS:$runlen:1}
            let indtaskTagArr=indtaskTagArr+1
            cleanEPIseqName[$indcleanEPIseqName]="ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_bold"
            dcm2niix -v n -b y -z y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_bold" $d$c
            sed -i '' -e '$ d' $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_bold.json"
            lastline=$(tail -n 1 $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_bold.json")
            sed -i '' -e '$ d' $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_bold.json"
            echo $lastline"," >> $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_bold.json"
            echo "\"TaskName\": \"$taskTag\"\n}" >> $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_bold.json"
            let indcleanEPIseqName=indcleanEPIseqName+1
        done
    fi

    usedFMreal=$((indFM + 1))
    uniqFMused=($(echo "${usedFMclean[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    ########
    declare -a indUsedFM
    indUsedFMx=0
    for r in "${uniqFMused[@]}"; do
        indUsedFM[$indUsedFMx]=$(( $r/2 ))
        if [[ "${indUsedFM[$indUsedFMx]}" -gt 0 ]];then
            indUsedFM[$indUsedFMx]=$(( ${indUsedFM[$indUsedFMx]}-1 ))
        fi
        let indUsedFMx=indUsedFMx+1
    done
    declare -a usedFMfinal
    usedFMfinalx=0
    for r in "${indUsedFM[@]}"; do
        usedFMfinal[usedFMfinalx]=${seqIndFMclean[$r]}
        let usedFMfinalx=usedFMfinalx+1
    done
    declare -a indexpand
    idx=0
    for c in "${indUsedFM[@]}"; do
        indexpand[$idx]=$(( $c*2 ))
        let idx=idx+1
        indexpand[$idx]=$(( $c*2+1 ))
        let idx=idx+1
    done

    #########usedfinal anstatt seqIndFMclean

    inde=0
    checkval=${usedFMclean[$inde]}
    declare -a jsonin
    indFM=0
    usedFMfinallen=${#usedFMfinal[*]}
    declare -a usedFMcleanCheck
    uniqFMusedlen=${#uniqFMused[*]}
    uniqFMusedlenCheck=$(( uniqFMusedlen-1 ))

    for c in "${cleanEPIseqName[@]}"; do

        if [[ $checkval -eq ${usedFMclean[$inde]} ]] || [[ $indFM -ge $uniqFMusedlenCheck ]]; then
            jsonin[$indFM]+=$c
            jsonin[$indFM]+="\",\""
        else
            let indFM=indFM+1
            checkval=usedFMclean[$inde]
            jsonin[$indFM]+=$c
            jsonin[$indFM]+="\",\""
        fi
        actdist=$((seqIndFuncclean[$inde] - usedFMfinal[$indFM]))
        actdist=`echo ${actdist/#-/}`
        indcheck=$((indFM + 1))
        if [[ $usedFMfinallen -le $indcheck ]]; then
            indcheck=$indFM
        fi
        actcheck=$((seqIndFuncclean[$inde] - usedFMfinal[$indcheck]))
        actcheck=`echo ${actcheck/#-/}`
        if [[ $actcheck -lt $actdist ]]; then
            usedFMcleanCheck[$inde]="${uniqFMused[$indcheck]}"
        else
            usedFMcleanCheck[$inde]="${usedFMclean[$inde]}"
        fi
        let inde=inde+1
    done


    for c in "${!jsonin[@]}"; do
        betw=${jsonin[$c]}
        betw=${betw%???}
        jsonin[$c]=$betw
    done

    inde=0
    index=0
    idx=0
    if [ ! -z "$SEFMseq" ]; then
        echo "---------------- converting FieldMaps -----------------------"
        for c in "${SEFMseq[@]}"; do
            if [[ $inde -eq ${indexpand[$idx]} ]]; then
                if [[ $c == *"AP"* ]]; then
                    dcm2niix -v n -b y -z y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-AP_run-"$runIDfmapAP"_epi" $d$c
                    sed -i '' -e '$ d' $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-AP_run-"$runIDfmapAP"_epi.json"
                    lastline=$(tail -n 1 $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-AP_run-"$runIDfmapAP"_epi.json")
                    sed -i '' -e '$ d' $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-AP_run-"$runIDfmapAP"_epi.json"
                    echo $lastline","$'\n'"\"IntendedFor\": [\""${jsonin[$index]}"\"]"$'\n'"}" >> $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-AP_run-"$runIDfmapAP"_epi.json"
                    runIDfmapAP=$((runIDfmapAP + 1))
                    let idx=idx+1
                elif [[ $c == *"PA"* ]]; then
                    dcm2niix -v n -b y -z y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-PA_run-"$runIDfmapPA"_epi" $d$c
                    sed -i '' -e '$ d' $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-PA_run-"$runIDfmapPA"_epi.json"
                    lastline=$(tail -n 1 $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-PA_run-"$runIDfmapPA"_epi.json")
                    sed -i '' -e '$ d' $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-PA_run-"$runIDfmapPA"_epi.json"
                    echo $lastline","$'\n'"\"IntendedFor\": [\""${jsonin[$index]}"\"]"$'\n'"}" >> $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/fmap/sub-"${subjects[$counter]}"_ses-"$sessionID"_dir-PA_run-"$runIDfmapPA"_epi.json"
                    runIDfmapPA=$((runIDfmapPA + 1))
                    let idx=idx+1
                    let index=index+1
                fi
            fi
            let inde=inde+1
        done
    fi

##### SBref conversion ######

    if [[ $nofMRISBref -eq 0 ]]; then
        echo "---------------- converting functional SBref scans ---------------------"
        #declare -a cleanEPIseqName
        #indcleanEPIseqName=0
        declare -a taskTagArrSBref
        indtaskTagArrSBref=0
        for c in "${fMRIseqSbref[@]}"; do
            clow=$(echo "$c" | tr '[:upper:]' '[:lower:]')
            if [[ $clow == *"rest"* ]]; then
                taskTag="RestingState"
            else
                taskTag=$(printf '%s' "$c" | tr -d '0123456789_/%')
            fi
            taskTagArrSBref[$indtaskTagArrSBref]=$taskTag
            runIDRS=$( grep -o $taskTag <<< ${taskTagArrSBref[*]} | wc -l )
            runlen=${#runIDRS}
            let runlen=runlen-1
            runIDRS=${runIDRS:$runlen:1}
            let indtaskTagArrSBref=indtaskTagArrSBref+1
#cleanEPIseqName[$indcleanEPIseqName]="ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_sbref"
            dcm2niix -v n -b y -z y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_sbref" $d$c
            sed -i '' -e '$ d' $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_sbref.json"
            lastline=$(tail -n 1 $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_sbref.json")
            sed -i '' -e '$ d' $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_sbref.json"
            echo $lastline"," >> $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_sbref.json"
            echo "\"TaskName\": \"$taskTag\"\n}" >> $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/func/sub-"${subjects[$counter]}"_ses-"$sessionID"_task-"$taskTag"_run-"$runIDRS"_sbref.json"
            #let indcleanEPIseqName=indcleanEPIseqName+1
        done
    fi

    if [[ $nodMRISBref -eq 0 ]]; then
        runIDDTIAP=1
        runIDDTIPA=1
        echo "---------------- converting dwi SBref scans ----------------------"
        for c in "${dMRIseqSbref[@]}"; do
            if [[ $c == *"AP"* ]]; then
                dcm2niix -v n -b y -z y y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/dwi/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_acq-AP_run-"$runIDDTIAP"_sbref"  $d$c
                let runIDDTIAP=runIDDTIAP+1
            elif [[ $c == *"PA"* ]]; then
                dcm2niix -v n -b y -z y y -o $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID"/dwi/" -f "sub-"${subjects[$counter]}"_ses-"$sessionID"_acq-PA_run-"$runIDDTIPA"_sbref" $d$c
                let runIDDTIPA=runIDDTIPA+1
            fi
        done
    fi


######################################################################################################

    if [[ $d != "datasets/" ]]
    then
#echo "--- cleaning up ---"

#rm -r $outpath"sub-"${subjects[$counter]}"/ses-"$sessionID/fMap_info
        let counter=counter+1;
    fi

    # move longitudinal data to the previous sessions in the BIDS structure, if existing
#if [ $sessionID -gt 1 ] && [ $foundPrevData_flag -eq 1 ]
#   then
        # mv $outpath${subjects[$counter]}/*
#   fi

unset seqUse
unset t1seq
unset t2seq
unset fMRIseq
unset dMRIseq
unset SEFMseq
unset MISCseq
unset seqIndFunc
unset seqIndFM
unset fMRIseqClean
unset fMRIseqSbref
unset usedFMclean
unset seqIndFuncclean
unset dMRIseqClean
unset dMRIseqSbref
unset usedFMfinal
unset cleanEPIseqName
unset taskTagArr
unset jsonin
unset usedFMcleanCheck
unset taskTagArrSBref
unset indUsedFM
unset unknown
unset allSeq
done # loop over subjects

fi # closing usage message!
