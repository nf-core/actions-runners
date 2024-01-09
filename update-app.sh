#!/bin/bash

### CHECKS ###

if ! command -v gh &> /dev/null
then
    echo "gh cli could not be found"
    exit
fi

if ! command -v terraform &> /dev/null
then
    echo "terraform could not be found"
    exit
fi

# create usages function usages mesaages. APP_ID and APP_PRIVATE_KEY_PATH are required as parameter or environment variable
usages() {
    echo "Description: Update the GitHub App webhook configuration with terraform output for the webhook output of the module." >&2
    echo " " >&2
    echo "Usage: $0" >&2
    echo "Usage: $0 [-a APP_ID] [-k APP_PRIVATE_KEY_BASE64]" >&2
    echo "Usage: $0 [-a APP_ID] [-f APP_PRIVATE_KEY_FILE]" >&2
    echo "Usage: $0 [-h]" >&2
    echo "  <no flags>                   Use APP_ID and APP_PRIVATE_KEY_BASE64 or APP_PRIVATE_KEY_PATH environment variables" >&2
    echo "  -a APP_ID                    GitHub App ID" >&2
    echo "  -k APP_PRIVATE_KEY_BASE64    Base64 encoded private key of the GitHub App" >&2
    echo "  -f APP APP_PRIVATE_KEY_FILE  Path to the private key of the GitHub App" >&2
    echo "  -h                           Show this help message" >&2
    exit 1
}

# hadd h flag to show help
while getopts a:f:k:h flag
do
    case "${flag}" in
        a) APP_ID=${OPTARG};;
        f) APP_PRIVATE_KEY_FILE=${OPTARG};;
        k) APP_PRIVATE_KEY_BASE64=${OPTARG};;
        h) usages ;;
    esac
done

if [ -z "$APP_ID" ]; then
  echo "APP_ID must be set"
  usages
fi

# check one of variables APP_PRIVATE_KEY_PATH or APP_PRIVATE_KEY are set
if [ -z "$APP_PRIVATE_KEY_BASE64" ] && [ -z "$APP_PRIVATE_KEY_FILE" ]; then
  echo "APP_PRIVATE_KEY_BASE64 or APP_PRIVATE_KEY_FILE must be set"
  usages
fi

### CREATE JWT TOKEN ###

# Generate the JWT header and payload
HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '\n')
PAYLOAD=$(echo -n "{\"iat\":$(date +%s),\"exp\":$(( $(date +%s) + 600 )),\"iss\":$APP_ID}" | base64 | tr -d '\n')

# Generate the signature
if [ -z "$APP_PRIVATE_KEY_BASE64" ]; then
  APP_PRIVATE_KEY_BASE64=$(cat $APP_PRIVATE_KEY_FILE | base64 | tr -d '\n')
fi

SIGNATURE=$(echo -n "$HEADER.$PAYLOAD" | openssl dgst -sha256 -sign <(echo "$APP_PRIVATE_KEY_BASE64" | base64 -d) | base64 | tr -d '\n')

# Concatenate the JWT token
JWT_TOKEN="$HEADER.$PAYLOAD.$SIGNATURE"
WEBHOOK_ENDPOINT=$(terraform output webhook_endpoint | sed 's/^"//;s/"$//')
WEBHOOK_SECRET=$(terraform output webhook_secret | sed 's/^"//;s/"$//')

### UPDATE WEBHOOK ###

gh api \
  --method PATCH \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /app/hook/config \
  -f content_type='json' \
 -f insecure_ssl='0' \
 -f secret=${WEBHOOK_SECRET} \
 -f url=${WEBHOOK_ENDPOINT}


# resource "null_resource" "run_script" {
#   provisioner "local-exec" {
#     command = <<-EOT
#       if [[ "$(uname)" != "Darwin" && "$(uname)" != "Linux" ]]; then
#         echo "This module can only be run on Mac or Linux"
#         exit 1
#       fi

#       ./update-app.sh -a ${var.app_id} -k ${var.app_private_key}
#     EOT
#   }
# }
