{ dovecot, gawk, gnused, jq, runCommand }:

runCommand "dovecot-version" {
  buildInputs = [dovecot gnused jq];
} ''
  jq -n  \
    --arg dovecot_version "$(dovecot --version |
        sed 's/\([0-9.]*\).*/\1/' |
        awk -F '.' '{ print $1"."$2"."$3 }')" \
    '[$dovecot_version | split("."), ["major", "minor", "patch"]]
       | transpose | map( { (.[1]): .[0] | tonumber }) | add' > $out
''
