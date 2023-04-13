#!/bin/bash

# Unofficial Bash Strict Mode (http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'
PROG="$(basename "$0")"


function set_defaults()
{
    PROJECT_ROOT="."
    MAX_WORDS_PROJECT_DESC=100
}


function error()
{
    if (( $# > 0 ));
    then
        echo "$PROG: error: $@"
    else
        echo
    fi
} >&2


function bail_out()
{
    error "$@"
    exit 1
}


function bail_out_usage()
{
    error "$@"
    error
    print_usage
    exit 1
}


function log()
{
    echo "-- $@"
} >&2


function print_usage()
{
    echo "USAGE:  $PROG [-h] [<directory>]"
} >&2


function print_help()
{
    print_usage
    echo
    echo 'Initialize a new assembly project establishing all mandatory meta data about'
    echo 'the project.'
    echo
    echo 'Positional arguments:'
    echo ' <directory>     Root directory of the project (default: .)'
    echo
    echo 'Optional arguments:'
    echo ' --help, -h      Prints this help.'
    echo ' --usage         Print a short command summary.'
    echo ' --version       Print software version.'
} >&2


function print_version()
{
    echo "$PROG v0"
    echo    
} >&2


function parse_args()
{
    ARGS=()
    for ARG in "$@";
    do
        if [[ "${ARG:0:1}" == - ]];
        then
            case "$ARG" in
                -h|--help)
                    print_help

                    exit
                    ;;
                --usage)
                    print_usage

                    exit
                    ;;
                --version)
                    print_version

                    exit
                    ;;
                *)
                    bail_out_usage "unkown option $ARG"
                    ;;
            esac
        else
            ARGS+=( "$ARG" )
        fi
    done

    (( ${#ARGS[*]} <= 1 )) || bail_out_usage "too many arguments"

    if (( ${#ARGS[*]} == 1 ));
    then
        PROJECT_ROOT="${ARGS[0]}"
    fi

    [[ -d "$PROJECT_ROOT" ]] || bail_out "<directory> must be a directory: $PROJECT_ROOT"
}


function prompt_for_meta_data()
{
    DEFAULT_PROJECT_ID="$(basename "$(realpath "$PROJECT_ROOT")")"
    read -ep "Project ID [$DEFAULT_PROJECT_ID]: " PROJECT_ID
    [[ -n "$PROJECT_ID" ]] || PROJECT_ID="$DEFAULT_PROJECT_ID"

    while true;
    do
        read -ep "Project Source (VREBP|ERGA|Other): " -i "${PROJECT_SOURCE:-}" PROJECT_SOURCE

        [[ "$PROJECT_SOURCE" =~ ^(VREBP|ERGA|Other)$ ]] && break

        echo "error: project source must be one of VREBP, ERGA, Other" >&2
    done

    read -ep "Species Full Scientific Name (e.g. Bos taurus): " SPECIES_FULL_SCIENTIFIC_NAME

    DEFAULT_SPECIES_ID="$(sed -E 's/[^a-zA-Z0-9]+/_/g; s/^_+|_+$//;' <<<"$SPECIES_FULL_SCIENTIFIC_NAME" | tr '[:upper:]' '[:lower:]')"
    while true;
    do
        read -ep "Species ID [$DEFAULT_SPECIES_ID]: " -i "${SPECIES_ID:-}" SPECIES_ID
        [[ -n "$SPECIES_ID" ]] || SPECIES_ID="$DEFAULT_SPECIES_ID"

        [[ "$SPECIES_ID" =~ ^[a-z_A-Z0-9]+$ ]] && break

        echo "error: species ID may contain only letters, digits and underscores" >&2
    done

    read -ep "Species Full Trivial Name (e.g. Cattle): " SPECIES_FULL_TRIVIAL_NAME

    while true;
    do
        read -ep "Project Description (up to $MAX_WORDS_PROJECT_DESC words): " -i "${PROJECT_DESCRIPTION:-}" PROJECT_DESCRIPTION

        if (( $(wc -w <<<"$PROJECT_DESCRIPTION") <= MAX_WORDS_PROJECT_DESC ));
        then
            break
        else
            echo "error: project description is too long (max. $MAX_WORDS_PROJECT_DESC words)"
        fi
    done

    while true;
    do
        read -ep "Estimated genome Size (e.g. 2200M): " -i "${GENOME_SIZE:-}" GENOME_SIZE

	[[ "$GENOME_SIZE" =~ ^[0-9]+|([kMGT])$ ]] && break

        echo "error: genome size must be an integer followed by" >&2
        echo "       a multiplier (k=10^3, M=10^6, G=10^9, T=10^12)" >&2
    done

    while true;
    do
        read -ep "NCBI Taxonomy ID (https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi): " -i "${NCBI_TAXONOMY_ID:-}" NCBI_TAXONOMY_ID

        [[ -z "$NCBI_TAXONOMY_ID" || "$NCBI_TAXONOMY_ID" =~ ^[0-9]+$ ]] && break

        echo "error: NCBI Taxonomy ID must be an integer" >&2
    done

    [[ -n "$NCBI_TAXONOMY_ID" ]] || unset NCBI_TAXONOMY_ID

    read -ep "Sanger ToLID (from https://id.tol.sanger.ac.uk/): " SANGER_TOLID
}


function print_variables()
{
    local QUOTE="'\\''"
    declare -A WAS_PRINTED=()

    for NAME in "$@";
    do
        [[ -v "$NAME" && -n "$NAME" && ! -v WAS_PRINTED[$NAME] ]] || continue

        local VALUE="${!NAME}"

        echo "$NAME='${VALUE//\'/$QUOTE}'"
    done
}


function main()
{
    set_defaults
    parse_args "$@"
    prompt_for_meta_data

    print_variables \
        PROJECT_ID \
        PROJECT_SOURCE \
        SPECIES_FULL_SCIENTIFIC_NAME \
        SPECIES_ID \
        SPECIES_FULL_TRIVIAL_NAME \
        PROJECT_DESCRIPTION \
        GENOME_SIZE \
        NCBI_TAXONOMY_ID | tee meta-data.rc

    sed "s/{{PROJECT_ID}}/${PROJECT_ID}/g" ../README.template.md >& ../README.md
    sed -i "s/{{PROJECT_SOURCE}}/${PROJECT_SOURCE}/g" ../README.md
    sed -i "s/{{SPECIES_FULL_SCIENTIFIC_NAME}}/${SPECIES_FULL_SCIENTIFIC_NAME}/g" ../README.md
    sed -i "s/{{SPECIES_ID}}/${SPECIES_ID}/g" ../README.md
    sed -i "s/{{SPECIES_FULL_TRIVIAL_NAME}}/${SPECIES_FULL_TRIVIAL_NAME}/g" ../README.md
    sed -i "s/{{PROJECT_DESCRIPTION}}/${PROJECT_DESCRIPTION}/g" ../README.md
    sed -i "s/{{GENOME_SIZE}}/${GENOME_SIZE}/g" ../README.md
    sed -i "s/{{NCBI_TAXONOMY_ID}}/${NCBI_TAXONOMY_ID}/g" ../README.md
    sed -i "s/{{SANGER_TOLID}}/${SANGER_TOLID}/g" ../README.md

    cp ../README.md ../README.template2.md
    
    sed -i "s/{{PROJECT_ID_INPUT}}/${PROJECT_ID}/g" setup_pacbioLoFi.sh
    sed -i "s/{{GSIZE_INPUT}}/${GENOME_SIZE}/g" setup_pacbioLoFi.sh
    
    sed -i "s/{{PROJECT_ID_INPUT}}/${PROJECT_ID}/g" setup_pacbioHiFi.sh
    sed -i "s/{{GSIZE_INPUT}}/${GENOME_SIZE}/g" setup_pacbioHiFi.sh

    sed -i "s/{{PROJECT_ID}}/${PROJECT_ID}/g" run_HiFiConsensus.template.sh
    
    sed -i "s/{{PROJECT_ID}}/${PROJECT_ID}/g" submit_LongRanger.sh

    sed -i "s/{{PROJECT_ID}}/${PROJECT_ID}/g" submit_GenomeScope.sh

    sed -i "s/{{PROJECT_ID}}/${PROJECT_ID}/g" illumina_qc/run_hicQC.slurm
    sed -i "s/{{PROJECT_ID}}/${PROJECT_ID}/g" illumina_qc/run_10xQC.slurm

    species_id=${PROJECT_ID:4:7}

    sed "s/{{PROJECT_ID}}/${species_id}/g" ./LongRanger/template.longranger.config.sh >& ./LongRanger/${PROJECT_ID}.longranger.config.sh
    sed -i "s/{{GSIZE_INPUT}}/${GENOME_SIZE}/g" ./LongRanger/${PROJECT_ID}.longranger.config.sh
    sed "s/{{PROJECT_ID}}/${species_id}/g" ./GenomeScope/template.genomescope.config.sh >& ./GenomeScope/${PROJECT_ID}.genomescope.config.sh
    sed -i "s/{{GSIZE_INPUT}}/${GENOME_SIZE}/g" ./GenomeScope/${PROJECT_ID}.genomescope.config.sh
    
    sed -i "s/{{PROJECT_ID}}/${species_id}/g" ../rawdata/10x/create_symLinks.sh

    sed -i "s/{{PROJECT_ID}}/${PROJECT_ID}/g" ./bionano/assembly_v3.5.1_DLE1_noES.slurm
    sed -i "s/{{PROJECT_ID}}/${PROJECT_ID}/g" ./bionano/assembly_v3.5.1_DLE1_default.slurm

    git add ../README.md
    git add ../README.template.md
    git add ../.gitignore
    git add ../.editorconfig
    git add ../LICENSE
    git add -f meta-data.rc
    git add -f init-project.sh
    git add -f */.keep
    git add -f ../data/*/.keep
    git add -f ../data/pacbio/*/.keep
    git add -f ../data/pacbio/lofi/*/.keep
    git add -f ../*/.keep
    git add -f ../QC/*/.keep
    git add -f ../QC/pacbio/*/.keep
    git add -f ../QC/pacbio/lofi/*/.keep
    git add -f ../QC/pacbio/hifi/*/.keep

    git commit -m "Initial commit"

    any_remote=$(git remote -v | wc -l)

    token=$(<~/github_token.txt)
    # GH_TOKEN needs to be set in order to get gh working properly
    export GH_TOKEN="${token}"
    
    if [ $any_remote -eq 0 ];
    then
        git remote add ${PROJECT_ID} "https://${token}@github.com/NBISweden/${PROJECT_ID}.git"
        gh repo create --source=../ --private NBISweden/${PROJECT_ID}.git
    else

        is_remoteThere=$(git ls-remote --heads git@github.com:NBISweden/${PROJECT_ID}.git master | wc -l)

        if [ $is_remoteThere -eq 1 ];
        then
            echo "Git remote exists"
        else          
            git remote add ${PROJECT_ID} "https://${token}@github.com/NBISweden/${PROJECT_ID}.git"
            gh repo create --source=../ --private NBISweden/${PROJECT_ID}.git
        fi
    fi

    git push ${PROJECT_ID}

    # add git repo to the corresponding team 
    #TODO add the other teams as well VREBP and Other
    org=NBISweden; 
    if [[ ${PROJECT_SOURCE} == "ERGA"  ]]
    then 
        team="ERGA assemblies"; 
        
        ## TODO should we hard code the team ID ?? 7704367
        teamid=$(curl -H "Authorization: Token ${token}" -s  "https://api.github.com/orgs/$org/teams" |     jq --arg team "$team" '.[] | select(.name==$team) | .id')
        
    elif [[ ${PROJECT_SOURCE} == "VREBP"  ]]
    then 
        team="VREBP assemblies"; 
        ## TODO should we hard code the team ID ?? 7718981
        teamid=$(curl -H "Authorization: Token ${token}" -s  "https://api.github.com/orgs/$org/teams" |     jq --arg team "$team" '.[] | select(.name==$team) | .id')
    else
        >&2 echo "[WARN] - Team assignment for source \"${PROJECT_SOURCE}\" needs to be added to intit_project.sh"
    fi 
     

    if [[ "x${teamid}" == "x" ]]
    then 
        >&2 echo "[ERROR] - Could not get team id of the \"${team}\" team. The Git repo ${PROJECT_ID} has to be manually added to a team"
    else 
        curl -v -H "Authorization: Token ${token}" -d "" -X PUT "https://api.github.com/teams/$teamid/repos/$org/${PROJECT_ID}"
    fi
}

main "$@"