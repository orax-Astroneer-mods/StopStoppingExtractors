@if "%~1"=="" goto skip

@setlocal enableextensions
"repak.exe" unpack "%~1" -f -o "%~dp1%~n1"
@pause

:skip