# argparser _for bash_

## Download & Install

Download from releases: [argparser.bash v0.2.0](https://github.com/jsphu/argparser-bash/releases/download/v0.2.0/argparser)

```bash
wget -O argparser.bash "https://github.com/jsphu/argparser-bash/releases/download/v0.2.0/argparser"
# or using curl
curl -fsSL "https://github.com/jsphu/argparser-bash/releases/download/v0.2.0/argparser" > argparser.bash
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
      declare -A ARGPARSERARGS=()
      ARGPARSERCOMMAND="example"
      ARGPARSERARGS["arg ..."]="some argument"
      # or you can make one line usage like this:
      # ARGPARSERUSAGE="example [-hlacqs] <arg ...>"

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

    <arg ...>   some argument

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

Parser options are stored in the following variables:

```bash
OPTIND=1 # reset OPTIND to 1 if you want to use argparser more than once in a script
OPTSUBIND=1 # reset OPTSUBIND to 1 if you want to use argparser more than once in a script

ARGPARSEROPTIONSDELIM= # change delimiter for options parser, default is a comma.
```

`ARGPARSEROPTIONS` display options are stored in the following variables:

```bash
ARGPARSEROPTIONS # smart display function for usage of command. Call it at the end.
ARGPARSERTOPTEXT= # set top text
declare -a ARGPARSERTOPTEXT=() # set top text for usage display, you can set multiple lines with this array.
ARGPARSERCOMMAND= # set command name for usage display
ARGPARSERARGS= # set arguments for usage display
declare -A ARGPARSERARGS[arg]= # set argument description for usage display using this associative array. You can set multiple arguments with this array.
ARGPARSERUSAGE= # set usage for usage display
ARGPARSERDESCRIPTION= # set description for usage display
ARGPARSERMIDDLETEXT= # set middle text for usage display
declare -a ARGPARSERMIDDLETEXT=() # set middle text for usage display, you can set multiple lines with this array.
ARGPARSERBOTTOMTEXT= # set bottom text for usage display
declare -a ARGPARSERBOTTOMTEXT=() # set bottom text for usage display, you can set multiple lines with this array.
ARGPARSER_ # prefix for all options.
ARGPARSERSHOWTYPES=1 # display types. you can use (true|false) or (1|0) to enable or disable.
ARGPARSERTYPESUPPERCASE=1 # display types in uppercase
```

## Upcoming Version v1.0.0

Included in repository for current development, but not yet released. You can try it out by pulling the source code and using the `argparser_v1.0.bash` file.

### Whats included on v1.0.0?

```bash
# - new parsing methods
declare -A ARGPARSER=(

    # option: prefix for options (you can use these too= opt: | o:)
    [option:help]="show this usage"
    [option:debug]="debug mode"

    # same as old version, :<type> suffix for options that require argument
    [option:t:any]="takes argument"

    # new '+N' suffix for multi arguments.
    # Takes exactly 'N' arguments, and will be stored in argparser_value as an array.
    [option:multi+N]="takes #N arguments"

    # set display behaviour on usage naturally in styles field.
    # omit if you don't want these attributes.
    [styles]="types.show types.uppercase types.next options.force_longs"
    # reverse. They are default.
    [styles]="types.hide types.lowercase types.in_description options.normal"

    # additional texts for custom experience
    [top]="This is a top text."
    [mid]="This is a middle text."
    [bot]="This is a bottom text."

    # you can add more lines for top, mid, bot text with prefixing the key
    # currently sorting is not working, it will be placed in random order.
    [top1]=""
    [top2]=""

    # used for 'argparser_usage --usage-only to display one-liner usage text'
    [usage]="argparser [-hdo] OPTIONSTRING NAME [arg ...]"

    # additional description
    [description]="An extended version of getopts command"

    # set command name to appear in usage display.
    [command]="argparser"

    # set positional arguments for usage display, you can set multiple arguments with this associative array.
    [argument:input]="input file"

    # arg: and a: are both valid prefixes for arguments, you can use either one.
    [arg:output]="output file"
    [a:log]="log file"
)

# no need to give an option string, it generated above based on the ARGPARSER associative array.
while argparser "$@"; do

    # now no need to describe an OPT key, every argparser key is stored in the variable ${argparser_key} and its value in ${argparser_value}
    case "$argparser_key" in
        # you can use argparser_usage to display according to ARGPARSER associative array.
        h) argparser_usage ;;
        
        # available options for argparser_usage:
        #    -1 | -u | --one-line | --usage-only
        #    -t | --top-only
        #    -m | --mid-only
        #    -b | --bot-only
        #    -o | --options-only
        # TODO: --format filter to ignore certain options or arguments, and display only the ones you want.

        d) DEBUG=true ;;
        o) OPTIONDISPLAY=true ;;

        # non-multi arguments are stored in the variable ${argparser_value}
        t) T="${argparser_value}" ;;

        # for multi arguments; you can unpack array values with ${argparser_value[@]} or ${argparser_value[0]} for the first value
        m) MULTI="${argparser_value[@]}" ;;
    esac
done
```
