#!/bin/bash
# Simple test PDF creator for Duplexer

set -euo pipefail

TEST_DIR="$(dirname "$0")"
OUTPUT_DIR="${TEST_DIR}/pdfs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$OUTPUT_DIR"

echo "🔧 Creating simple test PDFs..."

# Create odd pages PDF
ODD_PDF="$OUTPUT_DIR/test_odd_pages_${TIMESTAMP}.pdf"
cat > "/tmp/odd.ps" << 'EOF'
%!PS-Adobe-3.0
%%Pages: 4
%%Page: 1 1
/Arial findfont 48 scalefont setfont
100 400 moveto (PAGE 1 - ODD) show
showpage
%%Page: 2 2
/Arial findfont 48 scalefont setfont
100 400 moveto (PAGE 3 - ODD) show
showpage
%%Page: 3 3
/Arial findfont 48 scalefont setfont
100 400 moveto (PAGE 5 - ODD) show
showpage
%%Page: 4 4
/Arial findfont 48 scalefont setfont
100 400 moveto (PAGE 7 - ODD) show
showpage
%%EOF
EOF

# Create even pages PDF
EVEN_PDF="$OUTPUT_DIR/test_even_pages_${TIMESTAMP}.pdf"
cat > "/tmp/even.ps" << 'EOF'
%!PS-Adobe-3.0
%%Pages: 4
%%Page: 1 1
/Arial findfont 48 scalefont setfont
100 400 moveto (PAGE 8 - EVEN) show
showpage
%%Page: 2 2
/Arial findfont 48 scalefont setfont
100 400 moveto (PAGE 6 - EVEN) show
showpage
%%Page: 3 3
/Arial findfont 48 scalefont setfont
100 400 moveto (PAGE 4 - EVEN) show
showpage
%%Page: 4 4
/Arial findfont 48 scalefont setfont
100 400 moveto (PAGE 2 - EVEN) show
showpage
%%EOF
EOF

# Convert to PDF
ps2pdf /tmp/odd.ps "$ODD_PDF"
ps2pdf /tmp/even.ps "$EVEN_PDF"

# Clean up
rm -f /tmp/odd.ps /tmp/even.ps

echo "✅ Test PDFs created:"
echo "   📄 Odd pages:  $ODD_PDF"
echo "   📄 Even pages: $EVEN_PDF"

ls -lh "$ODD_PDF" "$EVEN_PDF"

echo ""
echo "🎯 Ready for testing! Copy these files to your NAS inbox:"
echo "   scp \"$ODD_PDF\" \"$EVEN_PDF\" ugadmin@starkiller.ebschseid:/volume1/services/duplexer/inbox/"