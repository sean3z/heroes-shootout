#!/usr/bin/env bash
# Curl-based conformance for the Heroes API. usage: conformance.sh http://host:port
set -u; B=${1:-http://localhost:8000}; fail=0
ok(){ echo "PASS $1"; }; bad(){ echo "FAIL $1: $2"; fail=1; }
j(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }
r=$(curl -s -w '\n%{http_code}' $B/heroes/1); c=${r##*$'\n'}; b=${r%$'\n'*}
[ "$c" = 200 ] && [ "$(echo "$b"|j 'd["name"]+"/"+d["alias"]+"/"+str(d["id"])')" = "Barry Allen/The Flash/1" ] && ok "GET /heroes/1" || bad "GET /heroes/1" "$c $b"
[ "$(echo "$b"|j '"mentor" not in d or d["mentor"] is None')" = True ] && ok "mentor null/absent" || bad mentor "$b"
r=$(curl -s -w '\n%{http_code}' $B/heroes/4); b=${r%$'\n'*}; [ "$(echo "$b"|j 'd["name"]+"|"+d["mentor"]+"|"+d["power"]')" = "Tim Drake|Bruce Wayne|Detective skills" ] && ok "GET /heroes/4 Robin" || bad "GET /heroes/4" "$b"
r=$(curl -s -w '\n%{http_code}' $B/heroes); c=${r##*$'\n'}; b=${r%$'\n'*}
[ "$c" = 200 ] && [ "$(echo "$b"|j 'str(len(d))+","+",".join(h["name"] for h in d[:5])')" = "50,Barry Allen,Dick Grayson,Jason Todd,Tim Drake,Damian Wayne" ] && ok "GET /heroes (50, ordered)" || bad "GET /heroes" "$c ${b:0:200}"
c=$(curl -s -o /dev/null -w '%{http_code}' $B/heroes/999999); [ "$c" = 404 ] && ok "GET missing 404" || bad "GET missing" $c
r=$(curl -s -D /tmp/hdr -w '\n%{http_code}' -X POST $B/heroes -H 'content-type: application/json' -d '{"name":"Bart Allen","alias":"Impulse","power":"Super speed","mentor":"Barry Allen"}'); c=${r##*$'\n'}; b=${r%$'\n'*}
id=$(echo "$b"|j 'd["id"]' 2>/dev/null)
[ "$c" = 201 ] && [ -n "$id" ] && [ "$(echo "$b"|j 'd["alias"]')" = Impulse ] && ok "POST 201 id=$id" || bad POST "$c $b"
grep -qi "^location: */heroes/$id" /tmp/hdr && ok "POST Location" || bad "POST Location" "$(grep -i location /tmp/hdr)"
r=$(curl -s -w '\n%{http_code}' -X PUT $B/heroes/$id -H 'content-type: application/json' -d '{"name":"Bart Allen","alias":"Kid Flash","power":"Super speed","mentor":"Barry Allen"}'); c=${r##*$'\n'}; b=${r%$'\n'*}
[ "$c" = 200 ] && [ "$(echo "$b"|j 'd["alias"]+str(d["id"])')" = "Kid Flash$id" ] && ok "PUT 200" || bad PUT "$c $b"
[ "$(curl -s $B/heroes/$id | j 'd["alias"]')" = "Kid Flash" ] && ok "PUT persisted" || bad "PUT persisted" ""
c=$(curl -s -o /dev/null -w '%{http_code}' -X PUT $B/heroes/999999 -H 'content-type: application/json' -d '{"name":"x","alias":"y","power":"z"}'); [ "$c" = 404 ] && ok "PUT missing 404" || bad "PUT missing" $c
c=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/heroes -H 'content-type: application/json' -d '{"name":'); [ "${c:0:1}" = 4 ] && ok "POST bad JSON 4xx ($c)" || bad "POST bad JSON" $c
c=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE $B/heroes/$id); [ "$c" = 204 ] && ok "DELETE 204" || bad DELETE $c
c=$(curl -s -o /dev/null -w '%{http_code}' $B/heroes/$id); [ "$c" = 404 ] && ok "GET deleted 404" || bad "GET deleted" $c
c=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE $B/heroes/$id); [ "$c" = 404 ] && ok "DELETE missing 404" || bad "DELETE missing" $c
curl -s $B/metrics | grep -q "^[a-z_]*http[a-z_]*" && ok "GET /metrics prometheus" || bad metrics ""
exit $fail
