#!/bin/bash
INPUT="./soft_output/全部文档_合并.txt"
OUTPUT_DIR="./soft_output"
LINES_PER_PAGE=50
TOTAL_LINES=1500

# 前1500行
head -n "$TOTAL_LINES" "$INPUT" > "$OUTPUT_DIR/文档_前1500行.txt"
# 后1500行
tail -n "$TOTAL_LINES" "$INPUT" > "$OUTPUT_DIR/文档_后1500行.txt"

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
    sed -i '' '1s/^/—————————— 第 1 页 ——————————\'$'\n/' "$output_file"
}

add_page_numbers "$OUTPUT_DIR/文档_前1500行.txt" "$OUTPUT_DIR/文档_前30页.txt"
add_page_numbers "$OUTPUT_DIR/文档_后1500行.txt" "$OUTPUT_DIR/文档_后30页.txt"

# 合并 → PDF
cat "$OUTPUT_DIR/文档_前30页.txt" "$OUTPUT_DIR/文档_后30页.txt" > "$OUTPUT_DIR/文档_完整60页.txt"
cupsfilter "$OUTPUT_DIR/文档_完整60页.txt" > "$OUTPUT_DIR/文档_完整60页.pdf" 2>/dev/null

# 清理中间文件
rm -f "$OUTPUT_DIR/文档_前1500行.txt" "$OUTPUT_DIR/文档_后1500行.txt" \
      "$OUTPUT_DIR/文档_前30页.txt" "$OUTPUT_DIR/文档_后30页.txt" \
      "$OUTPUT_DIR/文档_完整60页.txt" \
      "$OUTPUT_DIR/全部文档_合并.txt"

echo "✅ 完成"
ls -lh "$OUTPUT_DIR"/文档_完整60页.pdf
