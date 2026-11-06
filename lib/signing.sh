SIGNING_KEY_ID=""

stage_signing() {
  local tmp pub
  tmp=$(mktemp -d)
  ssh-keygen -q -t ed25519 -N '' -C "$SIGNING_TITLE" -f "$tmp/k"
  pub=$(cat "$tmp/k.pub")
  if SIGNING_KEY_ID=$(gh api -X POST /user/ssh_signing_keys \
        -f title="$SIGNING_TITLE" -f key="$pub" --jq .id 2>/dev/null); then
    cp "$tmp/k" "$SHARED/signing-key"
    chmod 600 "$SHARED/signing-key"
  else
    SIGNING_KEY_ID=""
    echo "    コミットは未署名です。署名するには 1 回だけ:"
    echo "      gh auth refresh -h github.com -s admin:ssh_signing_key"
  fi
  rm -rf "$tmp"
}

drop_stale_signing_keys() {
  local id
  for id in $(gh api /user/ssh_signing_keys \
      --jq ".[] | select(.title == \"$SIGNING_TITLE\") | .id" 2>/dev/null); do
    gh api -X DELETE "/user/ssh_signing_keys/$id" >/dev/null 2>&1 || true
  done
}

rotate_signing_key() {
  local old=$SIGNING_KEY_ID
  stage_signing >/dev/null || return 0
  [ -n "$SIGNING_KEY_ID" ] || return 0
  tart exec "$VM" /bin/bash -lc '
    install -m 600 "/Volumes/My Shared Files/shared/signing-key" ~/.ssh/signing.new &&
    mv ~/.ssh/signing.new ~/.ssh/signing' 2>/dev/null || true
  if [ -n "$old" ]; then
    gh api -X DELETE "/user/ssh_signing_keys/$old" >/dev/null 2>&1 || true
  fi
  return 0
}

drop_signing_key() {
  drop_stale_signing_keys
  SIGNING_KEY_ID=""
}
