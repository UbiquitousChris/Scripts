#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jun 21 2019
# Purpose:
#
#
# Change Log:
# Jun 21 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="0.0.0"

postURL="https://qualityprograms.apple.com/snlookup/062019"

#-------------------
# Functions
#-------------------

usage()
{
    echo "Usage: ${SCRIPT_NAME} [OPTIONS...] [ARGUMENTS]"
    echo ""
    echo "Short description of what this script does"
    echo ""
    echo "Options:"
    echo " -h, -?, --help     Display this help and exit"
    echo "         --version  Display version information and exit"
    echo ""
}

version()
{
    echo "${SCRIPT_VERSION}"
}

#-------------------
# Parse Arguments
#-------------------
while [ "$#" -gt "0" ]; do
    case "$1" in
        --help | -h | -\?)
            usage
            shift
            exit 0
            ;;
        --version)
            version
            shift
            exit 0
            ;;
        --input)
            shift
            INPUT_FILE="$1"
            shift
            ;;
        --output)
            shift
            OUTPUT_FILE="$1"
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit -1
            ;;
        *)
            break
            ;;
    esac
done

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

if [[ -z "$INPUT_FILE" ]]; then
    echo "ERROR: Input file must be specified with --input"
    exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    echo "ERROR: Output file must be specified with --output"
    exit 1
fi

if [[ -f "$OUTPUT_FILE" ]]; then
    rm "$OUTPUT_FILE"
fi

while IFS= read -r RECORD; do
    SERIAL_NO="$(echo "$RECORD" | awk -F, '{print $3}')"
    quotGUID="$(uuidgen)"

    if [[ "$SERIAL_NO" == "Serial Number" ]]; then
        echo "$RECORD,Eligiblity" >> "$OUTPUT_FILE"
        continue
    fi



    # 12 charlen for all serials in affected years (14 incl quote)
    # 36 charlen for all guids (38 incl quote)


    postData="{\"serial\":$SERIAL_NO,\"GUID\":$quotGUID}"
    resp=$(curl -s -d "$postData" -H "Content-Type: application/json" -X POST "$postURL")
    if [[ "$resp" == *'"status":"E00"'* ]]; then
       RESULT="E00-Eligible"
    elif [[ "$resp" == *'"status":"E01"'* ]]; then
       RESULT="E01-Ineligible"
    elif [[ "$resp" == *'"status":"E99"'* ]]; then
       RESULT="E99-ProcessingError"
    elif [[ "$resp" == *'"status":"FE01"'* ]]; then
       RESULT="FE01-EmptySerial"
    elif [[ "$resp" == *'"status":"FE02"'* ]]; then
       RESULT="FE02-InvalidSerial"
    elif [[ "$resp" == *'"status":"FE03"'* ]]; then
       RESULT="FE03-ProcessingError"
    else
       RESULT="Err1-UnexpectedResponse"
    fi

    echo "$RECORD, $RESULT" >> "$OUTPUT_FILE"

done < "$INPUT_FILE"

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
