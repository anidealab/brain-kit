#!/bin/bash
# Puts a key into the brain's GitHub Actions secrets with one paste, on a Mac: opens the page that makes it,
# says what to press there, reads the key hidden, checks it if asked, and hands it to GitHub with gh. The Mac's
# version of add-api-keys.ps1, with the same options. Never a file, the clipboard, the screen or a command line
# other programs can see. It knows no service: the agent's command says which key. The owner runs it from their
# copy of the brain on the Mac, with what the agent filled in:
#   bash ~/AI-Brain-Link/<repo name>/skills/add-a-key/add-api-keys.sh --secret OPENAI_API_KEY --page "https://platform.openai.com/api-keys" --tell "Sign in, press Create new secret key, and copy it." --prefix "sk-" --check "https://api.openai.com/v1/models"
# Only --secret is needed. --prefix takes how keys start, comma-separated for more than one. --check is a URL
# that answers 401 to a bad key, sent the key as "Authorization: Bearer <key>", or in the header --header names.
# The brain's repo is the one that copy syncs with (or --repo owner/name). Safe to run again: a key already
# there is replaced. macOS's own bash 3.2.

secret='' page='' tell='' prefix='' check='' header='Authorization' repo=''
while [ $# -gt 0 ]; do
  case "$1" in
    --secret) secret="$2"; shift 2 ;;
    --page) page="$2"; shift 2 ;;
    --tell) tell="$2"; shift 2 ;;
    --prefix) prefix="$2"; shift 2 ;;
    --check) check="$2"; shift 2 ;;
    --header) header="$2"; shift 2 ;;
    --repo) repo="$2"; shift 2 ;;
    *) shift ;;
  esac
done
export PATH="$HOME/AI-Brain-Link/Tools/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

main() {
  local name here brain url owner login admin key starts s ok code value
  name=$(printf '%s' "$secret" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  if ! [[ "$name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then echo 'Say what to call the key, like --secret OPENAI_API_KEY (letters, digits and _).'; return; fi

  if [ -z "$repo" ]; then
    here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    brain=$(cd "$here/../.." && pwd)
    url=$(git -C "$brain" remote get-url origin 2>/dev/null)
    if [[ "$url" =~ github\.com[/:]([^/[:space:]]+/[^/[:space:]]+)$ ]]; then repo="${BASH_REMATCH[1]%.git}"; fi
  fi
  if [ -z "$repo" ]; then read -r -p "Your brain's repo on GitHub, as owner/name: " repo; fi
  owner="${repo%%/*}"

  # gh, signed in as an account that can change the repo's secrets (its owner's)
  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub's command line (gh) isn't on this Mac. Paste the brain kit's Mac command again, which installs it, then this line."; return
  fi
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then gh auth login --hostname github.com --web --git-protocol https; fi
  login=$(gh api user --jq .login 2>/dev/null)
  if [ "$login" != "$owner" ]; then
    gh auth switch --user "$owner" >/dev/null 2>&1
    login=$(gh api user --jq .login 2>/dev/null)
  fi
  admin=$(gh api "repos/$repo" --jq .permissions.admin 2>/dev/null)
  if [ "$admin" != true ]; then echo "GitHub is signed in as $login, which can't change $repo's secrets. Run gh auth login and pick $owner, then run this again."; return; fi

  if [ -n "$page" ]; then open "$page" >/dev/null 2>&1; fi
  if [ -n "$tell" ]; then echo "$tell"; fi
  read -r -s -p "Paste the key for $name (it will not show): " key; echo
  key=$(printf '%s' "$key" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [ -z "$key" ]; then echo 'Nothing was pasted. Run this again and paste the key.'; return; fi
  if [ -n "$prefix" ]; then
    ok=''
    IFS=',' read -r -a starts <<< "$prefix"
    for s in "${starts[@]}"; do
      s=$(printf '%s' "$s" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      if [ -n "$s" ] && [ "${key#"$s"}" != "$key" ]; then ok=yes; fi
    done
    if [ -z "$ok" ]; then echo "That doesn't look like the right key (it should start with $(printf '%s' "$prefix" | sed 's/ *, */ or /g')). Run this again and paste it fresh."; return; fi
  fi

  # Only a 401 means the key is bad; any other answer, or none, lets it through. The header goes to curl on
  # its standard input, so the key never shows in the list of running programs.
  if [ -n "$check" ]; then
    value="$key"
    if [ "$header" = Authorization ]; then value="Bearer $key"; fi
    value=${value//\\/\\\\}; value=${value//\"/\\\"}
    code=$(printf 'header = "%s: %s"\n' "$header" "$value" | curl -s -o /dev/null -w '%{http_code}' --max-time 30 -K - "$check" 2>/dev/null)
    if [ "$code" = 401 ]; then echo 'The service did not accept that key. Run this again and paste it fresh.'; return; fi
  fi

  if ! printf '%s' "$key" | gh secret set "$name" --repo "$repo" >/dev/null 2>&1; then key=''; echo 'GitHub would not take the key. Run this again.'; return; fi
  key=''
  echo "Success: $name is in $repo's secrets."
}

main
