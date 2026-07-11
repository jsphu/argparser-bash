#!/usr/bin/env bash

# Private function
__argparser() {

  # FUNCTION DEFINITIONS
  __debug() {
    if ! $DEBUG; then
      return
    fi

    if (( $# > 1 )); then
      input=("$@")
    else
      input="$1"
    fi

    printf "\033[1;31m[DEBUG]\033[0;33m %s\033[0m\n" "${input[@]}" 1>&2
  }

  __usage() {
    cat <<-'EOF'
usage: argparser [-hdo] OPTIONSTRING NAME [arg ...]
An extended version of getopts command

options:
    -h                shows this usage
    -d                debug mode
    -o                add display function for options
                      call it with: `ARGPARSEROPTIONS`

parser rules:
    option            -o or --option
    option,t          (-o or --option) and -t
    o:                -o=? or -o ?
    *option           --option
    *cat~bat          --cat or --bat
    time~hour         -t or --time or --hour
    d:int             -d=INTEGER or -d INTEGER
    s:[s|b]           -s=STRING or -s=BYTE ...
    c:(always|never)  -c="always" or -c="never" ...

available types:
    : :any                    (default) anything
    :(match|exact|same|thing) only exact same thing given
    :? :bool :boolean         true or false
    :i :int :integer          -36893488147419103232 to 36893488147419103232
    :f :float :double         +-36893488147419103232.36893488147419103232
    :b :byte :bytes           anything
    :d :date :datetime        whatever 'date -d' command allows
    :s :str :string           anything
    :u :url                   URLs, https://example.com or example.com etc.
    :p :path                  file path
    :c :char :character       single literals 'a', 'b' etc.
    :a :alpha :alphabetical   only alphabetical words

EOF
  }

  __is_type_valid() {
    local d="$1" types=()
    shift 1
    IFS="$d" read -r -a types <<<"$@"
    for t in "${types[@]}"; do
      t="${t/\[/}"
      t="${t/\]/}"
      if [[ *" ${VALIDTYPES[*]} "* != *" ${t} "* ]]; then
        return 1
      fi
    done
  }

  __is_bool() { [[ ${1,,} =~ ^(true|false)$ ]]; return $?; }
  __is_int() { [[ $1 =~ ^(\+|\-)?[0-9]+$ ]]; return $?; }
  __is_float() { [[ $1 =~ ^(\+|\-)?[0-9]*(\.|,)[0-9]*$ ]]; return $?; }
  __is_byte() { [[ $1 =~ ^.*$ ]]; return $?; }
  __is_str() { [[ ! $1 =~ ^$ ]]; return $?; }
  __is_date() { date -d "$1" >/dev/null 2>&1; return $?; }
  __is_strict() { [[ $1 =~ ^($2)$ ]]; return $?; }
  __is_char() { [[ $1 =~ ^[a-zA-Z]$ ]]; return $?; }
  __is_alpha() { [[ $1 =~ ^[a-zA-Z]+$ ]]; return $?; }
  __is_url() { [[ $1 =~ ^([a-zA-Z0-9]+://)?([a-zA-Z0-9-]+\.)?[a-zA-Z]+\.[a-z]+(\/.*)?$ ]]; return $?; }
  __is_path() { [[ $1 =~ ^(/|\.|~).* ]]; return $?; }

  __validate_type() {
    local arg="$1"
    local typ="$2"
    local ret=0
    __debug "checking '$arg' for '${typ}'"

    IFS='|' read -ra typs <<<"${typ}"
    for i in "${!typs[@]}"; do
      t="${typs[$i]}"
      case "${t,,}" in
        bool|boolean|?) __is_bool "$arg"; ret=$?;;
        i|int|integer) __is_int "$arg"; ret=$?;;
        f|float|double) __is_float "$arg"; ret=$?;;
        b|byte|bytes) __is_byte "$arg"; ret=$?;;
        d|date|datetime) __is_date "$arg"; ret=$?;;
        s|str|string) __is_str "$arg"; ret=$?;;
        u|url) __is_url "$arg"; ret=$?;;
        c|char|character) __is_char "$arg"; ret=$?;;
        a|alpha|alphabetical) __is_alpha "$arg"; ret=$?;;
        p|path) __is_path "$arg"; ret=$?;;
        any) ret=0;;
        strict) __is_strict "$arg" "${typ#STRICT|*}"; return $?;;
        *) ret=1;;
      esac
      [[ $ret -eq 1 ]] && _ret="False" || _ret="True"
      __debug "is '$arg' type of '$t'? => $_ret"
      if [[ $ret -ne 0 ]]; then
        return $ret
      fi
    done
    return $ret
  }

  __is_option_valid() {
    local option=$1
    for o in "${!argstable[@]}"; do
      if [[ $o =~ ^[^\.]+\.NAME$ ]]; then
        IFS='|' read -r -a names <<<"${argstable[$o]}"
        if [[ *" ${names[*]} "* == *" $option "* ]]; then
          return 0
        fi
      fi
    done

    return 1
  }

  # MAIN FUNCTION STARTS HERE
  OLDOPTIND=$OPTIND
  OPTIND=1
  DEBUG=false OPTIONDISPLAY=false
  while getopts "hdo" prompt; do
  case "$prompt" in
    h) __usage; return;;
    d) DEBUG=true ;;
    o) OPTIONDISPLAY=true;;
  esac
  done
  shift $((OPTIND - 1))
  OPTIND=$OLDOPTIND

  if [[ -z $1 ]]; then
      __usage
      return 1
  fi

  declare -a VALIDTYPES=(
    "i" "int" "integer"
    "f" "float" "double"
    "?" "bool" "boolean"
    "s" "str" "string"
    "b" "byte" "bytes"
    "d" "date" "datetime"
    "c" "char" "character"
    "a" "alpha" "alphabetical"
    "u" "url"
    "p" "path"
    "strict"
    "any"
  )

  declare -A argstable
  declare -A realopts
  IFS="${ARGPARSEROPTIONSDELIM:-,}" read -r -a args <<<"${1//[[:space:]]/}"
  for i in "${args[@]}"; do

    # skip if empty argument is there
    [[ -z ${i} ]] && continue

    if [[ $i =~ ^([^:]+)(:)?(.*)$ ]]; then
      NAME=${BASH_REMATCH[1]}
      COLON=${BASH_REMATCH[2]}
      TYPE=${BASH_REMATCH[3]}

      [[ -n $COLON ]] && BOOL=false || BOOL=true

      # if option have '*' prefix, treat it as only long option
      # meaning; it will not have alias as its first letter
      [[ ${NAME:0:1} == \* ]] && NOSHORT=true || NOSHORT=false

      NAMEINDEX= NAMEVALUE=
      # if option have a long name
      if (( ${#NAME} > 1 )); then

        # if option have aliases
        # e.g.: "help~?~usage"
        if [[ ${NAME} =~ \~ ]]; then
          IFS='~' read -r -a NAMES <<< "${NAME}"
          # declare -p NAMES >&2
          printf -v NAME "%s|" ${NAMES[@]}

          if $NOSHORT; then
            NAME="${NAME:1}"
            NAMEVALUE="${NAME%|}"
          else
            NAMEVALUE="${NAME:0:1}|${NAME%|}"
          fi

          NAMEINDEX="${NAME%%|*}.NAME"

          # return back to first name for naming keys
          NAME="${NAME%%|*}"

          # add aliases to point main name
          for ((j=1; j<${#NAMES[@]}; j++)); do
            [[ -n "${NAMES[$j]}" ]] || continue
            realopts["${NAMES[$j]}"]="${NAME}"
          done

        else

          if $NOSHORT; then
            NAME="${NAME:1}"
            NAMEVALUE="${NAME}"
          else
            NAMEVALUE="${NAME:0:1}|${NAME}"
          fi

          NAMEINDEX="${NAME}.NAME"
        fi

        # else if option have no long name
      else
        NAMEINDEX="${NAME}.NAME"
        NAMEVALUE="${NAME}"
      fi


      TYPEINDEX= TYPEVALUE=
      # if any type annotation has done
      if [[ -n ${COLON} ]]; then

      # if type is set to strict match
      if [[ ${TYPE} =~ ^\(.*\)$ ]]; then
        trimmed_type="${BASH_REMATCH[0]/\(/}"
        trimmed_type="${trimmed_type/\)/}"

        TYPEINDEX="${NAME}.TYPE"
        TYPEVALUE="STRICT|${trimmed_type}"

        # if type is a union type (multiple) match
      elif [[ ${TYPE} =~ ^\[[^\]+]\]$ ]]; then
        trimmed_type="${BASH_REMATCH[0]/\[/}"
        trimmed_type="${trimmed_type/\]/}"

        if __is_type_valid '|' "${trimmed_type}"; then
          TYPEINDEX="${NAME}.TYPE"
          TYPEVALUE="${trimmed_type}"

        else
          echo "Unkown types: ${trimmed_type}" 1>&2
          ok=false
        fi
        # default is only one type
      elif [[ -n ${TYPE} ]]; then

        if __is_type_valid '|' "${TYPE}"; then
          TYPEINDEX="${NAME}.TYPE"
          TYPEVALUE="${TYPE}"

        else
          echo "Unkown type: ${TYPE}" 1>&2
          ok=false
        fi
        # no type is given, defaults to 'ANY' type
      else
        TYPEINDEX="${NAME}.TYPE"
        TYPEVALUE="ANY"
      fi
    fi

    # no argument required
    else
    argstable["${i:0:1}.NAME"]="${i}"
    fi

    if [[ -n "$NAMEINDEX" && -n "${NAMEVALUE}" ]]; then

      argstable["${NAMEINDEX}"]="${NAMEVALUE}"

      argstable["${NAME}.BOOL"]="$BOOL"
    fi

    if [[ -n "$TYPEINDEX" && -n "${TYPEVALUE}" ]]; then

      argstable["${TYPEINDEX}"]="${TYPEVALUE}"

    fi
  done
  shift 1

  # __debug "parsed options:"
  # $DEBUG && paste -d $'\t' <(printf "\033[1;31m[DEBUG]\033[0;33m %s\n" "${!argstable[@]}") <(printf "%s\n" "${argstable[@]}") | sort -k1 | column -to " = " -s $'\t' 1>&2

  # assign argparse options to this variable
  # just like getopts' NAME
  OPT="$1"
  shift 1

  # __debug "assigning to name: '$OPT'"

  CUR_OPTIND=${1:-1}
  shift 1

  # 1-based offset into the CURRENT argv token (item), pointing at the
  # next unconsumed character after the leading '-'. This is what lets
  # a combined cluster like -lhtra survive across separate calls to
  # this function: OPTIND alone can only point at a whole argv token,
  # it can't say "we're 2 characters into it", so that position has to
  # be threaded through the same eval-based round-trip OPTIND uses.
  CUR_OPTSUBIND=${1:-1}
  shift 1

  REMAINING_ARGS=("${@:CUR_OPTIND}")

  item="${REMAINING_ARGS[0]}"

  # __debug "choose '$item' inside '${REMAINING_ARGS[*]}', subind=$CUR_OPTSUBIND"

  ok=true

  if [[ -z $item || "$item" != -* ]]; then
    __debug "no more options, item='$item'"
    __debug "$OPT='+'; OPTIND=$CUR_OPTIND; OPTSUBIND=1; false"
    echo "$OPT='+'; OPTIND=$CUR_OPTIND; OPTSUBIND=1; false"
    return 1
  fi

  $ok && found_opt="" || found_opt="+"

  found_arg=""
  next_optind=$((CUR_OPTIND + 1))
  next_optsubind=1

  # is the option long formatted? '--help' '--long' etc.
  if $ok && [[ $item =~ ^-- ]]; then
    __debug "long option: $item"

    opt_raw="${item#--}"
    if [[ "$opt_raw" =~ = ]]; then
      opt_name="${opt_raw%%=*}"
      found_arg="${opt_raw#*=}"
    else
      opt_name="$opt_raw"
      # found_arg="${REMAINING_ARGS[$next_optind]}"
    fi

    if ! __is_option_valid "$opt_name"; then
      # if [[ *" ${args[*]} "* != *"${opt:2}"* ]]; then

      echo "echo 'illegal option: --$opt_name' >&2;"
      found_opt=$'\?'
      ok=false
    fi

    for key in "${!argstable[@]}"; do
      if [[ "$key" == *.NAME ]]; then
        IFS='|' read -r -a names <<< "${argstable[$key]}"
        for n in "${names[@]}"; do
          if [[ "$n" == "$opt_name" ]]; then
            found_opt="${key%.NAME}"
            break 2
          fi
        done
      fi
    done

    if ! ${argstable[$found_opt.BOOL]} && [[ -z "$found_arg" ]]; then
      # Value is in the NEXT argument
      found_arg="${REMAINING_ARGS[1]}"
      if [[ -z $found_arg ]]; then
        echo "echo 'option --$found_opt needs argument (${argstable[$found_opt.TYPE]})' >&2;"
        ok=false
        found_opt=$'\?'
      fi
      next_optind=$((CUR_OPTIND + 2))
    fi

    # is the option short formatted? '-h' '-hlts' etc.
  elif $ok && [[ $item =~ ^- ]]; then
    __debug "short option: $item (char index $CUR_OPTSUBIND)"
    char="${item:CUR_OPTSUBIND:1}"
    if ! __is_option_valid "$char"; then
      echo "echo 'illegal option: -$char' >&2;"
      found_opt=$'\?'
      ok=false
    fi

    # Find the main name for this char
    for key in "${!argstable[@]}"; do
      if [[ "$key" == *.NAME ]]; then
        IFS='|' read -r -a names <<< "${argstable[$key]}"
        for n in "${names[@]}"; do
          if [[ "$n" == "$char" ]]; then
            found_opt="${key%.NAME}"
            break 2
          fi
        done
      fi
    done

    # Handle required arguments
    if ! ${argstable[$found_opt.BOOL]}; then
      if (( CUR_OPTSUBIND + 1 < ${#item} )); then
        # -n10 / -lhtra format: whatever is left of this token
        # (after the option char itself) becomes the value, e.g.
        # for -lhtra with l,h boolean and t taking a value, once we
        # reach 't' the remaining "ra" becomes its argument.
        found_arg="${item:CUR_OPTSUBIND+1}"
        found_arg="${found_arg#=}"
        next_optind=$((CUR_OPTIND + 1))
        next_optsubind=1
      else
        # -n 10 format: value is the next whole token
        found_arg="${REMAINING_ARGS[1]}"
        next_optind=$((CUR_OPTIND + 2))
        next_optsubind=1
      fi

      if [[ -z $found_arg ]]; then
        echo "echo 'option -${found_opt:0:1} needs argument (${argstable[$found_opt.TYPE]})' >&2;"
        found_opt=$'\?'
        ok=false
      fi
    else
      # Boolean flag. If there are more characters left in this
      # cluster (e.g. -lhtra with 'l' just consumed, "htra" left),
      # stay on the SAME argv token and just move the character
      # pointer forward instead of advancing to the next token.
      if (( CUR_OPTSUBIND + 1 < ${#item} )); then
        next_optind=$CUR_OPTIND
        next_optsubind=$((CUR_OPTSUBIND + 1))
      else
        next_optind=$((CUR_OPTIND + 1))
        next_optsubind=1
      fi
    fi

  fi

  t="${argstable[$found_opt.TYPE]}"

  if [[ -n ${t} ]] && ! __validate_type "$found_arg" "${t}"; then
    if [[ "$t" == "STRICT"* ]]; then
      IFS='|' read -ra t<<<"$t"
      printf -v t "%s, " ${t[@]:1}
      echo "echo \"invalid option argument for '$found_opt': '$found_arg' is not one of them: ${t}\" >&2"
    else
      echo "echo \"invalid option argument for '$found_opt': '$found_arg' is not $t\" >&2"
    fi
    ok=false
    found_opt=$'\?'
    found_arg=""
  fi


  if $OPTIONDISPLAY; then
    echo -e "ARGPARSEROPTIONS() {"
    cat <<EOF
    if [[ -n "\$ARGPARSERUSAGE" || -n "\$ARGPARSERCOMMAND" ]]; then
      if [[ -n "\$ARGPARSERCOMMAND" && -n "\$ARGPARSERARGS" ]]; then
      echo -e "usage: \$ARGPARSERCOMMAND [$(
        printf -- '--%s\n| ' "${!argstable[@]}" |
          grep '\.NAME$' |
          sed 's/\.NAME$//' |
          tr '\n' ' '
      )] \$ARGPARSERARGS"
      else
        echo -e "usage: \$ARGPARSERUSAGE"
      fi
      if [[ -n "\$ARGPARSERDESCRIPTION" ]]; then
        echo -e "\$ARGPARSERDESCRIPTION"
      fi
      echo ""
      echo "options: "
    fi
EOF
    echo -e "    cat <<EOF"

    # Step 1: Initialize an array to store lines and track the maximum length for column alignment
    local -a lines=()
    local max_opt_len=0

    for arg in "${!argstable[@]}"; do
      if [[ $arg =~ \.NAME$ ]]; then
        local argname="${arg%*.NAME}"
        local _argname="${argname//-/_}"
        IFS='|' read -ra arr <<<"${argstable[$arg]}"
        
        # Build the options string (e.g., "    -h, --help")
        local opt_str="    "
        local z=0
        local arr_len=${#arr[@]}
        for r in "${arr[@]}"; do
          if (( z != arr_len && z != 0 )); then
            opt_str+=","
          fi
          if (( ${#r} > 1 )); then
            opt_str+=" --$r"
          else
            opt_str+=" -$r"
          fi
          ((z++))
          if (( arr_len == 1 )); then
            break
          fi
        done

        local ARGPARSERTYPE=""
        if [[ -n "${argstable[$argname.TYPE]}" ]]; then
          opt_str+=" ${_argname^^}"
          if [[ "$ARGPARSERSHOWTYPES" == "true" || "$ARGPARSERSHOWTYPES" -eq 1 ]]; then
            printf -v ARGPARSERTYPE "[${argstable[$argname.TYPE],,}] "
            if [[ "$ARGPARSERTYPESUPPERCASE" == "true" || "$ARGPARSERTYPESUPPERCASE" -eq 1 ]]; then
              ARGPARSERTYPE=${ARGPARSERTYPE^^}
            fi
            if [[ "$ARGPARSERTYPESNEXT" == "true" || "$ARGPARSERTYPESNEXT" -eq 1 ]]; then
              opt_str+=" ${ARGPARSERTYPE}"
              ARGPARSERTYPE=""
            fi
          fi
        fi

        # Track the maximum length of the left-hand side column
        if (( ${#opt_str} > max_opt_len )); then
          max_opt_len=${#opt_str}
        fi

        # Store the left side, the type info, and the variable name for later rendering
        lines+=("${opt_str}"$'\x1f'"${ARGPARSERTYPE}"$'\x1f'"\$ARGPARSER_${_argname^^}")
      fi
    done

    for line in "${lines[@]}"; do
      IFS=$'\x1f' read -r opt_part type_part desc_part <<< "$line"
      # %b safely processes backslash escapes if they exist in type
      # %-*s dynamically pads the option string to the maximum length found
      printf "%-*s  %b%b\n" "$max_opt_len" "$opt_part" "$type_part" "$desc_part"
    done

    echo "EOF"
    cat <<'EOF'
    if [[ -n "$ARGPARSERBOTTOMTEXT" ]]; then
      echo ""
      echo -e "$ARGPARSERBOTTOMTEXT"
    fi
EOF
    echo ""
    echo "};"
  fi

  __debug "$OPT='$found_opt'; OPTARG='$found_arg'; OPTIND=$next_optind; OPTSUBIND=$next_optsubind; ok=$ok;"

  if [[ "$found_opt" == "+" ]] && (( next_optind <= CUR_OPTIND )); then
      next_optind=$((CUR_OPTIND + 1))
      next_optsubind=1
  fi

  if [[ -n "$found_opt" ]]; then
    echo "$OPT='$found_opt'; OPTARG='$found_arg'; OPTIND=$next_optind; OPTSUBIND=$next_optsubind; $ok"
  else
    echo "$OPT='?'; OPTIND=$next_optind; OPTSUBIND=$next_optsubind; false"
  fi
  return 0
}

# Public function
function argparser() {
  local OPTSTR="$1" OPTNAM="$2" c=""
  [[ -z $OPTSTR || -z $OPTNAM ]] && unset -f __argparser && return 2 
  shift 2

  # OPTSUBIND tracks how far we are INTO a combined short-option cluster,
  # character by character, across separate calls to this function.
  : "${OPTSUBIND:=1}"

  c=$(__argparser -o "$OPTSTR" "$OPTNAM" "$OPTIND" "$OPTSUBIND" "$@")
  eval "$c"

  if [[ ${!OPTNAM} == "+" ]]; then
    return 1
  fi

  if [[ $c =~ [[:space:]]true$ ]]; then
    return 0
  else
    return 1
  fi
}

if ! (return 2>/dev/null); then
  __argparser $@
fi
