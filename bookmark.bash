#!/usr/bin/env bash

# The MIT License (MIT)
#
# Copyright (c) 2013 Carlos Valera
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

__bmark_file="$HOME/.bash_bookmark_data"

declare -a __bmark_tags
declare -a __bmark_locs

# Re-reads the data file, and parses its contents into the global __bmark_tags
# and __bmark_locs arrays.
function __bmark_parse_file {
  unset __bmark_tags
  unset __bmark_locs

  while read line
  do
    if [[ "$line" =~ ^#.*$ || "$line" =~ ^\s*$ ]]
    then
      continue
    fi

    local bmark="${line%% *}"
    local loc="${line#* }"

    __bmark_tags=("${__bmark_tags[@]}" "$bmark")
    __bmark_locs=("${__bmark_locs[@]}" "$loc")
  done < "$__bmark_file"
}

# Provides completion for file directorties. Param 1 is the base directory to
# complete for.
#
# TODO: Does not handle newlines or tabs in files
function __bmark_complete_dir {
  local cur="${COMP_WORDS[COMP_CWORD]}"

  if [[ "${#cur}" > 0 ]] ; then
    local dir="`printf %b "${cur%\/*}/"`"
  fi

  local lst=()
  IFS="`printf '\n\t'`"
  while read file ; do
    file=${file//"$1"/}
    lst=("${lst[@]}" "`printf %q "$file"`")
  done < <(ls -1d "$1$dir"*/ 2> /dev/null)

  COMPREPLY=("${lst[@]}")
}

# Generates the completions based on the global __bmark_tags and __bmark_locs
# arrays. Expects that they're the same length.
function __bmark_gen_completions {
  let local len=${#__bmark_tags[@]}-1
  for i in `seq 0 $len`
  do
    local bmark="${__bmark_tags[$i]}"
    local loc="${__bmark_locs[$i]}"
    eval '
      function _'$bmark' {
        __bmark_complete_dir "'$loc'"
      }
      function '$bmark' {
          cd "'$loc'$1"
      }
      complete -o nospace -F _'$bmark' '$bmark'
    '  # eval
  done
}

# Re-reads the data file and re-generates the completions
#
# TODO: If bmark was deleted, and this is called, old bmark will be left in the
# runtime
function __bmark_reload {
  __bmark_parse_file
  __bmark_gen_completions
}
__bmark_reload

# Deletes the bookmark with the tag associated with the first parameter.
function __bmark_delete {
  if [ -n "$1" ] ; then
    sed -i /"^$1"/d "$__bmark_file"
    echo 'Bookmark deleted.'
    __bmark_reload
    return 0
  else
    echo 'You must specify a bookmark to delete.'
    return 1
  fi
}

# Prints all the bookmarks in memory to stdout.
function __bmark_print {
  let local len=${#__bmark_tags[@]}-1
  for i in `seq 0 $len`
  do
    local tag="${__bmark_tags[$i]}"
    local loc="${__bmark_locs[$i]}"
    printf "$tag\t$loc\n"
  done
}

# Creates a bookmark and reloads the tags and locs. First parameter is the tag
# name of the bookmark, second is the location. If location is not specified,
# then PWD is used.
function __bmark_create {
  # default case, create a new bookmark
  if [ -n "$1" ] ; then
    if [ -n "$(grep "^$1" "$__bmark_file")" ] ; then
      echo "Bookmark \`$1' already exists."
      return 1
    fi

    location="${2:-$(pwd)}"
    if [[ ! "$location" =~ /$ ]] ; then
      local location=$location/
    fi

    echo "$1 $location" >> "$__bmark_file"
    __bmark_reload
    return 0
  else
    echo "Must specify a name for the new bookmark to create"
    return 1
  fi
}

__bmark_usage=$(cat <<EOT
creates a bookmark by appending to the .bash_bookmark file which handles
creating a bookmark function an a completion function uses current directory if
no location supplied. Default action is to print all bookmarks.

-p
   prints all the current bookmarks saved
-d name_of_bookmark
   deletes the specified bookmark
-h
   prints this help message

usage:
   bookmark name_of_bookmark [location_to_bookmark]
   bookmark -d name_of_bookmark
   bookmark -p
   bookmark -h
EOT
)
function bookmark {
  if [ "$1" = "-p" -o -z "$1" ] ; then
    __bmark_print
    return 0
  fi

  if [ "$1" = "-h" ] ; then
    echo "$__bmark_usage"
    return 0
  fi

  if [ "$1" = "-d" ] ; then
    if __bmark_delete "$2"; then
      return 0
    else
      return 1
    fi
  fi

  if __bmark_create "$@"; then
    return 0
  else
    return 1
  fi
}
