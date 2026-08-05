#!/bin/bash
PROJECT_DIR="."
OUTPUT_DIR="./soft_output"
LINES_PER_PAGE=50
TOTAL_LINES=1500

mkdir -p "$OUTPUT_DIR"

TEMP_FILE="$OUTPUT_DIR/all_source_temp.txt"
> "$TEMP_FILE"

SOURCE_FILES=$(find "$PROJECT_DIR" \
    \( -name "*.ets" -o -name "*.ts" \) \
    -not -path "*/oh_modules/*" \
    -not -path "*/build/*" \
    -not -path "*/.hvigor/*" \
    -not -path "*/node_modules/*" \
    | sort)

for file in $SOURCE_FILES; do
    echo "// ========== $file ==========" >> "$TEMP_FILE"
    grep -v '^\s*$' "$file" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
done

TOTAL_CODE_LINES=$(wc -l < "$TEMP_FILE" | tr -d ' ')
echo "============================================"
echo "  有效代码总行数: $TOTAL_CODE_LINES 行"
echo "============================================"

head -n "$TOTAL_LINES" "$TEMP_FILE" > "$OUTPUT_DIR/源代码_前1500行.txt"
tail -n "$TOTAL_LINES" "$TEMP_FILE" > "$OUTPUT_DIR/源代码_后1500行.txt"

add_page_numbers() {
    local input_file=$1
    local output_file=$2
    local page_num=1
    local line_count=0
    > "$output_file"
    while IFS= read -r line; do
        if [ $((line_count % LINES_PER_PAGE)) -eq 0 ] && [ $line_count -gt 0 ]; then
            echo "" >> "$output_file"
            echo "—————————— 第 ${page_num} 页 ——————————" >> "$output_file"
            page_num=$((page_num + 1))
        fi
        echo "$line" >> "$output_file"
        line_count=$((line_count + 1))
    done < "$input_file"
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' '1s/^/—————————— 第 1 页 ——————————\'$'\n/' "$output_file"
    else
        sed -i '1s/^/—————————— 第 1 页 ——————————\n/' "$output_file"
    fi
}

add_page_numbers "$OUTPUT_DIR/源代码_前1500行.txt" "$OUTPUT_DIR/源代码_前30页_分页.txt"
add_page_numbers "$OUTPUT_DIR/源代码_后1500行.txt" "$OUTPUT_DIR/源代码_后30页_分页.txt"

rm -f "$TEMP_FILE"

echo ""
echo "============================================"
echo "  ✅ 提取完成！输出目录: $OUTPUT_DIR"
echo "============================================"
ls -lh "$OUTPUT_DIR"
