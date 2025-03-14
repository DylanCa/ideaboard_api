#!/bin/bash

# Function to convert snake_case to CamelCase without 'U' prefix
camel_case_convert() {
    local input="$1"
    # Use awk to convert snake_case to CamelCase
    echo "$input" | awk -F'_' '{
        for(i=1;i<=NF;i++) {
            $i=toupper(substr($i,1,1)) substr($i,2)
        }
        print $0
    }' | tr -d '_' | tr -d ' '
}

# Function to convert filename to controller class name
convert_to_controller_class() {
    local filename="$1"
    local parts=()

    # Split the path
    IFS='/' read -ra PATH_PARTS <<< "$filename"

    for part in "${PATH_PARTS[@]}"; do
        # Skip 'controllers' and files ending with '_controller.rb'
        if [[ "$part" == "controllers" || "$part" == *"_controller.rb" ]]; then
            continue
        fi

        # Convert part to CamelCase and remove any "App" prefix
        converted_part=$(camel_case_convert "$part" | sed -E 's/^App//')

        # Only add non-empty parts
        if [[ -n "$converted_part" ]]; then
            parts+=("$converted_part")
        fi
    done

    # Get the last part (controller name) without '_controller.rb'
    local controller_name=$(basename "$filename" "_controller.rb")
    controller_name=$(camel_case_convert "$controller_name")

    # Combine parts
    local full_class_name=""
    if [[ ${#parts[@]} -gt 0 ]]; then
        # Join module parts with :: and append Controller
        # Use printf to ensure :: is used correctly
        full_class_name=$(printf '%s::' "${parts[@]}")${controller_name}Controller
    else
        full_class_name="${controller_name}Controller"
    fi

    echo "$full_class_name"
}

# Navigate to the Rails project root
cd "$(dirname "$0")/.."

# Find all controller files
controllers=$(find app/controllers -name "*_controller.rb" ! -path "app/controllers/api/concerns/*")

# Generate Swagger specs for each controller
for controller in $controllers; do
    # Convert filename to controller class name
    controller_class=$(convert_to_controller_class "$controller")

    echo "Generating Swagger spec for $controller_class"
    bundle exec rails generate rspec:swagger "$controller_class"
done

echo "Swagger spec generation complete!"