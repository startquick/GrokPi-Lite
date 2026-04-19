#!/bin/bash
echo "============================"
echo " GrokPi Admin Utility (.sh) "
echo "============================"

APP_KEY=$1
if [ -z "$APP_KEY" ]; then
    read -s -p "Enter App Key (Admin Password): " APP_KEY
    echo ""
fi

# Bearer Token
export TOKEN="$APP_KEY"
echo -e "\e[32mLogin successful!\e[0m"

while true; do
    echo ""
    echo "--- Upstream Token Management ---"
    echo "1. Add Upstream Grok Token(s)"
    echo "2. List Upstream Tokens"
    echo "3. Delete Upstream Token"
    echo ""
    echo "--- Client API Key Management ---"
    echo "4. Create a new Client API Key"
    echo "5. List Client API Keys"
    echo "6. Delete a Client API Key"
    echo ""
    echo "7. Exit"
    read -p "Choice [1-7]: " choice

    if [ "$choice" = "1" ]; then
        read -p "Enter tokens (comma separated for multiple): " upTokens
        JSON_TOKENS=$(echo "$upTokens" | tr ',' '\n' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/.*/"&"/' | paste -sd, -)
        if [ ! -z "$JSON_TOKENS" ]; then
            JSON_PAYLOAD="{\"tokens\": [$JSON_TOKENS]}"
            curl -s -X POST http://127.0.0.1:8080/admin/tokens/batch \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json" \
              -d "$JSON_PAYLOAD" > /dev/null
            echo -e "\e[32mTokens added successfully!\e[0m"
        fi
    elif [ "$choice" = "2" ]; then
        RES=$(curl -s -X GET "http://127.0.0.1:8080/admin/tokens?page_size=100" -H "Authorization: Bearer $TOKEN")
        if command -v python3 &>/dev/null; then
            echo -e "\e[36m\n--- Upstream Token List ---\e[0m"
            echo "$RES" | python3 -c '
import sys, json
try:
  data = json.load(sys.stdin)
  if "error" in data:
      print(f"API Error: {data['error']}")
  else:
      print("{:<5} | {:<10} | {:<6} | {}".format("ID", "STATUS", "QUOTA", "TOKEN"))
      print("-" * 65)
      for t in data.get("data", []):
          print("{:<5} | {:<10} | {:<6} | {}".format(t.get("id",""), t.get("status",""), t.get("chat_quota",""), t.get("token","")))
except Exception as e:
  print("Failed to parse JSON")'
        else
            echo "$RES"
        fi
    elif [ "$choice" = "3" ]; then
        read -p "Enter the Token ID to delete (e.g. 1): " delId
        if [ ! -z "$delId" ]; then
            DEL_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "http://127.0.0.1:8080/admin/tokens/$delId" -H "Authorization: Bearer $TOKEN")
            if [ "$DEL_CODE" = "204" ] || [ "$DEL_CODE" = "200" ]; then
                echo -e "\e[32mSuccessfully deleted Token ID: $delId\e[0m"
            else
                echo -e "\e[31mFailed to delete Token ID: $delId\e[0m"
            fi
        fi
    elif [ "$choice" = "4" ]; then
        read -p "Enter an alias/name for the new API Key: " keyName
        if [ -z "$keyName" ]; then keyName="UnnamedKey"; fi
        K_RES=$(curl -s -X POST http://127.0.0.1:8080/admin/apikeys \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"name\": \"$keyName\", \"limit_type\": \"unlimited\"}")
        API_KEY=$(echo "$K_RES" | grep -o '"key":"[^"]*' | grep -o '[^"]*$')
        echo -e "\e[32mSuccessfully created API Key: $API_KEY\e[0m"
    elif [ "$choice" = "5" ]; then
        RES=$(curl -s -X GET "http://127.0.0.1:8080/admin/apikeys?page_size=100" -H "Authorization: Bearer $TOKEN")
        if command -v python3 &>/dev/null; then
            echo -e "\e[36m\n--- Client API Key List ---\e[0m"
            echo "$RES" | python3 -c '
import sys, json
try:
  data = json.load(sys.stdin)
  print("{:<5} | {:<10} | {:<15} | {}".format("ID", "STATUS", "NAME", "KEY"))
  print("-" * 75)
  for t in data.get("data", []):
      print("{:<5} | {:<10} | {:<15} | {}".format(t.get("id",""), t.get("status",""), str(t.get("name",""))[:15], t.get("key","")))
except Exception:
  print("Failed to parse JSON")'
        else
            echo "$RES"
        fi
    elif [ "$choice" = "6" ]; then
        read -p "Enter the API Key ID to delete: " delId
        if [ ! -z "$delId" ]; then
            DEL_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "http://127.0.0.1:8080/admin/apikeys/$delId" -H "Authorization: Bearer $TOKEN")
            if [ "$DEL_CODE" = "204" ] || [ "$DEL_CODE" = "200" ]; then
                echo -e "\e[32mSuccessfully deleted API Key ID: $delId\e[0m"
            else
                echo -e "\e[31mFailed to delete API Key ID: $delId\e[0m"
            fi
        fi
    elif [ "$choice" = "7" ]; then
        break
    fi
done
