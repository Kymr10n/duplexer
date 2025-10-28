#!/bin/bash

# Test script to understand page ordering issues
set -e

echo "🔍 Testing page order logic..."

# Use the existing test PDFs
cd /home/alex/Projects/duplexer/test

if [[ ! -f "test_odd_pages.pdf" ]] || [[ ! -f "test_even_pages.pdf" ]]; then
    echo "❌ Test PDFs not found, generating them..."
    ./generate_test_pdfs.sh
fi

echo "📄 Analyzing page structure of test files..."

echo "=== ODD PAGES PDF STRUCTURE ==="
pdftk test_odd_pages.pdf dump_data | grep -E "(PageMedia|NumberOfPages)"

echo "=== EVEN PAGES PDF STRUCTURE ==="
pdftk test_even_pages.pdf dump_data | grep -E "(PageMedia|NumberOfPages)"

echo "=== Testing reverse operation on even pages ==="
pdftk test_even_pages.pdf cat end-1 output test_even_reversed.pdf
echo "Even pages reversed structure:"
pdftk test_even_reversed.pdf dump_data | grep -E "(PageMedia|NumberOfPages)"

echo "=== Testing merge operation ==="
pdftk A=test_odd_pages.pdf B=test_even_reversed.pdf shuffle A B output test_merged.pdf
echo "Merged PDF structure:"
pdftk test_merged.pdf dump_data | grep -E "(PageMedia|NumberOfPages)"

echo "✅ Page order test complete. Check test_merged.pdf for correctness."
echo "Expected order should be: Page 1 (Odd), Page 2 (Even), Page 3 (Odd), Page 4 (Even)..."

# Clean up
rm -f test_even_reversed.pdf
