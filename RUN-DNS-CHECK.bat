@echo off
cd /d "%~dp0"
set OUT=%~dp0check-dns-m02-results.txt
set DNS=127.0.0.1

echo ============================================================ > "%OUT%"
echo   VCF9 M02 DNS CHECK REPORT >> "%OUT%"
echo   Time: %DATE% %TIME% >> "%OUT%"
echo   DNS Server: %DNS% >> "%OUT%"
echo ============================================================ >> "%OUT%"
echo. >> "%OUT%"

echo === FORWARD (A Records) === >> "%OUT%"
echo --- vcf-m02-inst01.home.lab --- >> "%OUT%"
nslookup vcf-m02-inst01.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-sddcm01.home.lab --- >> "%OUT%"
nslookup vcf-m02-sddcm01.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-esx01.home.lab --- >> "%OUT%"
nslookup vcf-m02-esx01.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-esx02.home.lab --- >> "%OUT%"
nslookup vcf-m02-esx02.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-esx03.home.lab --- >> "%OUT%"
nslookup vcf-m02-esx03.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-esx04.home.lab --- >> "%OUT%"
nslookup vcf-m02-esx04.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-vc01.home.lab --- >> "%OUT%"
nslookup vcf-m02-vc01.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-nsx01a.home.lab --- >> "%OUT%"
nslookup vcf-m02-nsx01a.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-nsx01.home.lab --- >> "%OUT%"
nslookup vcf-m02-nsx01.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-ops01.home.lab --- >> "%OUT%"
nslookup vcf-m02-ops01.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-fleet01.home.lab --- >> "%OUT%"
nslookup vcf-m02-fleet01.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- vcf-m02-opsc01.home.lab --- >> "%OUT%"
nslookup vcf-m02-opsc01.home.lab %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo ============================================================ >> "%OUT%"
echo === REVERSE (PTR Records) === >> "%OUT%"
echo ============================================================ >> "%OUT%"
echo. >> "%OUT%"

echo --- 10.0.1.4 --- >> "%OUT%"
nslookup 10.0.1.4 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.5 --- >> "%OUT%"
nslookup 10.0.1.5 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.14 --- >> "%OUT%"
nslookup 10.0.1.14 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.15 --- >> "%OUT%"
nslookup 10.0.1.15 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.16 --- >> "%OUT%"
nslookup 10.0.1.16 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.17 --- >> "%OUT%"
nslookup 10.0.1.17 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.19 --- >> "%OUT%"
nslookup 10.0.1.19 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.20 --- >> "%OUT%"
nslookup 10.0.1.20 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.21 --- >> "%OUT%"
nslookup 10.0.1.21 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.22 --- >> "%OUT%"
nslookup 10.0.1.22 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.23 --- >> "%OUT%"
nslookup 10.0.1.23 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo --- 10.0.1.24 --- >> "%OUT%"
nslookup 10.0.1.24 %DNS% >> "%OUT%" 2>&1
echo. >> "%OUT%"

echo ============================================================ >> "%OUT%"
echo Done. >> "%OUT%"

echo.
echo Results saved to: %OUT%
echo.
type "%OUT%"
pause
