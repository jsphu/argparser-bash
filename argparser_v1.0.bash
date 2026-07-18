#!/usr/bin/env bash
# WORK IN PROGRESS
# It works but needs improvement and more optimization

# Private function
__argparser() {

    __parser() {
      for key in "${!ARGPARSER[@]}"; do
        value="${ARGPARSER[$key]}"

        case "${key,}" in
          option:*|opt:*|o:*)
              key="${key#*:}"
              key="${key%%:*}"
              [[ $key =~ ^\* ]] &&
                key="${key#\*}"
              [[ $key =~ \~ ]] &&
                key="${key%%~*}"
              if [[ $key =~ \+([2-9][0-9]*) ]]; then
                local multi_count="${BASH_REMATCH[1]}"
                key="${key/\+${multi_count}/}"
                if [[ $value =~ ^\[([^\]]+)\] ]]; then
                  local -a multi_names=()
                  IFS=']' read -ra multi_names <<<"${value}"
                  local _i=0
                  for _n in "${multi_names[@]:0:multi_count}"; do
                    _n="${_n##*\[}"
                    [[ -n "$_n" ]] && ARGPARSER["${key}:$_i"]="$_n"
                    (( _i++ ))
                  done
                  value=${multi_names[@]:multi_count}
                fi
              fi
              echo "ARGPARSER['$key']='${value# *}'"
              ;;
          types)
              for val in $value; do
                case "${val,,}" in
                show)
                  ARGPARSERSHOWTYPES=true
                  ;;
                uppercase)
                  ARGPARSERTYPESUPPERCASE=true
                  ;;
                next)
                  ARGPARSERTYPESNEXT=true
                  ;;
                esac
              done
              ;;
          t*) echo "ARGPARSERTOPTEXT+=('$value')" ;;
          m*) echo "ARGPARSERMIDDLETEXT+=('$value')" ;;
          b*) echo "ARGPARSERBOTTOMTEXT+=('$value')" ;;
          u*) echo "ARGPARSERUSAGE='$value'" ;;
          d*) echo "ARGPARSERDESCRIPTION='$value'" ;;
          c*) echo "ARGPARSERCOMMAND='$value'" ;;
          argument:*|arg:*|a:*) key="${key#*:}"; echo "declare -A ARGPARSERARGS['$key']='$value'";
        esac
        __debug "$key => $value"
      done
    }
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

example of argparser usage:
declare -A ARGPARSER=(
    [option:help]="show this usage"
    [option:debug]="debug mode"
    [option:t:any]="takes argument"
    [option:multi+N]="takes #N arguments"
    [types]="show uppercase next"
    [top]="This is a sample script to demonstrate the usage of argparser."
    [mid]="This is a sample script to demonstrate the usage of argparser."
    [bot]="This is a sample script to demonstrate the usage of argparser."
    [usage]="argparser [-hdo] OPTIONSTRING NAME [arg ...]"
    [description]="An extended version of getopts command"
    [command]="argparser"
    [argument:input]="input file"
)

while argparser "$@"; do
    case "$argparser_key" in
        h) argparser_usage ;;
        d) DEBUG=true ;;
        o) OPTIONDISPLAY=true ;;
        t) T="${argparser_value[0]}" ;;
        m) MULTI="${argparser_value[@]}" ;;
    esac
done

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

options:
    -h                shows this usage
    -d                debug mode
    -o                add display function for options
                      call it with: `ARGPARSERUSAGE`

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
    local typ="$1"
    shift 1
    local args=("$@")
    __debug "__validate_type for args=(${args[*]}) with type ${typ}"
    local ret=0
    for arg in "${args[@]}"; do
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
  local OLDOPTIND=$OPTIND
  OPTIND=1
  local DEBUG=false OPTIONDISPLAY=false
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

  declare -a _shorts=() _longs=() _wants=()
  declare -A argstable
  declare -A realopts

  for key in "${!ARGPARSER[@]}"; do
    value="${ARGPARSER[$key]}"

    case "${key,}" in
      option:*|opt:*|o:*)
        i="${key#*:}"
        ;;
      *)
        continue
        ;;
    esac

    # skip if empty argument is there
    [[ -z ${i} ]] && continue

    if [[ $i =~ ^([^:]+)(:)?(.*)$ ]]; then
      NAME=${BASH_REMATCH[1]}
      COLON=${BASH_REMATCH[2]}
      TYPE=${BASH_REMATCH[3]}
      MULTIARG=1

      [[ -n $COLON ]] && BOOL=false || BOOL=true

      # if option have '*' prefix, treat it as only long option
      # meaning; it will not have alias as its first letter
      [[ ${NAME:0:1} == \* ]] && NOSHORT=true || NOSHORT=false

      # if option have '+' prefix, treat it as multi argument
      if [[ "${NAME}" =~ \+([2-9][0-9]*) ]]; then
        MULTIARG="${BASH_REMATCH[1]}"
        BOOL=false
        NAME="${NAME/\+${MULTIARG}/}"
      fi

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
      
      argstable["${NAME}.MULTI"]="${MULTIARG}"

      if [[ "${MULTIARG}" -gt 1 ]]; then
        [[ -z "${TYPEINDEX}" ]] && TYPEINDEX="${NAME}.TYPE"
        [[ -z "${TYPEVALUE}" ]] && TYPEVALUE="ANY"
      fi

    fi

    if [[ -n "$TYPEINDEX" && -n "${TYPEVALUE}" ]]; then

      argstable["${TYPEINDEX}"]="${TYPEVALUE}"

    fi

    # put arguments into arrays
    if $BOOL; then
      if $NOSHORT || [[ "$ARGPARSERFORCELONGS" -eq 1 || $ARGPARSERFORCELONGS == "true" ]]; then
        _longs+=("${NAME}")
      else
        _shorts+=("${NAME:0:1}")
      fi
    else
      _wants+=("${NAME}")
    fi
  done
  # __debug "parsed options:"
  # $DEBUG && paste -d $'\t' <(printf "\033[1;31m[DEBUG]\033[0;33m %s\n" "${!argstable[@]}") <(printf "%s\n" "${argstable[@]}") | sort -k1 | column -to " = " -s $'\t' 1>&2

  # assign argparse options to this variable
  # just like getopts' NAME
  # argparser_key=

  # __debug "assigning to name: 'argparser_key'"

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
    __debug "argparser_key='+'; OPTIND=$CUR_OPTIND; OPTSUBIND=1; false"
    echo "argparser_key='+'; OPTIND=$CUR_OPTIND; OPTSUBIND=1; false"
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

    # handle required arguments
    if ! ${argstable[$found_opt.BOOL]}; then

      # option is multi-argument and needs more argument along with the found_arg
      if [[ -n "$found_arg" && "${argstable[$found_opt.MULTI]}" -gt 1 ]]; then
        local multi_count="${argstable[$found_opt.MULTI]}"
        found_arg=("${found_arg}")

        # reduce one since we taken one argument before
        ((multi_count--))
        for ((i=1; i<=multi_count; i++)); do
          if [[ -n "${REMAINING_ARGS[i]}" ]]; then
            found_arg+=("${REMAINING_ARGS[i]}")
          else
            echo "echo 'option --$found_opt needs ${argstable[$found_opt.MULTI]} arguments (${argstable[$found_opt.TYPE]})' >&2;"
            multi_count=1
            ok=false
            found_opt=$'\?'
          fi
        done
        next_optind=$((CUR_OPTIND + 1 + multi_count))

      # Value is in the NEXT argument and is multi-argument
      elif [[ -z "$found_arg" && "${argstable[$found_opt.MULTI]}" -gt 1 ]]; then
          local multi_count="${argstable[$found_opt.MULTI]}"
          found_arg=()
          for ((i=1; i<=multi_count; i++)); do
            if [[ -n "${REMAINING_ARGS[i]}" ]]; then
              found_arg+=("${REMAINING_ARGS[i]}")
            else
              echo "echo 'option --$found_opt needs ${argstable[$found_opt.MULTI]} arguments (${argstable[$found_opt.TYPE]})' >&2;"
              multi_count=1
              ok=false
              found_opt=$'\?'
            fi
          done
          next_optind=$((CUR_OPTIND + 1 + multi_count))

      # then there is one value and in the NEXT argument  while it is not a multi-argument
      elif [[ -z "$found_arg" && "${argstable[$found_opt.MULTI]}" -eq 1 ]]; then
        found_arg="${REMAINING_ARGS[1]}"
        if [[ -z $found_arg ]]; then
          echo "echo 'option --$found_opt needs argument (${argstable[$found_opt.TYPE]})' >&2;"
          ok=false
          found_opt=$'\?'
        fi
        next_optind=$((CUR_OPTIND + 2))

      # then there is one value and in the SAME argument while it is not a multi-argument
      elif [[ -n "$found_arg" && "${argstable[$found_opt.MULTI]}" -eq 1 ]]; then
        # do nothing, found_arg is already set from the '=' assignment
        :

      # it should be unexpected
      else
        # throw error
        echo "echo 'something broke, please report this.' >&2; "
        echo "echo 'arg:$found_arg opt:$found_opt bool:$BOOL multi:${argstable[$fount_opt.MULTI]} type:${argstable[$found_opt.TYPE]}' >&2; "
      fi
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

        # check if option is multi-argument
        if [[ "${argstable[$found_opt.MULTI]}" -gt 1 ]]; then
          local multi_count="${argstable[$found_opt.MULTI]}"
          local first_arg="${item:CUR_OPTSUBIND+1}"
          found_arg=("${first_arg#=}")
          # reduce one of multi because we are taking in the same token
          ((multi_count--))
          for ((i=1; i<=multi_count; i++)); do
            if [[ -n "${REMAINING_ARGS[i]}" ]]; then
              found_arg+=("${REMAINING_ARGS[i]}")
            else
              echo "echo 'option -$char needs ${argstable[$found_opt.MULTI]} arguments (${argstable[$found_opt.TYPE]})' >&2;"
              multi_count=1
              ok=false
              found_opt=$'\?'
            fi
          done
          next_optind=$((CUR_OPTIND + 1 + multi_count))
        else
          found_arg="${item:CUR_OPTSUBIND+1}"
          found_arg="${found_arg#=}"
          next_optind=$((CUR_OPTIND + 1))
        fi

        # reset subind to 1 because short flags are done to parsing
        next_optsubind=1
      else
        # -n 10 format: value is the next whole token
        # check if option is multi-argument
        if [[ "${argstable[$found_opt.MULTI]}" -gt 1 ]]; then
          local multi_count="${argstable[$found_opt.MULTI]}"
          found_arg=()
          for ((i=1; i<=multi_count; i++)); do
            if [[ -n "${REMAINING_ARGS[i]}" ]]; then
              found_arg+=("${REMAINING_ARGS[i]}")
            else
              echo "echo 'option -$char needs ${argstable[$found_opt.MULTI]} arguments (${argstable[$found_opt.TYPE]})' >&2;"
              multi_count=1
              ok=false
              found_opt=$'\?'
            fi
          done
          next_optind=$((CUR_OPTIND + 1 + multi_count))
        else
          found_arg="${REMAINING_ARGS[1]}"
          next_optind=$((CUR_OPTIND + 2))
        fi

        # reset subind to 1 because short flags are done to parsing
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

  if [[ -n ${t} ]] && ! __validate_type "${t}" "${found_arg[@]}"; then
    if [[ "$t" == "STRICT"* ]]; then
      IFS='|' read -ra t<<<"$t"
      printf -v t "%s, " ${t[@]:1}
      echo "echo \"invalid option argument for '$found_opt': '${found_arg[@]}' is not one of them: ${t}\" >&2"
    else
      echo "echo \"invalid option argument for '$found_opt': '${found_arg[@]}' one or more fails to be '$t'\" >&2"
    fi
    ok=false
    found_opt=$'\?'
    found_arg=""
  fi


  if $OPTIONDISPLAY; then
    echo -e "argparser_usage() {"
    __parser
    cat <<'EOF'
    local NO_DESC=false NO_USAGE=false NO_TOP=false NO_MIDDLE=false NO_BOTTOM=false NO_OPTIONS=false NO_COMMAND=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -1 | -u | --one-line | --usage-only)
          NO_TOP=true NO_MIDDLE=true NO_BOTTOM=true NO_OPTIONS=true NO_COMMAND=true NO_DESC=true
          ;;
        -t | --top-only)
          NO_MIDDLE=true NO_BOTTOM=true NO_OPTIONS=true NO_USAGE=true NO_COMMAND=true NO_DESC=true
          ;;
        -m | --mid-only)
          NO_TOP=true NO_BOTTOM=true NO_OPTIONS=true NO_USAGE=true NO_COMMAND=true NO_DESC=true
          ;;
        -b | --bot-only)
          NO_TOP=true NO_MIDDLE=true NO_OPTIONS=true NO_USAGE=true NO_COMMAND=true NO_DESC=true
          ;;
        -o | --options-only)
          NO_TOP=true NO_MIDDLE=true NO_BOTTOM=true NO_USAGE=true NO_COMMAND=true NO_DESC=true
          ;;
      esac

      shift
    done

    if ! $NO_TOP; then
      if [[ "${ARGPARSERTOPTEXT@a}" == *a* ]]; then
        for line in "${ARGPARSERTOPTEXT[@]}"; do
          echo -e "$line"
        done
        echo
      else
        if [[ -n "${ARGPARSERTOPTEXT}" ]]; then
          echo -e "$ARGPARSERTOPTEXT\n"
        fi
      fi
    fi
    if ! $NO_COMMAND && [[ -n "\$ARGPARSERCOMMAND" && -n "\$ARGPARSERARGS" || "\${ARGPARSERARGS@a}" == *A* ]] ; then
EOF
      echo -e "      local -a __output=("
      if [[ ${#_shorts[@]} -ne 0 ]]; then
        echo "        \"[-$(printf "%s" "${_shorts[@]}")]\""
      fi
      if [[ ${#_longs[@]} -ne 0 ]]; then
        for _l in "${_longs[@]}"; do
          [[ -n "$_l" ]] && echo "        \"[--$_l]\""
        done
      fi
      if [[ ${#_wants[@]} -ne 0 ]]; then
        for _w in "${_wants[@]}"; do
          __w="${_w//-/_}"
          [[ -z "$_w" ]] && continue
          [[ "${#_w}" -eq 1 ]] &&
            echo "        \"[-$_w ${__w^^}]\"" ||
            echo "        \"[--$_w ${__w^^}]\""
        done
      fi
      echo -e "      )"

      cat <<'EOF_RUNTIME_WRAPPING'
          local prefix="usage: ${ARGPARSERCOMMAND} "
          local length=${#ARGPARSERCOMMAND}
          local prefix_len=$(( length + 8 ))
          
          local padding=""
          printf -v padding "%*s" "$prefix_len" ""

          local max_width=$(( COLUMNS / 2 ))   # Dynamic runtime terminal width
          local current_line="$prefix"
          local current_len=$prefix_len
          local is_first_item=1

          for item in "${__output[@]}"; do
            local item_len=${#item}
            
            if (( current_len + item_len + 1 > max_width )) && (( is_first_item == 0 )); then
              echo -e "$current_line"
              current_line="${padding}${item}"
              current_len=$(( prefix_len + item_len ))
            else
              if [[ "$current_line" == "$prefix" || "$current_line" == "$padding" ]]; then
                current_line+="${item}"
                current_len=$(( current_len + item_len ))
              else
                current_line+=" ${item}"
                current_len=$(( current_len + item_len + 1 ))
              fi
              is_first_item=0
            fi
          done
          
          echo -n "$current_line"
EOF_RUNTIME_WRAPPING
    cat <<'EOF'
      if ! $NO_COMMAND; then
        if [[ "${ARGPARSERARGS@a}" == *A* ]]; then
          for _arg in "${!ARGPARSERARGS[@]}"; do
            echo -en " <${_arg}>"
          done
        else
          if [[ -n "$ARGPARSERARGS" ]]; then
            echo -en " ${ARGPARSERARGS@U}"
          fi
        fi
        echo ""
      fi
    elif ! $NO_USAGE && [[ -n "$ARGPARSERUSAGE" ]]; then
      echo -e "usage: $ARGPARSERUSAGE"
    fi
    if ! $NO_DESC; then
      if [[ -n "$ARGPARSERDESCRIPTION" ]]; then
        echo -e "$ARGPARSERDESCRIPTION"
      fi

      if [[ "${ARGPARSERARGS@a}" == *A* ]]; then
        echo ""
        local _max_arg_def_len=0 _max_arg_len=0
        for _arg in "${!ARGPARSERARGS[@]}"; do
          local _argdef="${ARGPARSERARGS[$_arg]}"
          if (( ${#_argdef} > _max_arg_def_len )); then
            _max_arg_def_len=${#_argdef}
          fi
          if (( ${#_arg} > _max_arg_len )); then
            _max_arg_len=${#_arg}
          fi
        done
        for _arg in "${!ARGPARSERARGS[@]}"; do
          local _arg_len=${#_arg} _arg_def_len=${#ARGPARSERARGS[$_arg]}
          _arg_def_len=$(( _max_arg_len + 4 + _max_arg_def_len - _arg_def_len ))
          printf '    %+*s\t%*s\n' "$_arg_len" "<${_arg}>" "$_arg_def_len" "${ARGPARSERARGS[$_arg]}"
        done
      fi
    fi

    if ! $NO_MIDDLE; then
      if [[ "${ARGPARSERMIDDLETEXT@a}" == *a* ]]; then
        echo ""
        for line in "${ARGPARSERMIDDLETEXT[@]}"; do
          echo -e "$line"
        done
      else
        if [[ -n "$ARGPARSERMIDDLETEXT" ]]; then
          echo -e "\n$ARGPARSERMIDDLETEXT"
        fi
      fi
    fi

    if ! $NO_OPTIONS; then
      echo ""
      echo "options: "
EOF
    echo -e "     cat <<EOF"

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
          if [[ "${argstable[$argname.MULTI]}" -gt 1 ]]; then
            local count="${argstable[$argname.MULTI]}"
            if [[ -n "${ARGPARSER[$argname:0]}" ]]; then
              for _i in $(seq 0 $count); do
                opt_str+=" ${ARGPARSER[${argname}:${_i}]}"
              done
            else
              _argname="${_argname:0:3}..."
              for _i in $(seq 1 $count); do
                opt_str+=" ${_argname^^}"
              done
            fi
          else
            opt_str+=" ${_argname^^}"
          fi
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
        lines+=("${opt_str}"$'\x1f'"${ARGPARSERTYPE}"$'\x1f'"\${ARGPARSER['${argname}']}")
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
    fi

    if ! $NO_BOTTOM; then
      if [[ "${ARGPARSERBOTTOMTEXT@a}" == *a* ]]; then
        echo ""
        for line in "${ARGPARSERBOTTOMTEXT[@]}"; do
          echo -e "$line"
        done
      else
        if [[ -n "${ARGPARSERBOTTOMTEXT}" ]]; then
          echo -e "\n$ARGPARSERBOTTOMTEXT"
        fi
      fi
    fi
EOF
    echo ""
    echo "};"
  fi


  __debug "argparser_key='$found_opt'; argparser_value='$found_arg' OPTIND=$next_optind; OPTSUBIND=$next_optsubind; ok=$ok;"

  if [[ "$found_opt" == "+" ]] && (( next_optind <= CUR_OPTIND )); then
      next_optind=$((CUR_OPTIND + 1))
      next_optsubind=1
  fi

  if [[ -n "$found_opt" && -n "${found_arg}" ]]; then
    if [[ "${#found_arg[@]}" -gt 1 && $ok ]]; then
      __debug "found multi-argument: (${found_arg[*]})"
      echo -n "argparser_key='$found_opt'; argparser_value=("
      for arg in "${found_arg[@]}"; do
        echo -n "'$arg' "
      done
      echo "); OPTIND=$next_optind; OPTSUBIND=$next_optsubind; $ok"
    else
      echo "argparser_key='$found_opt'; argparser_value='${found_arg}'; OPTIND=$next_optind; OPTSUBIND=$next_optsubind; $ok"
    fi
  elif [[ -n "$found_opt" ]]; then
    echo "argparser_key='$found_opt'; argparser_value=; OPTIND=$next_optind; OPTSUBIND=$next_optsubind; $ok"
    # echo "argparser_key='$found_opt'; argparser_value=('${found_arg[@]}'); OPTIND=$next_optind; OPTSUBIND=$next_optsubind; $ok"
  else
    echo "argparser_key='?'; OPTIND=$next_optind; OPTSUBIND=$next_optsubind; false"
  fi
  return 0
}

# Public function
function argparser() {
  # OPTSUBIND tracks how far we are INTO a combined short-option cluster,
  # character by character, across separate calls to this function.
  : "${OPTSUBIND:=1}"

  c=$(__argparser -o "$OPTIND" "$OPTSUBIND" "$@")
  eval "$c"

  if [[ ${argparser_key} == "+" ]]; then
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

