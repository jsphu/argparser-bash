# argparser _for bash_

## Download & Install
Download from releases: [argparser.bash v0.0.1](https://github.com/jsphu/argparser-bash/releases/download/v0.0.1/argparser.bash)
```bash
wget -O argparser.bash "https://github.com/jsphu/argparser-bash/releases/download/v0.0.1/argparser.bash"
# or using curl
curl -fsSL "https://github.com/jsphu/argparser-bash/releases/download/v0.0.1/argparser.bash" > argparser.bash
```

### Pull source code
```bash
git clone https://github.com/jsphu/argparser-bash.git
# or using ssh
git clone git@github.com:jsphu/argparser-bash.git
```

### Add this to .bashrc, or source on runtime
```bash
# now you can source this on anytime
source argparser.bash
```

## Usage
```bash
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
    :c :char :character       single literals 'a', 'b' etc.
    :a :alpha :alphabetical   only alphabetical words
```

### Example Usage

```bash
function sozluk() {
  source /path/to/argparser.bash # < source your argparser here
  # important, OPTIND=1 is needed for every argparser
  OPTIND=1 LIMIT=5 XARGSLIMIT=

  # argparser is insensitive to any spaces, you can do anything with newlines etc.
  printf -v opts '
    limit   ~ limit-output  ~ total       :integer  ,
    newline ~ delim-newline ~ printlines  ~ lines   ,
    help    ~ usage
  ' # or you can simply do this:
  opts='limit:integer,help,newline' # do not forget to put ',' between options
  # TODO: Add an ARGPARSEROPTIONSDELIM= environment variable to change ',' comma with anything.

  while argparser "$opts" opt "$@"; do
    case "$opt" in # < same as getopts command, match option
    help)
      echo "usage: sozluk [-h] [-l LIMIT] WORD [WORD ...]"
      echo "Direct translations of words TR-TR, TR-EN"
      echo ""
      echo "options:"
      ARGPARSER_HELP="prints this and exits"            # the template is simple
      ARGPARSER_LIMIT="set a word limit to display"     # put your first option name
      ARGPARSER_NEWLINE="seperate words with newlines"  # after 'ARGPARSER_' prefix
      ARGPARSERSHOWTYPES=1        # this enables types to be seen on ARGPARSEROPTIONS
      ARGPARSERTYPESNEXT=1        # puts types next to the option arguments
      ARGPARSERTYPESUPPERCASE=1   # makes types uppercase [int] -> [INT]
      ARGPARSEROPTIONS            # display options with this function
      return
      ;;
    limit)
      LIMIT="${OPTARG}" # < Same as getopts command, take argument
      ;;
    newline)
      XARGSLIMIT='-L1'
      ;;
    \?) # < if argparser fails, it will give '?' as output.
      return 1
      ;;
    \+) # < this will match if argparser not found an option
        # i do not recommend you to use this, probably not gonna work as you expect
      echo "Translating: $opt, please wait a couple seconds."
      ;;
    esac
  done
  shift $((OPTIND - 1)) # <-- just like getopts, shift all options
  unset -f argparser __argparser # no need to do this, but might be good idea
  if [[ -z $@ ]]; then
    echo "usage: sozluk [-hn] [-l LIMIT] WORD [WORD ...]"
    return 1
  fi
  local words=$(tr '[[:space:]]' '-' <<<"$@")
  local url="https://www.seslisozluk.net/${words}nedir-ne-demek/"
  curl -fsSL "$url" |
    pup 'a.definition-link text{}' |
    head -n ${LIMIT} |
    xargs ${XARGSLIMIT} echo
}
```

Example - 1: (types enabled, uppercase and next to arguments)

```bash
$ sozluk --help
usage: sozluk [-hn] [-l LIMIT] WORD [WORD ...]
Direct translations of words TR-TR, TR-EN

options:
     -l, --limit, --limit-output, --total LIMIT [INTEGER]   set a word limit to display
     -n, --newline, --delim-newline, --printlines, --lines  seperate words with newlines
     -h, --help, --usage                                    prints this and exits
```

Example - 2: (types disabled)

```bash
$ sozluk -h
usage: sozluk [-hn] [-l LIMIT] WORD [WORD ...]
Direct translations of words TR-TR, TR-EN

options:
     -l, --limit, --limit-output, --total LIMIT             set a word limit to display
     -n, --newline, --delim-newline, --printlines, --lines  seperate words with newlines
     -h, --help, --usage                                    prints this and exits
```

Example - 3: (types are not next to arguments, and not uppercase)

```bash
$ ARGPARSERSHOWTYPES=1 ARGPARSERTYPESNEXT=0 ARGPARSERTYPESUPPERCASE=0 sozluk -h
usage: sozluk [-hn] [-l LIMIT] WORD [WORD ...]
Direct translations of words TR-TR, TR-EN

options:
     -l, --limit, --limit-output, --total LIMIT             [integer] set a word limit to display
     -n, --newline, --delim-newline, --printlines, --lines  seperate words with newlines
     -h, --help, --usage                                    prints this and exits
```
