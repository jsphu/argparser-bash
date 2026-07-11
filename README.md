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
    :p :path                  file path
    :c :char :character       single literals 'a', 'b' etc.
    :a :alpha :alphabetical   only alphabetical words
```

### Example Usage

```bash
example() {
  # if something broken or using argparser more
  # than once in a script, uncomment these
  # local OPTIND=1 OPTSUBIND=1

  # you can change delimiter for options with ARGPARSEROPTIONSDELIM=
  # ARGPARSEROPTIONSDELIM=';'
  # local opts="help; list; add:s; check:p; quiet; summarize"
  # default is always a comma.
  local opts="
  help,
  list, add: string, check: path,
  quiet, summarize"
  while argparser "$opts" opt "$@"; do
    case "$opt" in
    help)
      # you can set command name and arguments for usage display
      # options will be displayed automatically based on the opts variable
      ARGPARSERCOMMAND="example"
      ARGPARSERARGS="<arg ...>"
      # or you can make one line usage like this:
      ARGPARSERUSAGE="example [-hlacqs] <arg ...>"

      # add a description for your script, and it will be displayed in the usage
      ARGPARSERDESCRIPTION="An example script."

      # you can set help text for each option, and it will be displayed in the usage
      ARGPARSER_HELP="prints this usage"
      ARGPARSER_LIST="lists all"
      ARGPARSER_ADD="add new"
      ARGPARSER_CHECK="checks"
      ARGPARSER_QUIET="suppress outputs"
      ARGPARSER_SUMMARIZE="summarizes"

      # add bottom text if you'd like
      ARGPARSERBOTTOMTEXT="https://github.com/jsphu/argparser-bash"

      # call wrapper function to display usage
      ARGPARSEROPTIONS
      ;;
    list) ... ;;
      # just like getopts, you can get the value of an option with $OPTARG
    add) ADD="$OPTARG" ;;
    quiet) ... ;;
    check) CHECK="$OPTARG" ;;
    summarize) ... ;;
    esac
  done
  shift $((OPTIND - 1)) # shift arguments to get to the rest of the script
  ...
}

# example of running --help option
$ example --help
usage: example [-hlacqs] <arg ...>
An example script.

options:
    -h, --help         prints this usage
    -l, --list         lists all
    -a, --add ADD      add new
    -c, --check CHECK  checks
    -q, --quiet        suppress outputs
    -s, --summarize    summarizes

https://github.com/jsphu/argparser-bash
```

### Tips

```bash
OPTIND=1 # reset OPTIND to 1 if you want to use argparser more than once in a script
OPTSUBIND=1 # reset OPTSUBIND to 1 if you want to use argparser more than once in a script

ARGPARSEROPTIONS # help display function
ARGPARSEROPTIONSDELIM= # change delimiter for options display, default is a comma.
ARGPARSERCOMMAND= # set command name for usage display
ARGPARSERARGS= # set arguments for usage display
ARGPARSERUSAGE= # set usage for usage display
ARGPARSERDESCRIPTION= # set description for usage display
ARGPARSERBOTTOMTEXT= # set bottom text for usage display

ARGPARSER_ # variables are set for each option, will display when calling 'ARGPARSEROPTIONS'.

ARGPARSERSHOWTYPES=1 # display types. you can use (true|false) or (1|0) to enable or disable.
ARGPARSERTYPESUPPERCASE=1 # display types in uppercase
```
