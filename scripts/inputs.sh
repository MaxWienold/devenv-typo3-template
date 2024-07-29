#!/usr/bin/env bash



function choose_from_menu() {
    local prompt="$1" outvar="$2"
    shift
    shift
    local local options=("$@") cur=0 count=${#options[@]} index=0
    local esc=$(echo -en "\e") # cache ESC as test doesn't allow esc codes
    printf "%s\n" "$prompt"
    while true
    do
        # list all options (option list is zero-based)
        index=0 
        for o in "${options[@]}"
        do
            if [ "$index" == "$cur" ]
            then echo -e " >\e[7m$o\e[0m" # mark & highlight the current option
            else echo "  $o"
            fi
            index=$(( $index + 1 ))
        done
        read -s -n1 key # wait for user to key in arrows or ENTER
        if [[ $key == "k" ]] # up arrow
        then cur=$(( $cur - 1 ))
            [ "$cur" -lt 0 ] && cur=0
        elif [[ $key == "j" ]] # down arrow
        then cur=$(( $cur + 1 ))
            [ "$cur" -ge $count ] && cur=$(( $count - 1 ))
        elif [[ $key == "" ]] # nothing, i.e the read delimiter - ENTER
        then break
        fi
        echo -en "\e[${count}A" # go up to the beginning to re-render
    done
    # export the selection to the requested output variable
    printf -v $outvar "$cur"
}

function input_pw() {
  local prompt="$1" outvar="$2" pw=""
  echo $prompt

  while true; do
    tries=3
    while [[ $tries -gt 0 ]]; do
      stty -echo
      printf "Password: "
      read -r pw
      printf "\n"
      printf "Confirm password: "
      read -r confirm_pw
      stty echo
      printf "\n"
      [[ "$pw" == "$confirm_pw" ]] && break 2 || tries=$((tries -1))
      echo "Passwords don't match'"
    done
    choices=(
      "yes"
      "no"
    )
    choose_from_menu "Try again ?" try "${choices[@]}"
    [[ $try -eq 0 ]] || exit 127
  done
  printf -v $outvar "$pw"
}

function confirm() {
  choices=(
  "yes"
  "no"
  )
  choose_from_menu "$1" answer "${choices[@]}"
  return $answer
}
