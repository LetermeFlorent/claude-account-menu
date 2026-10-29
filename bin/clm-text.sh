clm_lang_code() {
  case $1 in
    ''|[cC]|[pP][oO][sS][iI][xX]|[cC].*) ;;
    [fF][rR]*) echo fr ;;
    *) echo en ;;
  esac
}

clm_mac_lang() {
  if [ "$(uname 2>/dev/null)" = Darwin ]; then
    clm_lang_code "$(defaults read -g AppleLanguages 2>/dev/null | tr -d '\n' | sed -n 's/^[[:space:]]*([[:space:]]*"\{0,1\}\([A-Za-z]\{2,3\}\).*/\1/p')"
  fi
}

clm_lang() {
  clm_found=$(clm_lang_code "${CLM_LANG-}")
  if [ -z "$clm_found" ]; then clm_found=$(clm_mac_lang); fi
  for clm_var in "${LC_ALL-}" "${LC_MESSAGES-}" "${LANG-}"; do
    if [ -z "$clm_found" ]; then clm_found=$(clm_lang_code "$clm_var"); fi
  done
  echo "${clm_found:-en}"
}

clm_lookup() {
  sed -n "s/^  \"$2\": \"\(.*\)\",\{0,1\}\$/\1/p" "${CLM_LANG_DIR-}/$1.json" 2>/dev/null | head -n 1
}

clm_text() {
  clm_key=$1
  clm_out=$(clm_lookup "$(clm_lang)" "$clm_key")
  if [ -z "$clm_out" ]; then clm_out=$(clm_lookup en "$clm_key"); fi
  if [ -z "$clm_out" ]; then clm_out=$2; fi
  shift 2
  clm_index=0
  while [ $# -gt 0 ]; do
    clm_rest=$clm_out
    clm_out=
    while case $clm_rest in *"{$clm_index}"*) true ;; *) false ;; esac; do
      clm_out=$clm_out${clm_rest%%"{$clm_index}"*}$1
      clm_rest=${clm_rest#*"{$clm_index}"}
    done
    clm_out=$clm_out$clm_rest
    clm_index=$((clm_index + 1))
    shift
  done
  printf '%s\n' "$clm_out"
}
