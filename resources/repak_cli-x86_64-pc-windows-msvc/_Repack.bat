@if "%~1"=="" goto skip

@setlocal enableextensions
@pushd %~dp0
"repak.exe" pack --version V4 "%~1" "%~1.pak"
@popd
@pause

:skip