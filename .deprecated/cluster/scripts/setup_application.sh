#!/bin/bash
# requires jinja2-cli and kubectl
app=$1
domain=$2

# use the app's custom setup if it exists
if [ -f "./$app/setup.sh" ]; then
    chmod +x "./$app/setup.sh"
    "./$app/setup.sh" "$app" "$domain"
    exit 0
fi

echo "setting up $app"

# collect all variables from .env if it exists
declare -a jinja_args=()
if [ -f "./$app/.env" ]; then
    while IFS='=' read -r key value; do
        # skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        # remove quotes from value if present
        value="${value%\"}"
        value="${value#\"}"
        jinja_args+=("-D" "$key=$value")
    done < "./$app/.env"
fi

# add domain to jinja args
jinja_args+=("-D" "DOMAIN=$domain")

# apply all yaml files with jinja2 templating directly to kubectl
for file in ./$app/*.yml ./$app/*.yaml; do
    [ -f "$file" ] || continue
    jinja2 "$file" "${jinja_args[@]}" | kubectl apply -f -
done

echo "done ✅"
