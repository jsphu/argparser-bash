# argparser _for bash_

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

## Download

```sh
git clone https://github.com/jsphu/argparser-bash argparser_bash
cd argparser_bash
# either add to your PATH
export PATH=$PATH:/path/to/file/argparser_bash
# or simply move to your local bin
mv argparser.bash ~/.local/bin/argparser
# or add a symlink of it
ln -s /path/to/file/argparser.bash ~/.local/bin/argparser
# or add this to your .bashrc
[[ -f /path/to/argparser.bash ]] && source /path/to/argparser.bash
```

### Example Usage

```bash
function sozluk() {
  source /path/to/argparser.bash # < source your argparser here
  OPTIND=1 # < crucial, OPTIND should be fixed, or it will run forever
  LIMIT=5
  while argparser "help,limit:int" opt "$@"; do
    case "$opt" in # < same as getopts command, match option
    help)
      echo "usage: sozluk [-h] [-l LIMIT] WORD [WORD ...]"
      echo "Direct translations of words TR-TR, TR-EN"
      echo ""
      echo "options:"
      ARGPARSEROPTIONS # < this prints all options for usage texts
      return
      ;;
    limit)
      LIMIT="${OPTARG}" # < Same as getopts command, take argument
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
  shift $((OPTIND - 1))
  curl -fsSL "https://www.seslisozluk.net/${*// /-}-nedir-ne-demek/" |
    pup 'a.definition-link text{}' |
    head -n ${LIMIT} |
    xargs
}
```
